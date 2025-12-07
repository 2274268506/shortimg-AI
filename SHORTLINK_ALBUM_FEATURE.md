# 相册短链功能实现文档

## 📋 功能概述

实现了**相册级别的短链配置**和**图片上传时的短链生成**功能，允许用户：

1. **相册级别配置**：创建相册时可选择是否自动为上传的图片生成短链
2. **图片级别覆盖**：上传图片时可以覆盖相册的短链设置
3. **继承机制**：如果相册开启了短链，上传到该相册的所有图片默认生成短链

## 🎯 使用场景

### 场景 1：相册级自动短链
```
1. 创建相册时开启"自动生成短链"
2. 往该相册上传图片时，所有图片自动生成短链
3. 无需每次上传时手动勾选
```

### 场景 2：按需生成短链
```
1. 创建相册时不开启"自动生成短链"
2. 上传图片时，根据需要选择是否生成短链
3. 灵活控制单次上传的短链生成
```

### 场景 3：覆盖相册设置
```
1. 相册开启了"自动生成短链"
2. 某次上传时关闭短链开关，覆盖相册设置
3. 该次上传的图片不会生成短链
```

## 🔧 技术实现

### 后端修改

#### 1. 数据库模型 (backend/models/album.go)

**Album 模型新增字段**：
```go
type Album struct {
    // ... 现有字段

    // 短链配置字段
    EnableShortLink bool `json:"enableShortLink" gorm:"default:false"` // 是否自动为上传的图片生成短链
}
```

**Image 模型已有字段**：
```go
type Image struct {
    // ... 现有字段

    // 短链字段
    ShortLinkCode string `json:"shortLinkCode" gorm:"index"` // 短链代码
    ShortLinkURL  string `json:"shortLinkUrl" gorm:"-"`      // 短链完整URL（不存储）
}
```

#### 2. 相册控制器 (backend/controllers/album_controller.go)

- `CreateAlbum`：支持接收 `enableShortLink` 参数
- `UpdateAlbum`：支持更新 `enableShortLink` 字段
- 使用 `ShouldBindJSON` 自动绑定，无需额外代码

#### 3. 图片上传控制器 (backend/controllers/image_controller.go)

**单张上传 (UploadImage)**：
```go
// 检查是否需要生成短链
generateShortLink := false
if enableShortLinkStr := c.PostForm("enableShortLink"); enableShortLinkStr != "" {
    // 优先使用请求参数
    generateShortLink = enableShortLinkStr == "true" || enableShortLinkStr == "1"
} else {
    // 否则继承相册配置
    generateShortLink = album.EnableShortLink
}

// 生成短链
if generateShortLink {
    shortLinkClient := utils.NewShortLinkClient("http://localhost")
    shortLinkReq := &utils.ShortLinkRequest{
        ImageURL: fullImageURL,
        Metadata: map[string]interface{}{
            "image_id":      imageRecord.ID,
            "album_id":      imageRecord.AlbumID,
            "original_name": imageRecord.OriginalName,
            "file_size":     imageRecord.FileSize,
        },
    }

    if shortLink, err := shortLinkClient.CreateShortLink(shortLinkReq); err == nil {
        imageRecord.ShortLinkCode = shortLink.Code
        imageRecord.ShortLinkURL = shortLink.ShortURL
        // 更新数据库
        db.Model(&imageRecord).Updates(map[string]interface{}{
            "short_link_code": shortLink.Code,
        })
    }
}
```

**批量上传 (BatchUpload)**：
```go
// 获取相册信息和短链配置
var album models.Album
db.First(&album, albumID)

// 检查是否需要生成短链
generateShortLink := false
if enableShortLinkStr := c.PostForm("enableShortLink"); enableShortLinkStr != "" {
    generateShortLink = enableShortLinkStr == "true" || enableShortLinkStr == "1"
} else {
    generateShortLink = album.EnableShortLink
}

// 收集需要生成短链的图片信息
var shortLinkImages []utils.ImageInfo
for _, imageRecord := range uploadedImages {
    if generateShortLink {
        shortLinkImages = append(shortLinkImages, utils.ImageInfo{
            ImageURL: fullImageURL,
            Metadata: map[string]interface{}{...},
        })
    }
}

// 批量生成短链
if len(shortLinkImages) > 0 {
    shortLinkClient := utils.NewShortLinkClient("http://localhost")
    batchReq := &utils.BatchShortLinkRequest{
        Images: shortLinkImages,
    }

    if batchResp, err := shortLinkClient.BatchCreateShortLinks(batchReq); err == nil {
        // 更新图片记录的短链信息
        for i, result := range batchResp.Results {
            if result.Success && i < len(uploadedImages) {
                uploadedImages[i].ShortLinkCode = result.Code
                uploadedImages[i].ShortLinkURL = result.ShortURL
                db.Model(&uploadedImages[i]).Updates(map[string]interface{}{
                    "short_link_code": result.Code,
                })
            }
        }
    }
}
```

### 前端修改

#### 1. 相册对话框 (frontend/src/components/AlbumDialog.vue)

**新增短链设置区域**：
```vue
<el-divider content-position="left">
  <el-icon><Link /></el-icon>
  <span style="margin-left: 8px;">短链设置</span>
</el-divider>

<el-form-item label="自动生成短链">
  <el-switch v-model="form.enableShortLink" />
  <div style="margin-left: 12px; color: var(--el-text-color-secondary); font-size: 13px;">
    <div>开启后，上传到此相册的图片将自动生成短链</div>
    <div style="margin-top: 4px; color: var(--el-color-primary);">
      <el-icon><InfoFilled /></el-icon>
      短链示例: http://localhost/abc123
    </div>
  </div>
</el-form-item>
```

**表单数据结构**：
```javascript
const form = ref({
  name: '',
  description: '',
  isPrivate: false,
  isPublic: true,
  allowShare: true,
  enableShortLink: false,  // 新增字段
  sharedUserIds: []
})
```

**提交时包含短链配置**：
```javascript
const submitData = {
  name: form.value.name,
  description: form.value.description,
  isPrivate: form.value.isPrivate,
  isPublic: form.value.isPublic,
  allowShare: form.value.allowShare,
  enableShortLink: form.value.enableShortLink,  // 提交到后端
  sharedUsers: form.value.sharedUserIds.join(',')
}
```

#### 2. 上传对话框 (frontend/src/components/UploadDialog.vue)

**相册选择器增强**：
```vue
<el-select v-model="albumId" @change="handleAlbumChange">
  <el-option v-for="album in albums" :key="album.id" :value="album.id">
    <div style="display: flex; align-items: center; justify-content: space-between;">
      <span>{{ album.name }}</span>
      <el-tag v-if="album.enableShortLink" size="small" type="success">
        自动短链
      </el-tag>
    </div>
  </el-option>
</el-select>
```

**短链开关和智能提示**：
```vue
<el-form-item label="生成短链">
  <el-switch v-model="enableShortLink" />
  <span style="margin-left: 12px; color: var(--el-text-color-secondary); font-size: 13px;">
    {{ shortLinkHint }}
  </span>
</el-form-item>
```

**智能提示计算**：
```javascript
const shortLinkHint = computed(() => {
  const selectedAlbum = props.albums.find(a => a.id === albumId.value)
  if (selectedAlbum?.enableShortLink) {
    return enableShortLink.value
      ? '相册已开启自动短链，将为上传的图片生成短链'
      : '关闭后将不生成短链（覆盖相册设置）'
  }
  return enableShortLink.value
    ? '开启后将为上传的图片生成短链'
    : '相册未开启短链，上传的图片不会生成短链'
})
```

**相册切换时自动同步**：
```javascript
const handleAlbumChange = (newAlbumId) => {
  const selectedAlbum = props.albums.find(a => a.id === newAlbumId)
  if (selectedAlbum) {
    enableShortLink.value = selectedAlbum.enableShortLink || false
  }
}
```

**上传时传递短链参数**：
```javascript
const handleUpload = () => {
  emit('upload', {
    albumId: albumId.value,
    enableShortLink: enableShortLink.value,  // 传递短链配置
    files: fileList.value.map(f => f.raw)
  })
}
```

#### 3. 图片管理器 (frontend/src/views/ImageManager.vue)

**接收和传递短链参数**：
```javascript
const handleUpload = async ({ albumId, enableShortLink, files }) => {
  // ...
  await store.batchUploadImages(files, albumId, enableShortLink)
  // ...
}
```

#### 4. Store (frontend/src/stores/image.ts)

**批量上传时包含短链参数**：
```typescript
const batchUploadImages = async (files: File[], albumId: number, enableShortLink?: boolean) => {
  const formData = new FormData()
  files.forEach((file: File) => {
    formData.append('files', file)
  })
  formData.append('albumId', albumId.toString())

  // 添加短链配置参数
  if (enableShortLink !== undefined) {
    formData.append('enableShortLink', enableShortLink.toString())
  }

  const res = await api.batchUpload(formData)
  await loadImages(albumId)
  return res
}
```

## 📊 数据流程

### 创建相册流程
```
用户界面 → AlbumDialog (enableShortLink: true/false)
    ↓
提交表单 → POST /api/albums { enableShortLink: true }
    ↓
CreateAlbum → 保存到数据库 albums.enable_short_link
```

### 上传图片流程（相册已开启短链）
```
用户选择相册 → UploadDialog 自动设置 enableShortLink = true
    ↓
用户点击上传 → POST /api/images/batch-upload
                { files, albumId, enableShortLink: true }
    ↓
BatchUpload → 检查参数/相册配置
    ↓
generateShortLink = true → 调用短链服务
    ↓
批量生成短链 → 更新 images.short_link_code
    ↓
返回带短链的图片列表 → 前端显示短链信息
```

### 上传图片流程（覆盖相册设置）
```
相册开启短链 (album.enableShortLink = true)
    ↓
用户关闭上传对话框的短链开关 (enableShortLink = false)
    ↓
POST /api/images/batch-upload { enableShortLink: false }
    ↓
优先使用请求参数 generateShortLink = false
    ↓
不生成短链，图片的 short_link_code 为空
```

## 🎨 界面展示

### 相册创建对话框
```
┌─────────────────────────────────────┐
│  新建相册                             │
├─────────────────────────────────────┤
│  相册名称: [我的图片集合___________]  │
│  相册描述: [                        ] │
│                                      │
│  🔒 隐私设置                         │
│  访问权限: ○ 公开 ● 私有 ○ 共享     │
│                                      │
│  🔗 短链设置                         │
│  自动生成短链: [●──────]            │
│  ℹ️ 开启后，上传到此相册的图片将      │
│     自动生成短链                     │
│     短链示例: http://localhost/abc123│
│                                      │
│           [取消]      [创建]          │
└─────────────────────────────────────┘
```

### 上传对话框（相册已开启短链）
```
┌─────────────────────────────────────┐
│  上传图片                             │
├─────────────────────────────────────┤
│  选择相册: [我的图片集合 ▼] [自动短链] │
│                                      │
│  生成短链: [●──────]                │
│  相册已开启自动短链，将为上传的       │
│  图片生成短链                         │
│                                      │
│  选择图片: [拖拽文件到此处___________] │
│                                      │
│           [取消]      [开始上传]      │
└─────────────────────────────────────┘
```

### 上传对话框（覆盖相册设置）
```
┌─────────────────────────────────────┐
│  上传图片                             │
├─────────────────────────────────────┤
│  选择相册: [我的图片集合 ▼] [自动短链] │
│                                      │
│  生成短链: [──────○]                │
│  关闭后将不生成短链（覆盖相册设置）    │
│                                      │
│  选择图片: [拖拽文件到此处___________] │
│                                      │
│           [取消]      [开始上传]      │
└─────────────────────────────────────┘
```

## 🧪 测试步骤

### 测试 1：相册级自动短链

1. **创建相册**
   - 登录系统（admin/admin123）
   - 点击"新建相册"
   - 输入名称："测试短链相册"
   - 开启"自动生成短链"开关
   - 点击"创建"

2. **上传图片**
   - 点击"上传图片"
   - 选择相册"测试短链相册"（应显示"自动短链"标签）
   - 短链开关自动开启
   - 选择图片上传

3. **验证结果**
   - 上传完成后，查看图片列表
   - 每张图片应显示短链按钮
   - 点击"复制短链"应成功复制
   - 访问短链应能正常跳转到图片

### 测试 2：手动控制短链

1. **创建普通相册**
   - 创建相册"普通相册"
   - 不开启"自动生成短链"

2. **选择性生成短链**
   - 上传图片到"普通相册"
   - 短链开关默认关闭
   - 手动开启短链开关
   - 上传图片

3. **验证**
   - 该批次图片应有短链
   - 再次上传时不开启短链开关
   - 该批次图片应无短链

### 测试 3：覆盖相册设置

1. **使用已开启短链的相册**
   - 选择"测试短链相册"
   - 短链开关自动开启

2. **覆盖设置**
   - 手动关闭短链开关
   - 上传图片

3. **验证**
   - 该批次图片应无短链
   - 相册配置不变（仍是开启状态）
   - 下次上传时短链开关仍自动开启

## 📝 API 文档

### 创建相册
```http
POST /api/albums
Content-Type: application/json

{
  "name": "我的相册",
  "description": "相册描述",
  "enableShortLink": true,
  "isPrivate": false,
  "isPublic": true,
  "allowShare": true
}
```

### 更新相册
```http
PUT /api/albums/:id
Content-Type: application/json

{
  "enableShortLink": true
}
```

### 批量上传图片
```http
POST /api/images/batch-upload
Content-Type: multipart/form-data

files: <File>[]
albumId: 1
enableShortLink: true  // 可选，覆盖相册设置
```

**响应**：
```json
{
  "data": [
    {
      "id": 123,
      "uuid": "abc-def-ghi",
      "fileName": "image.jpg",
      "url": "/i/abc-def-ghi",
      "shortLinkCode": "XyZ9Abc",
      "shortLinkUrl": "http://localhost/XyZ9Abc"
    }
  ],
  "errors": [],
  "total": 1,
  "success": 1
}
```

## 🔍 优先级逻辑

短链生成的决策逻辑：

```
if 请求中包含 enableShortLink 参数:
    使用请求参数的值
else:
    使用相册的 EnableShortLink 配置
```

**优先级**：`请求参数 > 相册配置`

这样设计的好处：
- 默认继承相册配置，无需每次手动设置
- 支持临时覆盖，灵活性高
- 不影响相册本身的配置

## ✅ 已完成功能

- [x] Album 模型添加 EnableShortLink 字段
- [x] Image 模型已有 ShortLinkCode 和 ShortLinkURL 字段
- [x] 相册控制器支持短链配置的创建和更新
- [x] 单张上传集成短链生成（优先级：请求参数 > 相册配置）
- [x] 批量上传集成短链生成（批量调用短链服务）
- [x] 前端相册对话框添加短链开关
- [x] 前端上传对话框添加短链选项
- [x] 相册选择器显示短链标签
- [x] 智能提示短链状态
- [x] Store 传递短链参数

## 🚀 使用说明

### 快速开始

1. **启动服务**
   ```bash
   # 短链服务（Docker）
   cd redirect-service
   docker-compose up -d

   # Backend
   cd backend
   go run main.go

   # Frontend
   cd frontend
   npm run dev
   ```

2. **登录系统**
   - 访问 http://localhost:5174
   - 用户名：admin
   - 密码：admin123

3. **创建短链相册**
   - 点击"新建相册"
   - 开启"自动生成短链"
   - 创建相册

4. **上传图片**
   - 选择刚创建的相册
   - 上传图片
   - 系统自动生成短链

5. **使用短链**
   - 点击图片的"复制短链"按钮
   - 在浏览器访问短链
   - 自动跳转到原图

### 最佳实践

1. **公开分享的相册**：开启自动短链
2. **私有存储的相册**：关闭自动短链
3. **混合使用**：上传时手动控制

## 🎉 总结

本功能实现了完整的相册级短链配置和图片上传时的短链生成功能，包括：

- **灵活的配置方式**：相册级配置 + 上传时覆盖
- **智能的用户体验**：自动同步、智能提示
- **完整的数据流程**：前后端完整集成
- **批量处理优化**：批量上传使用批量短链API

用户可以根据实际需求选择最合适的使用方式，既可以一劳永逸地在相册级配置短链，也可以灵活地在每次上传时决定是否生成短链。
