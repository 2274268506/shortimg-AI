# 图床项目短链服务对接指南

## 📖 概述

本文档描述如何将图床系统（backend + frontend）与短链服务（redirect-service）对接，实现图片上传后自动生成短链功能。

## 🏗️ 架构说明

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│   Frontend      │      │    Backend       │      │ Redirect-Service│
│   (Vue.js)      │─────>│    (Gin/Go)      │─────>│  (OpenResty)    │
│                 │      │                  │      │                  │
│  - 上传界面     │      │  - 图片处理      │      │  - 短链生成     │
│  - 短链显示     │      │  - 短链客户端    │      │  - 短链重定向   │
│  - 复制功能     │      │  - 数据库存储    │      │  - 统计分析     │
└─────────────────┘      └──────────────────┘      └─────────────────┘
        │                         │                          │
        └─────────────────────────┴──────────────────────────┘
                        MySQL Database
```

## ✅ 已完成的工作

### 1. 短链服务 API (redirect-service)
- ✅ `/api/imagebed/create` - 创建单个图床短链
- ✅ `/api/imagebed/batch` - 批量创建短链
- ✅ `/api/imagebed/info/{code}` - 获取短链信息
- ✅ `/api/imagebed/metadata/{code}` - 更新元数据
- ✅ `/api/imagebed/stats` - 获取统计信息

### 2. Backend 集成代码
- ✅ `utils/shortlink_client.go` - 短链服务客户端
- ✅ `config/config.go` - 添加短链配置
- ✅ `models/album.go` - Image模型添加短链字段
- ✅ `.env.example` - 环境变量配置示例

### 3. 数据库变更
需要添加短链字段到 images 表

## 🚀 部署步骤

### 步骤 1: 启动短链服务

```bash
cd c:\Users\DXY\Documents\TC-GO\redirect-service

# 启动所有服务
docker-compose up -d

# 验证服务状态
docker-compose ps

# 应该看到以下服务运行:
# - short-link-openresty (端口80)
# - short-link-mysql (端口3306)
# - short-link-redis (端口6379)
# - short-link-prometheus (端口9090)
# - short-link-grafana (端口3000)
```

### 步骤 2: 配置 Backend

```bash
cd c:\Users\DXY\Documents\TC-GO\backend

# 复制环境变量文件
cp .env.example .env

# 编辑 .env 文件，添加短链配置
```

在 `.env` 文件中添加：

```bash
# ==================== 短链服务配置 ====================
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://localhost
SHORT_LINK_EXPIRE=0
```

### 步骤 3: 数据库迁移

执行以下 SQL 添加短链字段：

```sql
-- 添加短链字段到 images 表
ALTER TABLE images
ADD COLUMN short_link_code VARCHAR(32) DEFAULT NULL COMMENT '短链代码',
ADD INDEX idx_short_link_code (short_link_code);
```

或使用 GORM 自动迁移：

```go
// 在 main.go 或迁移脚本中
db.AutoMigrate(&models.Image{})
```

### 步骤 4: 修改图片上传控制器

编辑 `controllers/image_controller.go`，在 `UploadImage` 函数中添加短链生成逻辑：

```go
// 在文件开头添加导入
import (
	"imagebed/utils"
	// ... 其他导入
)

// 在 UploadImage 函数中，图片保存成功后添加：
func UploadImage(c *gin.Context) {
	// ... 现有代码 ...

	// 保存到数据库
	imageRecord := models.Image{
		UUID:          imageUUID,
		AlbumID:       uint(albumID),
		FileName:      newFileName,
		OriginalName:  file.Filename,
		// ... 其他字段 ...
	}

	if err := db.Create(&imageRecord).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存数据失败"})
		return
	}

	// 🆕 生成短链（如果启用）
	cfg := config.GetConfig()
	if cfg.ShortLinkEnabled {
		shortLinkClient := utils.NewShortLinkClient(cfg.ShortLinkBaseURL)

		// 构建图片URL
		imageURL := fmt.Sprintf("%s/api/files/album_%d/%s",
			cfg.StorageBaseURL, albumID, newFileName)

		// 如果使用完整域名
		if c.Request.Host != "" {
			scheme := "http"
			if c.Request.TLS != nil {
				scheme = "https"
			}
			imageURL = fmt.Sprintf("%s://%s%s", scheme, c.Request.Host, imageURL)
		}

		shortLinkReq := &utils.ShortLinkRequest{
			ImageURL:   imageURL,
			ExpireTime: cfg.ShortLinkExpire,
			Metadata: map[string]interface{}{
				"filename":      file.Filename,
				"size":          file.Size,
				"type":          imageRecord.MimeType,
				"album_id":      albumID,
				"image_uuid":    imageUUID,
				"uploaded_by":   userID,
			},
		}

		if shortLink, err := shortLinkClient.CreateShortLink(shortLinkReq); err == nil {
			// 更新数据库
			db.Model(&imageRecord).Update("short_link_code", shortLink.Code)
			imageRecord.ShortLinkCode = shortLink.Code
			imageRecord.ShortLinkURL = shortLink.ShortURL

			logger.Info("图片短链创建成功",
				zap.String("image_uuid", imageUUID),
				zap.String("short_link_code", shortLink.Code),
				zap.String("short_url", shortLink.ShortURL))
		} else {
			logger.Warn("图片短链创建失败",
				zap.String("image_uuid", imageUUID),
				zap.Error(err))
		}
	}

	// 🆕 在响应中包含短链信息
	imageRecord.URL = fmt.Sprintf("/api/files/album_%d/%s", albumID, newFileName)
	if imageRecord.ShortLinkCode != "" {
		imageRecord.ShortLinkURL = fmt.Sprintf("%s/%s", cfg.ShortLinkBaseURL, imageRecord.ShortLinkCode)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "上传成功",
		"data":    imageRecord,
	})
}
```

### 步骤 5: 修改批量上传

类似地，在 `BatchUpload` 函数中添加批量短链生成：

```go
func BatchUpload(c *gin.Context) {
	// ... 现有上传逻辑 ...

	// 🆕 批量生成短链
	cfg := config.GetConfig()
	if cfg.ShortLinkEnabled && len(uploadedImages) > 0 {
		shortLinkClient := utils.NewShortLinkClient(cfg.ShortLinkBaseURL)

		var batchImages []utils.ImageInfo
		for _, img := range uploadedImages {
			imageURL := fmt.Sprintf("%s/api/files/album_%d/%s",
				cfg.StorageBaseURL, img.AlbumID, img.FileName)

			batchImages = append(batchImages, utils.ImageInfo{
				ImageURL: imageURL,
				Metadata: map[string]interface{}{
					"filename":   img.OriginalName,
					"image_uuid": img.UUID,
					"album_id":   img.AlbumID,
				},
			})
		}

		batchReq := &utils.BatchShortLinkRequest{
			Images:     batchImages,
			ExpireTime: cfg.ShortLinkExpire,
		}

		if result, err := shortLinkClient.BatchCreateShortLinks(batchReq); err == nil {
			// 更新数据库
			for i, item := range result.Results {
				if item.Success && i < len(uploadedImages) {
					db.Model(&uploadedImages[i]).Update("short_link_code", item.Code)
					uploadedImages[i].ShortLinkCode = item.Code
					uploadedImages[i].ShortLinkURL = item.ShortURL
				}
			}

			logger.Info("批量短链创建完成",
				zap.Int("total", result.Total),
				zap.Int("success", result.Success),
				zap.Int("failed", result.Failed))
		}
	}

	// 返回结果...
}
```

### 步骤 6: 前端集成

#### 6.1 显示短链

修改前端图片列表组件，显示短链信息：

```vue
<!-- src/components/ImageList.vue -->
<template>
  <div class="image-card">
    <!-- 现有图片显示 -->
    <img :src="image.url" :alt="image.originalName" />

    <!-- 🆕 短链显示 -->
    <div v-if="image.shortLinkUrl" class="short-link-section">
      <div class="short-link-label">短链接：</div>
      <div class="short-link-value">
        <input
          :value="image.shortLinkUrl"
          readonly
          @click="selectAll"
          class="short-link-input"
        />
        <button @click="copyShortLink(image.shortLinkUrl)" class="copy-btn">
          <i class="fas fa-copy"></i> 复制
        </button>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  methods: {
    selectAll(event) {
      event.target.select();
    },

    async copyShortLink(url) {
      try {
        await navigator.clipboard.writeText(url);
        this.$message.success('短链已复制到剪贴板');
      } catch (err) {
        // 降级方案
        const input = document.createElement('input');
        input.value = url;
        document.body.appendChild(input);
        input.select();
        document.execCommand('copy');
        document.body.removeChild(input);
        this.$message.success('短链已复制');
      }
    }
  }
}
</script>

<style scoped>
.short-link-section {
  margin-top: 10px;
  padding: 10px;
  background: #f5f5f5;
  border-radius: 4px;
}

.short-link-label {
  font-size: 12px;
  color: #666;
  margin-bottom: 5px;
}

.short-link-value {
  display: flex;
  gap: 8px;
}

.short-link-input {
  flex: 1;
  padding: 6px 10px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 13px;
  font-family: monospace;
  background: white;
}

.copy-btn {
  padding: 6px 15px;
  background: #409eff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background 0.3s;
}

.copy-btn:hover {
  background: #66b1ff;
}
</style>
```

#### 6.2 上传界面增强

修改上传组件，添加短链选项：

```vue
<!-- src/components/Upload.vue -->
<template>
  <div class="upload-section">
    <!-- 现有上传界面 -->

    <!-- 🆕 短链选项 -->
    <el-form-item label="生成短链">
      <el-switch
        v-model="enableShortLink"
        active-text="启用"
        inactive-text="禁用"
      />
    </el-form-item>

    <el-form-item v-if="enableShortLink" label="过期时间">
      <el-select v-model="shortLinkExpire">
        <el-option label="永不过期" :value="0" />
        <el-option label="7天" :value="604800" />
        <el-option label="30天" :value="2592000" />
        <el-option label="365天" :value="31536000" />
      </el-select>
    </el-form-item>
  </div>
</template>

<script>
export default {
  data() {
    return {
      enableShortLink: true,  // 默认启用
      shortLinkExpire: 0,     // 默认永不过期
    }
  }
}
</script>
```

### 步骤 7: 重启服务

```bash
# 重启 backend
cd c:\Users\DXY\Documents\TC-GO\backend
go run main.go

# 或编译后运行
go build -o imagebed.exe
./imagebed.exe

# 重启 frontend（如果需要）
cd c:\Users\DXY\Documents\TC-GO\frontend
npm run dev
```

## 🧪 测试验证

### 1. 手动测试

1. 访问图床系统: `http://localhost:8080`
2. 登录账号
3. 上传一张图片
4. 查看返回结果中是否包含 `shortLinkCode` 和 `shortLinkUrl`
5. 复制短链并在浏览器中访问
6. 验证是否正确重定向到图片

### 2. API 测试

使用 curl 测试短链服务：

```bash
# 创建短链
curl -X POST http://localhost/api/imagebed/create \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "http://localhost:8080/api/files/album_1/test.jpg",
    "metadata": {
      "filename": "test.jpg",
      "size": 102400
    }
  }'

# 获取短链信息
curl http://localhost/api/imagebed/info/YOUR_CODE

# 获取统计
curl http://localhost/api/imagebed/stats
```

### 3. 自动化测试脚本

```bash
cd c:\Users\DXY\Documents\TC-GO\redirect-service
.\scripts\test-imagebed-api.ps1
```

## 📊 监控和统计

### Grafana 仪表板

访问 `http://localhost:3000` 查看监控数据：

- **短链管理面板**: 图床短链创建趋势、点击统计
- **热门图片 Top 10**: 最受欢迎的图片

### Prometheus 指标

访问 `http://localhost:9090` 查询指标：

```promql
# 图床短链总数
short_link_short_links_total{type="imagebed"}

# 图床短链创建速率
rate(short_link_http_requests_total{endpoint="/api/imagebed/create"}[5m])

# 短链点击数
sum(short_link_clicks_total{type="imagebed"})
```

## 🔧 故障排查

### 问题 1: 短链创建失败

**症状**: 图片上传成功，但没有短链

**排查步骤**:
1. 检查 `.env` 中 `SHORT_LINK_ENABLED=true`
2. 检查短链服务是否运行: `docker-compose ps`
3. 查看 backend 日志: `tail -f logs/app.log`
4. 测试短链服务连接: `curl http://localhost/api/health`

### 问题 2: 短链无法访问

**症状**: 短链返回 404

**排查步骤**:
1. 检查短链代码是否正确保存到数据库
2. 查看 OpenResty 错误日志:
   ```bash
   docker exec short-link-openresty tail -50 /usr/local/openresty/nginx/logs/error.log
   ```
3. 验证图片 URL 是否可访问

### 问题 3: 批量上传慢

**症状**: 批量上传时响应时间长

**解决方案**:
- 使用批量短链API (`/api/imagebed/batch`) 而不是循环调用单个API
- 考虑异步生成短链（上传后台任务）

## 📝 配置参考

### 完整 .env 配置

```bash
# 数据库配置
DB_TYPE=sqlite
DB_DSN=./data/imagebed.db

# Redis 配置（可选）
REDIS_ENABLED=false
REDIS_ADDR=localhost:6379

# 服务器配置
SERVER_PORT=8080
SERVER_MODE=debug

# JWT 配置
JWT_SECRET=your-secret-key-change-this-in-production
JWT_EXPIRATION=24h

# 文件上传配置
UPLOAD_PATH=./uploads
MAX_FILE_SIZE=100

# 存储配置
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=./uploads
STORAGE_BASE_URL=/api/files

# 短链服务配置
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://localhost
SHORT_LINK_EXPIRE=0

# 日志配置
LOG_PATH=./logs/app.log
LOG_MAX_SIZE=100
LOG_MAX_AGE=30
LOG_MAX_BACKUPS=10
```

## 📚 相关文档

- [短链 API 文档](../../redirect-service/docs/IMAGEBED_API.md)
- [监控仪表板使用指南](../../redirect-service/docs/MANAGEMENT_DASHBOARD.md)
- [图床系统文档](../README.md)

## 🎯 下一步

- [ ] 添加短链批量管理功能
- [ ] 支持短链自定义域名
- [ ] 添加短链访问统计到图床管理界面
- [ ] 实现短链过期自动清理
- [ ] 添加短链分享页面（带预览）

---

**更新时间**: 2025-12-06
**维护者**: TC-GO 团队
