# 快速开始 - 域名配置示例

## 场景：为 TC-GO 图床配置 CDN 加速

### 1. 准备工作

假设你有以下资源：

- **服务器**: 123.45.67.89
- **主域名**: example.com
- **CDN 提供商**: 阿里云、腾讯云、Cloudflare

### 2. 域名规划

```
短链服务:     s.example.com          -> 123.45.67.89
图床主站:     img.example.com        -> 你的图床服务器
图床备份:     img-backup.example.com -> 备份服务器

CDN 节点:
  北方电信:   cdn-bj.example.com     -> 阿里云 CDN (北京节点)
  南方联通:   cdn-gz.example.com     -> 腾讯云 CDN (广州节点)
  海外:       cdn-us.example.com     -> Cloudflare CDN
```

### 3. DNS 配置

在你的 DNS 服务商（如阿里云、腾讯云、Cloudflare）添加记录：

#### 3.1 短链服务

```
类型    名称    值
A       s       123.45.67.89
```

#### 3.2 图床服务

```
类型    名称          值
A       img           你的图床服务器IP
A       img-backup    备份服务器IP
```

#### 3.3 CDN 节点（使用 CNAME）

```
类型    名称      值
CNAME   cdn-bj    你的阿里云CDN域名.alikunlun.com
CNAME   cdn-gz    你的腾讯云CDN域名.cdn.dnsv1.com
CNAME   cdn-us    你的Cloudflare域名.cdn.cloudflare.net
```

### 4. 配置 .env 文件

```bash
# 复制示例配置
cp .env.example .env

# 编辑配置文件
nano .env
```

填入实际域名：

```bash
# ========================================
# 重定向服务配置
# ========================================
REDIRECT_DOMAIN=s.example.com
REDIRECT_PROTOCOL=https

# ========================================
# CDN 服务器域名配置
# ========================================
CDN_NORTH_TELECOM_DOMAIN=cdn-bj.example.com
CDN_NORTH_TELECOM_PROTOCOL=https

CDN_SOUTH_UNICOM_DOMAIN=cdn-gz.example.com
CDN_SOUTH_UNICOM_PROTOCOL=https

CDN_OVERSEAS_DOMAIN=cdn-us.example.com
CDN_OVERSEAS_PROTOCOL=https

# TC-GO 图床服务器
TC_GO_PRIMARY_DOMAIN=img.example.com
TC_GO_PRIMARY_PROTOCOL=https

TC_GO_BACKUP_DOMAIN=img-backup.example.com
TC_GO_BACKUP_PROTOCOL=https

# ========================================
# 数据库配置
# ========================================
MYSQL_PASSWORD=MyStrongPassword123!
REDIS_PASSWORD=

# ========================================
# 安全配置
# ========================================
DEFAULT_TOKEN_SECRET=random_string_here_change_in_production
ADMIN_AUTH_ENABLED=true
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin_password_here
```

### 5. 启动服务

```bash
# 确保已下载 GeoIP 数据库到 geoip/ 目录

# 启动服务
docker-compose up -d

# 查看日志确认配置
docker-compose logs openresty | grep "Redirect service"
# 输出: Redirect service: https://s.example.com
```

### 6. 创建第一个短链

#### 6.1 通过 API 创建

```bash
curl -X POST http://123.45.67.89/api/v1/links \
  -H "Content-Type: application/json" \
  -d '{
    "short_code": "test-img",
    "targets": [
      {
        "cdn": "north_telecom",
        "path": "/uploads/2024/12/photo.jpg",
        "region": "cn-north",
        "isp": "telecom",
        "weight": 5
      },
      {
        "cdn": "south_unicom",
        "path": "/uploads/2024/12/photo.jpg",
        "region": "cn-south",
        "isp": "unicom",
        "weight": 3
      },
      {
        "cdn": "overseas",
        "path": "/uploads/2024/12/photo.jpg",
        "region": "overseas",
        "weight": 2
      }
    ],
    "strategy": "geo+weight",
    "security_config": {
      "referer_whitelist": ["*.example.com", "localhost"]
    }
  }'
```

#### 6.2 直接在数据库中插入

```sql
INSERT INTO short_links (short_code, targets, strategy, security_config) VALUES (
  'test-img',
  '[
    {"cdn": "north_telecom", "path": "/uploads/2024/12/photo.jpg", "region": "cn-north", "isp": "telecom", "weight": 5},
    {"cdn": "south_unicom", "path": "/uploads/2024/12/photo.jpg", "region": "cn-south", "isp": "unicom", "weight": 3},
    {"cdn": "overseas", "path": "/uploads/2024/12/photo.jpg", "region": "overseas", "weight": 2}
  ]',
  'geo+weight',
  '{"referer_whitelist": ["*.example.com", "localhost"]}'
);
```

### 7. 测试短链

```bash
# 测试重定向
curl -I https://s.example.com/r/test-img

# 预期响应
HTTP/2 302
Location: https://cdn-bj.example.com/uploads/2024/12/photo.jpg
# (根据你的地理位置，可能重定向到不同的 CDN)

# 从不同地区测试
# 北京: Location: https://cdn-bj.example.com/uploads/2024/12/photo.jpg
# 广州: Location: https://cdn-gz.example.com/uploads/2024/12/photo.jpg
# 美国: Location: https://cdn-us.example.com/uploads/2024/12/photo.jpg
```

### 8. TC-GO 图床集成

在 TC-GO 后端代码中集成短链服务：

```go
// backend/services/shortlink_service.go
package services

import (
    "bytes"
    "encoding/json"
    "net/http"
)

type ShortLinkService struct {
    BaseURL string
}

type Target struct {
    CDN    string `json:"cdn"`
    Path   string `json:"path"`
    Region string `json:"region"`
    ISP    string `json:"isp,omitempty"`
    Weight int    `json:"weight"`
}

type CreateShortLinkRequest struct {
    ShortCode      string            `json:"short_code"`
    Targets        []Target          `json:"targets"`
    Strategy       string            `json:"strategy"`
    SecurityConfig map[string]any    `json:"security_config,omitempty"`
}

func NewShortLinkService() *ShortLinkService {
    return &ShortLinkService{
        BaseURL: "http://s.example.com/api/v1",
    }
}

func (s *ShortLinkService) CreateShortLink(filename string) (string, error) {
    req := CreateShortLinkRequest{
        ShortCode: generateShortCode(), // 实现你的短码生成逻辑
        Targets: []Target{
            {CDN: "north_telecom", Path: "/uploads/" + filename, Region: "cn-north", ISP: "telecom", Weight: 5},
            {CDN: "south_unicom", Path: "/uploads/" + filename, Region: "cn-south", ISP: "unicom", Weight: 3},
            {CDN: "overseas", Path: "/uploads/" + filename, Region: "overseas", Weight: 2},
        },
        Strategy: "geo+weight",
        SecurityConfig: map[string]any{
            "referer_whitelist": []string{"*.example.com"},
        },
    }

    body, _ := json.Marshal(req)
    resp, err := http.Post(s.BaseURL+"/links", "application/json", bytes.NewBuffer(body))
    if err != nil {
        return "", err
    }
    defer resp.Body.Close()

    return "https://s.example.com/r/" + req.ShortCode, nil
}
```

在图片上传控制器中使用：

```go
// backend/controllers/image_controller.go
func (c *ImageController) Upload(ctx *gin.Context) {
    // ... 上传逻辑 ...

    // 创建短链
    shortLinkService := services.NewShortLinkService()
    shortURL, err := shortLinkService.CreateShortLink(filename)
    if err != nil {
        log.Printf("创建短链失败: %v", err)
        // 降级到原始URL
        shortURL = "https://img.example.com/uploads/" + filename
    }

    ctx.JSON(200, gin.H{
        "url": shortURL,  // 返回短链
        "original_url": "https://img.example.com/uploads/" + filename,
        "cdn_urls": map[string]string{
            "north": "https://cdn-bj.example.com/uploads/" + filename,
            "south": "https://cdn-gz.example.com/uploads/" + filename,
            "overseas": "https://cdn-us.example.com/uploads/" + filename,
        },
    })
}
```

### 9. 前端展示

```vue
<!-- frontend/src/views/Images.vue -->
<template>
  <div class="image-card">
    <img :src="image.url" alt="图片" />
    <div class="image-info">
      <p>短链: <a :href="image.url">{{ image.url }}</a></p>
      <p>原始: <a :href="image.original_url">{{ image.original_url }}</a></p>
      <el-dropdown>
        <span>CDN 节点 <i class="el-icon-arrow-down"></i></span>
        <el-dropdown-menu slot="dropdown">
          <el-dropdown-item v-for="(url, region) in image.cdn_urls" :key="region">
            <a :href="url" target="_blank">{{ region }}: {{ url }}</a>
          </el-dropdown-item>
        </el-dropdown-menu>
      </el-dropdown>
    </div>
  </div>
</template>
```

### 10. 监控和维护

#### 10.1 查看访问统计

```bash
curl http://s.example.com/api/stats

# 响应示例
{
  "success": true,
  "data": {
    "requests": {"total": 10000, "success": 9950},
    "latency": {"avg": 3.5, "max": 50},
    "cache": {"hit_rate": 85.5},
    "region": {
      "cn-north": 5000,
      "cn-south": 3000,
      "overseas": 2000
    }
  }
}
```

#### 10.2 热更新配置

修改 `.env` 后重新加载：

```bash
# 重启服务
docker-compose restart openresty

# 或调用热更新 API
curl -X POST http://s.example.com/api/reload
```

### 11. 完成！

现在你的图床已经配置了智能 CDN 分发：

- ✅ 用户访问 `https://s.example.com/r/test-img`
- ✅ 系统根据用户地理位置自动选择最近的 CDN
- ✅ 北京用户访问北京 CDN，广州用户访问广州 CDN
- ✅ 支持健康检查和故障转移
- ✅ 支持防盗链和限流保护

享受你的高性能图床吧！ 🚀
