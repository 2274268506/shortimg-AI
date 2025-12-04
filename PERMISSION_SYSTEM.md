# 权限系统文档

## 📋 概述

本系统现已实现完整的多用户权限控制，包括：
- ✅ 图片所有权管理
- ✅ 相册私有性控制
- ✅ 细粒度的访问权限
- ✅ 相册共享功能

---

## 🔑 核心特性

### 1. 所有权系统

#### 相册所有权
- 每个相册都有一个所有者（创建者）
- 所有者可以：
  - 修改相册信息（名称、描述）
  - 删除相册
  - 上传图片到相册
  - 设置相册的访问权限
  - 共享相册给其他用户

#### 图片所有权
- 每张图片都有一个所有者（上传者）
- 所有者可以：
  - 修改图片信息（重命名、移动、添加标签）
  - 删除图片
  - 更新图片文件
  - 设置图片的访问和下载权限

### 2. 访问控制

#### 相册访问级别

| 字段 | 类型 | 说明 |
|------|------|------|
| `isPrivate` | Boolean | 是否私有（私有相册只有所有者可见） |
| `isPublic` | Boolean | 是否公开（公开相册其他登录用户可见） |
| `allowShare` | Boolean | 是否允许通过链接分享 |
| `sharedUsers` | String | 共享给的用户ID列表（逗号分隔） |

**访问规则**：
```
可以访问 = 以下任一条件满足：
  1. 用户是管理员
  2. 用户是所有者
  3. 相册是公开的（isPublic=true 且 isPrivate=false）
  4. 用户在共享列表中
```

#### 图片访问级别

| 字段 | 类型 | 说明 |
|------|------|------|
| `isPrivate` | Boolean | 是否私有 |
| `isPublic` | Boolean | 是否公开 |
| `allowDownload` | Boolean | 是否允许下载 |

**访问规则**：
```
可以查看 = 以下任一条件满足：
  1. 用户是管理员
  2. 用户是所有者
  3. 图片是公开的（isPublic=true 且 isPrivate=false）

可以下载 = 可以查看 且 allowDownload=true
```

### 3. 权限层级

| 角色 | 相册权限 | 图片权限 |
|------|---------|---------|
| **管理员** | 所有相册的完全访问权限 | 所有图片的完全访问权限 |
| **所有者** | 自己相册的完全控制权 | 自己图片的完全控制权 |
| **普通用户** | 查看公开相册和共享给自己的相册 | 查看公开图片 |
| **游客（未登录）** | 查看公开相册 | 查看公开图片 |

---

## 🛠️ API 变更

### 相册 API

#### GET /api/albums
- **权限**: 需要登录
- **行为变更**: 
  - 管理员：返回所有相册
  - 普通用户：返回自己的相册 + 公开相册 + 共享给自己的相册
  - 游客：返回公开相册

#### POST /api/albums
- **权限**: 需要登录
- **新增字段**:
  ```json
  {
    "name": "相册名称",
    "description": "描述",
    "isPrivate": false,      // 可选，默认false
    "isPublic": true,        // 可选，默认true
    "allowShare": true,      // 可选，默认true
    "sharedUsers": "2,3,5"   // 可选，用户ID逗号分隔
  }
  ```
- **自动设置**: `ownerId` 自动设为当前用户

#### PUT /api/albums/:id
- **权限**: 需要所有权（所有者或管理员）
- **新增**: 权限检查中间件 `CheckAlbumOwnership()`

#### DELETE /api/albums/:id
- **权限**: 需要所有权（所有者或管理员）
- **新增**: 权限检查中间件 `CheckAlbumOwnership()`

### 图片 API

#### GET /api/images
- **权限**: 需要登录
- **行为变更**:
  - 管理员：返回所有图片
  - 普通用户：返回自己的图片 + 公开图片
  - 游客：返回公开图片

#### POST /api/images/upload
- **权限**: 需要登录 + 相册修改权限
- **行为变更**: 
  - 检查是否有权限上传到目标相册
  - 自动设置 `ownerId`
  - 继承相册的 `isPrivate` 和 `isPublic` 设置

#### PUT /api/images/:id/move
#### PUT /api/images/:id/rename
#### PUT /api/images/:id/file
#### PUT /api/images/:id/tags
#### DELETE /api/images/:id
- **权限**: 需要所有权（所有者或管理员）
- **新增**: 权限检查中间件 `CheckImageOwnership()`

---

## 🔧 中间件

### 新增中间件

#### 1. CheckAlbumOwnership()
```go
// 用于需要修改相册的操作
// 验证用户是否为相册所有者或管理员
```

#### 2. CheckImageOwnership()
```go
// 用于需要修改图片的操作
// 验证用户是否为图片所有者或管理员
```

#### 3. CheckAlbumAccess()
```go
// 用于只读访问相册
// 验证用户是否有权限查看相册
```

#### 4. CheckImageAccess()
```go
// 用于只读访问图片
// 验证用户是否有权限查看图片
```

---

## 📊 数据库模型变更

### Album 模型新增字段

```go
type Album struct {
    // ... 原有字段 ...
    
    // 权限控制字段
    OwnerID     uint           `json:"ownerId" gorm:"index;not null"`
    Owner       *User          `json:"owner,omitempty" gorm:"foreignKey:OwnerID"`
    IsPrivate   bool           `json:"isPrivate" gorm:"default:false;index"`
    IsPublic    bool           `json:"isPublic" gorm:"default:true"`
    AllowShare  bool           `json:"allowShare" gorm:"default:true"`
    SharedUsers string         `json:"sharedUsers,omitempty" gorm:"type:text"`
}
```

### Image 模型新增字段

```go
type Image struct {
    // ... 原有字段 ...
    
    // 权限控制字段
    OwnerID       uint           `json:"ownerId" gorm:"index;not null"`
    Owner         *User          `json:"owner,omitempty" gorm:"foreignKey:OwnerID"`
    IsPrivate     bool           `json:"isPrivate" gorm:"default:false;index"`
    IsPublic      bool           `json:"isPublic" gorm:"default:true"`
    AllowDownload bool           `json:"allowDownload" gorm:"default:true"`
}
```

### 新增索引
- `idx_albums_owner_id`
- `idx_albums_is_private`
- `idx_images_owner_id`
- `idx_images_is_private`

---

## 🚀 使用示例

### 创建私有相册
```bash
POST /api/albums
Authorization: Bearer <token>

{
  "name": "我的私人相册",
  "description": "只有我能看",
  "isPrivate": true,
  "isPublic": false
}
```

### 创建共享相册
```bash
POST /api/albums
Authorization: Bearer <token>

{
  "name": "团队相册",
  "description": "与团队成员共享",
  "isPrivate": false,
  "isPublic": false,
  "sharedUsers": "2,3,5"  // 共享给用户 2, 3, 5
}
```

### 上传私有图片
```bash
POST /api/images/upload
Authorization: Bearer <token>
Content-Type: multipart/form-data

albumId: 1
file: <文件>
```
*注意：图片会自动继承相册的隐私设置*

### 修改图片权限
```bash
PUT /api/images/:id/tags
Authorization: Bearer <token>

{
  "isPrivate": true,
  "allowDownload": false
}
```

---

## 🔐 安全特性

1. **强制认证**: 所有相册和图片操作都需要登录
2. **所有权验证**: 修改操作需要验证所有权
3. **自动所有者设置**: 创建资源时自动设置为当前用户
4. **级联权限**: 图片继承相册的隐私设置
5. **管理员特权**: 管理员可以管理所有资源

---

## 📝 迁移说明

### 运行迁移
```bash
cd backend
go run cmd/migrate_permissions/main.go
```

### 迁移内容
1. 为 `albums` 表添加权限字段
2. 为 `images` 表添加权限字段
3. 创建性能索引
4. 将现有资源的所有者设置为第一个管理员
5. 移除相册名称唯一性约束（允许不同用户创建同名相册）

### 兼容性
- ✅ 向后兼容
- ✅ 现有数据自动更新
- ✅ 默认值确保安全（默认公开）

---

## 🎯 最佳实践

### 1. 相册组织
```
推荐结构：
├── 公开相册（is_public=true, is_private=false）
│   └── 所有人可见，适合展示作品
├── 私人相册（is_private=true, is_public=false）
│   └── 只有自己可见，存放个人照片
└── 团队相册（is_public=false, shared_users="2,3,5"）
    └── 与特定用户共享，团队协作
```

### 2. 权限设置
- **公开作品**: `isPublic=true, isPrivate=false, allowDownload=true`
- **受保护作品**: `isPublic=true, isPrivate=false, allowDownload=false`
- **私人照片**: `isPublic=false, isPrivate=true`

### 3. 共享管理
- 定期审核共享列表
- 使用用户ID而非用户名（更稳定）
- 共享列表格式：`"1,2,3,5"`（逗号分隔，无空格）

---

## ⚠️ 注意事项

1. **默认相册（ID=1）**: 不能删除，所有用户共享
2. **管理员权限**: 管理员可以访问和修改所有资源
3. **游客访问**: 未登录用户只能查看公开资源
4. **权限继承**: 上传的图片默认继承相册的隐私设置
5. **性能考虑**: 大量共享用户时建议优化查询

---

## 🔄 未来扩展

可能的增强功能：
- [ ] 相册协作者（除所有者外的编辑者）
- [ ] 细粒度图片权限（独立于相册）
- [ ] 用户组和角色扩展
- [ ] 权限继承策略配置
- [ ] 批量权限修改
- [ ] 权限模板

---

## 📚 相关文件

- **模型**: `backend/models/album.go`
- **中间件**: `backend/middleware/permission.go`
- **控制器**: 
  - `backend/controllers/album_controller.go`
  - `backend/controllers/image_controller.go`
- **路由**: `backend/routes/routes.go`
- **迁移脚本**: `backend/cmd/migrate_permissions/main.go`

---

## 🐛 故障排查

### 403 Forbidden 错误
```
可能原因：
1. 用户未登录
2. 用户不是资源所有者
3. 资源是私有的且用户没有访问权限
```

### 相册/图片不显示
```
检查：
1. 用户是否登录
2. isPublic 和 isPrivate 设置是否正确
3. 共享列表格式是否正确
```

### 无法上传图片
```
检查：
1. 是否有目标相册的修改权限
2. 相册是否存在
3. 用户是否为相册所有者
```

---

✅ **权限系统已成功部署！**

重启服务器后，所有新功能将生效。现有数据已自动迁移，默认为公开状态，确保平滑过渡。
