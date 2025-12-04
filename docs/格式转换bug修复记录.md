# 格式转换功能修复说明

## 问题描述
前端格式转换对话框中"目标格式"下拉框显示 "no data"，无法选择格式。

## 问题原因

### 1. API 响应格式不匹配
- **后端返回**: `{ formats: [...] }`  
- **前端期望**: `{ data: { supported: [...], animated: [...] } }`

### 2. GetFormatList() 函数返回值不完整
- **原实现**: 只返回 `[]string` (支持的格式列表)
- **需求**: 需要返回两个列表 (supported 和 animated)

## 修复内容

### 1. 修改 `backend/utils/image.go`

**修改前:**
```go
func GetFormatList() []string {
    formats := make([]string, 0, len(SupportedFormats))
    for format := range SupportedFormats {
        formats = append(formats, strings.TrimPrefix(format, "."))
    }
    return formats
}
```

**修改后:**
```go
func GetFormatList() ([]string, []string) {
    // 支持的格式
    supported := make([]string, 0, len(SupportedFormats))
    for format := range SupportedFormats {
        supported = append(supported, strings.TrimPrefix(format, "."))
    }
    
    // 动图格式
    animated := make([]string, 0, len(AnimatedFormats))
    for format := range AnimatedFormats {
        animated = append(animated, strings.TrimPrefix(format, "."))
    }
    
    return supported, animated
}
```

### 2. 修改 `backend/controllers/image_controller.go`

#### 2.1 GetSupportedFormats 函数

**修改前:**
```go
func GetSupportedFormats(c *gin.Context) {
    formats := utils.GetFormatList()
    c.JSON(http.StatusOK, gin.H{
        "formats": formats,
    })
}
```

**修改后:**
```go
func GetSupportedFormats(c *gin.Context) {
    supported, animated := utils.GetFormatList()
    c.JSON(http.StatusOK, gin.H{
        "code":    200,
        "message": "success",
        "data": gin.H{
            "supported": supported,
            "animated":  animated,
        },
    })
}
```

#### 2.2 修复其他使用 GetFormatList() 的地方

在以下 3 个位置修改了错误消息中的格式列表获取:

1. **UploadImage** (第 91 行)
2. **ConvertImageFormat** (第 717 行)  
3. **BatchConvertFormat** (第 817 行)

**修改示例:**
```go
// 修改前
if !utils.IsSupportedFormat(targetExt) {
    c.JSON(http.StatusBadRequest, gin.H{
        "error": fmt.Sprintf("不支持的目标格式，支持: %v", utils.GetFormatList()),
    })
    return
}

// 修改后
if !utils.IsSupportedFormat(targetExt) {
    supported, _ := utils.GetFormatList()
    c.JSON(http.StatusBadRequest, gin.H{
        "error": fmt.Sprintf("不支持的目标格式，支持: %v", supported),
    })
    return
}
```

#### 2.3 修复 BatchConvertFormat 返回值

**修改前:**
```go
c.JSON(http.StatusOK, gin.H{
    "message": "批量转换完成",
    "total":   len(req.ImageIDs),
    "success": successCount,
    "failed":  failedCount,
    "errors":  errors,
})
```

**修改后:**
```go
c.JSON(http.StatusOK, gin.H{
    "code":    200,
    "message": "success",
    "data": gin.H{
        "converted": convertedImages,
        "errors":    errors,
    },
})
```

### 3. 修改 `frontend/src/components/FormatConverter.vue`

#### 3.1 修复数据解析逻辑

**修改前:**
```typescript
const loadSupportedFormats = async () => {
  try {
    const res = await api.getSupportedFormats()
    if (res.data) {
      supportedFormats.value = res.data.supported || []
      animatedFormats.value = res.data.animated || []
    }
  } catch (error) {
    // ...
  }
}
```

**修改后:**
```typescript
const loadSupportedFormats = async () => {
  try {
    const res = await api.getSupportedFormats()
    if (res.data && res.data.data) {
      supportedFormats.value = res.data.data.supported || []
      animatedFormats.value = res.data.data.animated || []
    } else if (res.data) {
      // 兼容直接返回 data 的情况
      supportedFormats.value = res.data.supported || []
      animatedFormats.value = res.data.animated || []
    }
  } catch (error) {
    console.error('获取格式列表失败:', error)
    // 默认格式列表
    supportedFormats.value = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff', 'tif']
    animatedFormats.value = ['gif']
  }
}

// 组件挂载时加载格式列表
loadSupportedFormats()
```

## API 响应格式

### GET /api/images/formats

**响应示例:**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "supported": [
      "jpg",
      "jpeg", 
      "png",
      "gif",
      "webp",
      "bmp",
      "tiff",
      "tif"
    ],
    "animated": [
      "gif"
    ]
  }
}
```

## 测试验证

1. ✅ 启动后端服务
2. ✅ 访问 `/api/images/formats` 确认响应格式正确
3. ✅ 前端打开格式转换对话框
4. ✅ 确认目标格式下拉框显示所有格式
5. ✅ 确认 GIF 格式带有"支持动画"标签

## 影响范围

- **修改文件**: 3 个
  - `backend/utils/image.go` (1 处)
  - `backend/controllers/image_controller.go` (5 处)
  - `frontend/src/components/FormatConverter.vue` (1 处)

- **新增功能**: 无
- **破坏性变更**: 无
- **向后兼容**: ✅ 是

## 相关文档

- 图片格式转换功能说明.md
- 格式转换测试指南.md
