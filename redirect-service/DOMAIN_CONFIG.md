# 域名配置功能说明

## 更新内容

已实现**完全可配置的域名系统**，支持通过环境变量灵活配置所有域名，无需修改代码。

## 新增文件

### 1. 配置文件
- **`conf/config.lua`** - Lua 主配置文件
  - 定义所有可配置的域名参数
  - 支持环境变量读取
  - 提供默认值降级
  - 包含辅助函数 `get_cdn_url()`

### 2. 环境变量配置
- **`.env.example`** - 环境变量配置模板
  - 包含所有可配置项的示例
  - 详细的注释说明
  - 生产环境配置建议

- **`.gitignore`** - Git 忽略规则
  - 保护敏感配置文件 `.env`
  - 忽略日志、证书等文件

### 3. 文档
- **`CONFIG_GUIDE.md`** - 完整配置指南
  - 域名配置详解
  - 使用场景示例
  - 故障排查指南
  - 安全建议

- **`QUICKSTART.md`** - 快速开始指南
  - 实际场景演示（TC-GO 图床）
  - DNS 配置步骤
  - 代码集成示例
  - 监控和维护

## 核心功能

### 1. 可配置的域名

#### 短链服务域名
```bash
REDIRECT_DOMAIN=s.yourdomain.com      # 用户访问的短链域名
REDIRECT_PROTOCOL=https                # 协议 (http/https)
```

#### CDN 服务器域名
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

# TC-GO 图床
TC_GO_PRIMARY_DOMAIN=img.yourdomain.com
TC_GO_PRIMARY_PROTOCOL=https

TC_GO_BACKUP_DOMAIN=img-backup.yourdomain.com
TC_GO_BACKUP_PROTOCOL=https

# 降级服务器
CDN_FALLBACK_DOMAIN=static.yourdomain.com
CDN_FALLBACK_PROTOCOL=https
```

### 2. 域名映射机制

在数据库中，使用 CDN 名称标识，而非硬编码 URL：

```json
{
  "targets": [
    {
      "cdn": "north_telecom",
      "path": "/uploads/image.jpg",
      "region": "cn-north",
      "weight": 5
    }
  ]
}
```

系统会自动将 `cdn: "north_telecom"` 映射到配置的域名：
```
north_telecom + /uploads/image.jpg
↓
https://cdn-bj.yourdomain.com/uploads/image.jpg
```

### 3. 环境变量优先级

```
1. Docker/系统环境变量（最高优先级）
2. .env 文件
3. config.lua 中的默认值（最低优先级）
```

### 4. 热更新支持

修改 `.env` 后，可以通过以下方式生效：

```bash
# 方式 1: 重启容器
docker-compose restart openresty

# 方式 2: 热重载 Nginx
docker exec short-link-openresty nginx -s reload

# 方式 3: API 热更新
curl -X POST http://localhost/api/reload
```

## 使用示例

### 场景 1: 开发环境

```bash
# .env.development
REDIRECT_DOMAIN=localhost
REDIRECT_PROTOCOL=http
CDN_NORTH_TELECOM_DOMAIN=localhost:8081
CDN_SOUTH_UNICOM_DOMAIN=localhost:8082
```

### 场景 2: 生产环境

```bash
# .env.production
REDIRECT_DOMAIN=s.example.com
REDIRECT_PROTOCOL=https
CDN_NORTH_TELECOM_DOMAIN=cdn-bj1.example.com
CDN_SOUTH_UNICOM_DOMAIN=cdn-gz1.example.com
CDN_OVERSEAS_DOMAIN=cdn-us1.example.com
```

### 场景 3: 使用第三方 CDN

```bash
# 使用阿里云 CDN
CDN_NORTH_TELECOM_DOMAIN=your-domain.alikunlun.com

# 使用腾讯云 CDN
CDN_SOUTH_UNICOM_DOMAIN=your-domain.cdn.dnsv1.com

# 使用 Cloudflare
CDN_OVERSEAS_DOMAIN=your-domain.cdn.cloudflare.net
```

## 配置验证

### 1. 检查环境变量

```bash
# 查看容器内环境变量
docker exec short-link-openresty env | grep DOMAIN

# 输出示例
REDIRECT_DOMAIN=s.example.com
CDN_NORTH_TELECOM_DOMAIN=cdn-bj.example.com
```

### 2. 检查日志

```bash
# 查看启动日志
docker-compose logs openresty | grep "Redirect service"

# 输出示例
Redirect service: https://s.example.com
```

### 3. 测试重定向

```bash
# 测试短链
curl -I http://localhost/r/test-code

# 应返回 302 重定向到配置的 CDN 域名
Location: https://cdn-bj.example.com/path/to/resource
```

## 集成到 TC-GO

### 后端集成

在 `backend/config/config.go` 添加短链服务配置：

```go
type Config struct {
    // ... 其他配置

    ShortLink struct {
        BaseURL   string `mapstructure:"base_url"`    // https://s.example.com
        APIKey    string `mapstructure:"api_key"`     // API 密钥
    } `mapstructure:"short_link"`
}
```

在上传控制器中调用：

```go
// 创建短链
shortLinkService := services.NewShortLinkService(config.ShortLink.BaseURL)
shortURL, _ := shortLinkService.Create(filename)

// 返回短链 URL
ctx.JSON(200, gin.H{
    "url": shortURL,  // https://s.example.com/r/abc123
})
```

### 前端集成

在前端显示短链和原始 URL：

```vue
<el-input v-model="imageURL" readonly>
  <el-button slot="append" @click="copyURL">复制短链</el-button>
</el-input>
<p>CDN: {{ cdnURL }}</p>
```

## 优势

1. **灵活性**: 可随时更换 CDN 提供商，无需修改代码
2. **多环境**: 开发/测试/生产环境使用不同域名
3. **安全性**: 敏感配置不提交到 Git
4. **可维护**: 集中管理所有域名配置
5. **可扩展**: 轻松添加新的 CDN 节点

## 文档索引

- **配置指南**: [CONFIG_GUIDE.md](CONFIG_GUIDE.md)
- **快速开始**: [QUICKSTART.md](QUICKSTART.md)
- **部署指南**: [DEPLOYMENT.md](DEPLOYMENT.md)
- **项目文档**: [README.md](README.md)
- **项目总结**: [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)

## 总结

现在重定向服务支持完全可配置的域名系统：

✅ 所有域名都可以通过环境变量配置
✅ 支持多环境配置（开发/测试/生产）
✅ 支持热更新，无需重启服务
✅ 完整的文档和使用示例
✅ 集成到 TC-GO 图床的完整方案

你可以根据实际情况灵活配置各个 CDN 节点的域名，实现智能分流和高可用！
