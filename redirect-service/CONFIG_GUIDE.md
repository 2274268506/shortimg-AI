# 配置指南

## 配置文件说明

### 1. 配置文件位置

- **Lua 配置**: `conf/config.lua` - 主配置文件
- **环境变量**: `.env` - 环境变量配置（从 `.env.example` 复制）

### 2. 域名配置

#### 2.1 重定向服务域名

重定向服务的短链域名，用户访问的域名：

```bash
# .env 文件
REDIRECT_DOMAIN=short.yourdomain.com
REDIRECT_PROTOCOL=https
```

生成的短链格式：`https://short.yourdomain.com/r/{short_code}`

#### 2.2 CDN 服务器域名配置

配置各个 CDN 服务器的域名，这些是重定向的目标服务器：

```bash
# 北方电信 CDN
CDN_NORTH_TELECOM_DOMAIN=cdn-bj.yourdomain.com
CDN_NORTH_TELECOM_PROTOCOL=https

# 南方联通 CDN
CDN_SOUTH_UNICOM_DOMAIN=cdn-gz.yourdomain.com
CDN_SOUTH_UNICOM_PROTOCOL=https

# 海外 CDN
CDN_OVERSEAS_DOMAIN=cdn-us.yourdomain.com
CDN_OVERSEAS_PROTOCOL=https

# TC-GO 图床主服务器
TC_GO_PRIMARY_DOMAIN=img.yourdomain.com
TC_GO_PRIMARY_PROTOCOL=https

# TC-GO 图床备用服务器
TC_GO_BACKUP_DOMAIN=img-backup.yourdomain.com
TC_GO_BACKUP_PROTOCOL=https

# 降级服务器
CDN_FALLBACK_DOMAIN=static.yourdomain.com
CDN_FALLBACK_PROTOCOL=https
```

### 3. 短链配置示例

#### 3.1 数据库中的短链配置

在 MySQL 的 `short_links` 表中，`targets` 字段存储 JSON 格式的目标配置：

```json
{
  "short_code": "img-abc123",
  "targets": [
    {
      "cdn": "north_telecom",
      "path": "/uploads/2024/12/image.jpg",
      "region": "cn-north",
      "isp": "telecom",
      "weight": 5
    },
    {
      "cdn": "south_unicom",
      "path": "/uploads/2024/12/image.jpg",
      "region": "cn-south",
      "isp": "unicom",
      "weight": 3
    },
    {
      "cdn": "overseas",
      "path": "/uploads/2024/12/image.jpg",
      "region": "overseas",
      "weight": 2
    }
  ],
  "strategy": "geo+weight"
}
```

#### 3.2 目标 URL 生成

配置中的 `cdn` 字段对应 `config.lua` 中的 CDN 名称：

| cdn 值 | 对应配置 | 生成的完整 URL |
|--------|----------|---------------|
| `north_telecom` | `cdn_servers.north_telecom` | `https://cdn-bj.yourdomain.com/uploads/2024/12/image.jpg` |
| `south_unicom` | `cdn_servers.south_unicom` | `https://cdn-gz.yourdomain.com/uploads/2024/12/image.jpg` |
| `overseas` | `cdn_servers.overseas` | `https://cdn-us.yourdomain.com/uploads/2024/12/image.jpg` |
| `tc_go_primary` | `cdn_servers.tc_go_primary` | `https://img.yourdomain.com/uploads/2024/12/image.jpg` |

### 4. 使用场景示例

#### 场景 1: 图片 CDN 加速

**需求**: 将图片分发到多个 CDN，根据用户地理位置选择最优节点

**配置步骤**:

1. 在 `.env` 中配置各地 CDN 域名：
```bash
CDN_NORTH_TELECOM_DOMAIN=cdn-bj.example.com
CDN_SOUTH_UNICOM_DOMAIN=cdn-gz.example.com
CDN_OVERSEAS_DOMAIN=cdn-us.example.com
```

2. 创建短链（通过 API）：
```bash
curl -X POST http://localhost/api/v1/links \
  -H "Content-Type: application/json" \
  -d '{
    "short_code": "img-123",
    "targets": [
      {"cdn": "north_telecom", "path": "/images/photo.jpg", "region": "cn-north", "weight": 5},
      {"cdn": "south_unicom", "path": "/images/photo.jpg", "region": "cn-south", "weight": 3},
      {"cdn": "overseas", "path": "/images/photo.jpg", "region": "overseas", "weight": 2}
    ],
    "strategy": "geo+weight"
  }'
```

3. 用户访问：
```
https://short.example.com/r/img-123
↓ 北京用户 → https://cdn-bj.example.com/images/photo.jpg
↓ 广州用户 → https://cdn-gz.example.com/images/photo.jpg
↓ 美国用户 → https://cdn-us.example.com/images/photo.jpg
```

#### 场景 2: TC-GO 图床集成

**需求**: 图床上传后自动分发到主备服务器

**配置步骤**:

1. 配置图床域名：
```bash
TC_GO_PRIMARY_DOMAIN=img.example.com
TC_GO_BACKUP_DOMAIN=img-backup.example.com
```

2. 在 TC-GO 后端集成：
```go
// backend/controllers/image_controller.go
func (c *ImageController) Upload(ctx *gin.Context) {
    // ... 上传图片逻辑 ...

    // 创建短链
    shortCode := generateShortCode()
    createShortLink(shortCode, []Target{
        {CDN: "tc_go_primary", Path: "/uploads/" + filename, Weight: 5},
        {CDN: "tc_go_backup", Path: "/uploads/" + filename, Weight: 3},
    })

    // 返回短链
    ctx.JSON(200, gin.H{
        "short_url": "https://short.example.com/r/" + shortCode,
        "original_url": "https://img.example.com/uploads/" + filename,
    })
}
```

### 5. 环境变量优先级

配置加载顺序（优先级从高到低）：

1. **环境变量**: Docker/系统环境变量
2. **`.env` 文件**: 本地环境变量文件
3. **默认值**: `config.lua` 中的 `or` 默认值

### 6. 配置热更新

修改配置后，重新加载：

```bash
# 方法 1: 调用热更新 API
curl -X POST http://localhost/api/reload

# 方法 2: 重启 OpenResty
docker-compose restart openresty

# 方法 3: 热重载 Nginx（不中断服务）
docker exec short-link-openresty nginx -s reload
```

### 7. 配置验证

检查配置是否正确加载：

```bash
# 查看日志
docker-compose logs openresty | grep "Loading configuration"

# 应该看到类似输出：
# Loading configuration...
# Redirect service: https://short.example.com
# Redis initialized: redis:6379
# MySQL initialized: mysql:3306
# GeoIP databases loaded
# Health checker started
```

### 8. 安全建议

1. **生产环境配置**:
   - 修改所有默认密码
   - 使用强随机 Token 密钥
   - 启用 HTTPS
   - 配置防火墙规则

2. **敏感信息保护**:
   - 不要将 `.env` 文件提交到 Git
   - 使用 Docker secrets 或密钥管理服务
   - 定期轮换密码和密钥

3. **域名配置**:
   - 确保所有域名都配置了 DNS
   - 配置 SSL 证书
   - 启用 HSTS

### 9. 故障排查

#### 问题 1: 重定向到错误的域名

**检查步骤**:
```bash
# 1. 查看配置是否加载
docker exec short-link-openresty cat /usr/local/openresty/nginx/conf/config.lua

# 2. 检查环境变量
docker exec short-link-openresty env | grep CDN

# 3. 测试短链
curl -I http://localhost/r/test-code
```

#### 问题 2: 域名解析失败

**检查步骤**:
```bash
# 1. 检查 DNS 解析
docker exec short-link-openresty nslookup cdn-north.example.com

# 2. 检查网络连通性
docker exec short-link-openresty ping cdn-north.example.com

# 3. 查看健康检查日志
docker-compose logs openresty | grep "Health check"
```

### 10. 配置模板

#### 开发环境配置
```bash
# .env.development
REDIRECT_DOMAIN=localhost
REDIRECT_PROTOCOL=http
CDN_NORTH_TELECOM_DOMAIN=localhost:8081
CDN_SOUTH_UNICOM_DOMAIN=localhost:8082
```

#### 测试环境配置
```bash
# .env.staging
REDIRECT_DOMAIN=short-staging.example.com
REDIRECT_PROTOCOL=https
CDN_NORTH_TELECOM_DOMAIN=cdn-staging-north.example.com
```

#### 生产环境配置
```bash
# .env.production
REDIRECT_DOMAIN=s.example.com
REDIRECT_PROTOCOL=https
CDN_NORTH_TELECOM_DOMAIN=cdn-bj1.example.com
CDN_SOUTH_UNICOM_DOMAIN=cdn-gz1.example.com
CDN_OVERSEAS_DOMAIN=cdn-us1.example.com
ADMIN_AUTH_ENABLED=true
ADMIN_PASSWORD=strong_random_password_here
```
