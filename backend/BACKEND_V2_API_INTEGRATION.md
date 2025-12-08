# Backend V2 API 集成完成总结

## 📋 修改概览

已成功将 Backend（图床服务）更新为使用 V2 API，支持新的地理路由和高级分流功能。

---

## ✅ 已完成的修改

### 1. **shortlink_client.go** - 更新为 V2 API

**文件**: `backend/utils/shortlink_client.go`

#### 主要变更：

1. **API 端点更新**:
   - `/api/imagebed/create` → `/api/v2/imagebed/create`
   - `/api/imagebed/batch` → `/api/v2/imagebed/batch`

2. **请求结构更新**:
```go
type ShortLinkRequest struct {
    ImagePath        string                 `json:"image_path"`                   // 图片CDN路径
    CustomCode       string                 `json:"custom_code,omitempty"`        // 自定义代码
    EnableGeoRouting bool                   `json:"enable_geo_routing,omitempty"` // 🆕 地理路由
    ExpireTime       int64                  `json:"expire_time,omitempty"`        // 过期时间
    Metadata         map[string]interface{} `json:"metadata,omitempty"`           // 已弃用
}
```

3. **响应结构增强**:
```go
type ShortLink struct {
    Code               string `json:"code"`                          // 短链代码
    ShortURL           string `json:"short_url"`                     // 短链URL
    ImagePath          string `json:"image_path,omitempty"`          // 🆕 图片路径
    Strategy           string `json:"strategy,omitempty"`            // 🆕 路由策略
    TargetsCount       int    `json:"targets_count,omitempty"`       // 🆕 CDN目标数
    GeoRoutingEnabled  bool   `json:"geo_routing_enabled,omitempty"` // 🆕 地理路由状态
    ExpireAt           *int64 `json:"expire_at,omitempty"`           // 过期时间
    CreatedAt          int64  `json:"created_at"`                    // 创建时间
}
```

4. **默认启用地理路由**:
   - 单个创建和批量创建默认启用 `enable_geo_routing = true`
   - 自动为所有短链配置多CDN分流

5. **已弃用的方法**:
   - `GetShortLinkInfo()` - V2 API 不提供查询功能
   - `UpdateMetadata()` - V2 API 不支持元数据更新
   - `GetStats()` - V2 API 不提供全局统计

---

## 🔧 使用示例

### 单个图片上传创建短链

```go
package controllers

import (
    "shortimg-ai/backend/utils"
    "shortimg-ai/backend/config"
)

func UploadImageHandler(c *gin.Context) {
    // 1. 处理文件上传
    file, err := c.FormFile("file")
    if err != nil {
        c.JSON(400, gin.H{"error": "文件上传失败"})
        return
    }

    // 2. 保存到存储
    imagePath := saveToStorage(file) // 如: /uploads/2024/12/abc123.jpg

    // 3. 创建短链（V2 API）
    client := utils.NewShortLinkClient(
        config.AppConfig.ShortLinkBaseURL,
        config.AppConfig.ShortLinkAPIKey,
    )

    shortLink, err := client.CreateShortLink(&utils.ShortLinkRequest{
        ImagePath:        imagePath,
        EnableGeoRouting: true, // 启用地理路由分流
        ExpireTime:       0,    // 永不过期
    })

    if err != nil {
        log.Printf("创建短链失败: %v", err)
        c.JSON(500, gin.H{"error": "短链创建失败"})
        return
    }

    // 4. 返回响应
    c.JSON(200, gin.H{
        "success": true,
        "data": gin.H{
            "filename":     file.Filename,
            "url":          imagePath,
            "short_url":    shortLink.ShortURL,
            "short_code":   shortLink.Code,
            "strategy":     shortLink.Strategy,        // 如: "geo+weight"
            "cdn_targets":  shortLink.TargetsCount,    // 如: 5
            "geo_enabled":  shortLink.GeoRoutingEnabled,
        },
    })
}
```

### 批量上传创建短链

```go
func BatchUploadHandler(c *gin.Context) {
    // 1. 处理多文件上传
    form, _ := c.MultipartForm()
    files := form.File["files"]

    // 2. 准备批量请求
    var images []utils.ImageInfo
    for i, file := range files {
        imagePath := saveToStorage(file)
        
        images = append(images, utils.ImageInfo{
            ImagePath:        imagePath,
            CustomCode:       fmt.Sprintf("img-%d-%d", time.Now().Unix(), i),
            EnableGeoRouting: true, // 所有图片启用地理路由
        })
    }

    // 3. 批量创建短链
    client := utils.NewShortLinkClient(
        config.AppConfig.ShortLinkBaseURL,
        config.AppConfig.ShortLinkAPIKey,
    )

    result, err := client.BatchCreateShortLinks(&utils.BatchShortLinkRequest{
        Images:     images,
        ExpireTime: 0,
    })

    if err != nil {
        c.JSON(500, gin.H{"error": "批量创建失败"})
        return
    }

    // 4. 处理结果
    c.JSON(200, gin.H{
        "success": true,
        "data": gin.H{
            "total":   result.Total,
            "success": result.Success,
            "failed":  result.Failed,
            "results": result.Results,
        },
    })
}
```

---

## 🧪 测试脚本

已创建测试程序：`backend/cmd/test_v2_api/main.go`

运行测试：

```bash
cd backend
go run cmd/test_v2_api/main.go
```

---

## 🔄 迁移指南

### 从 V1 API 迁移

**之前（V1 API）**:
```go
req := &ShortLinkRequest{
    ImagePath: "/uploads/image.jpg",
    Metadata: map[string]interface{}{
        "filename": "image.jpg",
    },
}
```

**现在（V2 API）**:
```go
req := &ShortLinkRequest{
    ImagePath:        "/uploads/image.jpg",
    EnableGeoRouting: true, // 🆕 地理路由
    // metadata 已废弃，无需设置
}
```

### 响应字段变更

**之前**:
```json
{
  "code": "abc123",
  "short_url": "http://short.example.com/abc123",
  "long_url": "http://cdn.example.com/uploads/image.jpg"
}
```

**现在**:
```json
{
  "code": "abc123",
  "short_url": "http://short.example.com/abc123",
  "image_path": "/uploads/image.jpg",
  "strategy": "geo+weight",
  "targets_count": 5,
  "geo_routing_enabled": true,
  "created_at": 1733299200
}
```

---

## 📊 V2 API 优势

### 1. **自动地理路由**
- ✅ 根据访问者地理位置自动选择最近的 CDN
- ✅ 支持多运营商分流（电信/联通/移动）
- ✅ 海外访问自动切换海外 CDN

### 2. **高级分流策略**
- `geo`: 纯地理位置路由
- `weight`: 权重分配路由
- `geo+weight`: 地理位置 + 权重组合（推荐）
- `hash`: 一致性哈希路由
- `ip`: 基于 IP 范围路由
- `asn`: 基于 ASN 路由

### 3. **配置灵活性**
- ✅ 所有 CDN 节点配置在 `routing_rules.yaml`
- ✅ 支持热重载（5分钟缓存）
- ✅ 可随意添加/删除 CDN 节点
- ✅ 无需修改代码

### 4. **简化的 API**
- ❌ 删除了不常用的元数据功能
- ❌ 删除了查询和统计接口（后端自己管理）
- ✅ 专注于核心功能：创建短链

---

## ⚙️ 环境配置

确保 `.env` 文件中配置了正确的短链服务地址：

```env
# 短链服务配置
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://localhost
SHORT_LINK_API_KEY=sk_test_12345678901234567890123456789012
SHORT_LINK_EXPIRE=0
```

**生产环境示例**:
```env
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=https://short.example.com
SHORT_LINK_API_KEY=sk_prod_your_production_api_key_here
SHORT_LINK_EXPIRE=31536000  # 1年
```

---

## 🚀 部署建议

### 1. **逐步迁移**
- 先在测试环境验证 V2 API
- 确认所有功能正常后再生产部署
- 保留 V1 API 客户端代码作为备份

### 2. **监控关键指标**
- 短链创建成功率
- API 响应时间
- CDN 分流效果
- 地理路由准确性

### 3. **性能优化**
- 使用连接池减少 HTTP 连接开销
- 批量操作合并多个请求
- 缓存常用的短链结果

---

## ⚠️ 注意事项

1. **API 密钥安全**
   - ❌ 不要将 API 密钥提交到代码仓库
   - ✅ 使用环境变量管理
   - ✅ 定期轮换 API 密钥

2. **地理路由限制**
   - 需要 GeoIP 数据库支持
   - 首次访问可能稍慢（数据库查询）
   - 缓存机制可以提升性能

3. **错误处理**
   - 短链服务不可用时的降级方案
   - 重试机制（建议最多3次）
   - 用户友好的错误提示

---

## 📝 相关文档

- [V2 API 文档](../../redirect-service/README.md)
- [高级路由配置](../../redirect-service/ADVANCED_ROUTING_GUIDE.md)
- [Docker 配置完成](../../redirect-service/DOCKER_CONFIG_COMPLETE.md)
- [routing_rules.yaml 示例](../../redirect-service/routing_rules.yaml.example)

---

**完成时间**: 2025年12月8日  
**状态**: ✅ 已完成并测试通过
**下一步**: 在实际图床上传流程中集成并测试
