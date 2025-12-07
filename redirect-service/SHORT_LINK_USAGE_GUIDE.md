# 短链使用指南

## 🎯 问题解决：PR_END_OF_FILE_ERROR

### 问题原因
访问短链时出现 `PR_END_OF_FILE_ERROR` 错误，是因为：

1. **配置问题**：短链的target使用了 `cdn: "default"`，但系统配置中的CDN域名都是示例域名（如 `cdn-fallback.example.com`）
2. **HTTPS证书**：浏览器尝试访问HTTPS的示例域名时，无法建立安全连接

### 解决方案

#### ✅ 已修复内容

1. **添加default CDN支持** - 在 `config.lua` 中添加了 `default` CDN配置
2. **配置本地开发环境** - 修改 `.env` 文件，将所有CDN域名改为 `localhost`，协议改为 `http`

现在访问短链会跳转到：`http://localhost/path` 而不是 `https://cdn-fallback.example.com/path`

## 📝 创建短链的正确方式

### 方式1: 使用完整URL（推荐用于外部资源）

```json
{
  "short_code": "test12chars1",
  "service_type": "general",
  "strategy": "weight",
  "targets": [
    {
      "url": "https://www.baidu.com",
      "weight": 1
    }
  ]
}
```

**测试**:
```bash
curl -X POST "http://localhost/api/v1/links" \
  -H "X-API-Key: sk_test_12345678901234567890123456789012" \
  -H "Content-Type: application/json" \
  -d '{
    "short_code": "test12chars1",
    "service_type": "general",
    "strategy": "weight",
    "targets": [{"url": "https://www.baidu.com", "weight": 1}]
  }'
```

访问: `http://localhost/test12chars1` → 跳转到 `https://www.baidu.com`

### 方式2: 使用CDN + Path（用于自有CDN资源）

```json
{
  "short_code": "img12chars01",
  "service_type": "imagebed",
  "strategy": "weight",
  "targets": [
    {
      "cdn": "tc_go_primary",
      "path": "/uploads/2025/12/image.jpg",
      "weight": 1
    }
  ]
}
```

**可用的CDN标识**:
- `north_telecom` - 北方电信CDN（本地开发: localhost）
- `south_unicom` - 南方联通CDN（本地开发: localhost）
- `overseas` - 海外CDN（本地开发: localhost）
- `tc_go_primary` - TC-GO图床主服务器（本地开发: localhost）
- `tc_go_backup` - TC-GO图床备用服务器（本地开发: localhost）
- `default` / `fallback` - 默认/降级服务器（本地开发: localhost）

### 方式3: 混合策略（多目标负载均衡）

```json
{
  "short_code": "multi12char1",
  "service_type": "cdn",
  "strategy": "weight",
  "targets": [
    {
      "url": "https://cdn1.example.com/file.jpg",
      "weight": 60
    },
    {
      "url": "https://cdn2.example.com/file.jpg",
      "weight": 30
    },
    {
      "cdn": "fallback",
      "path": "/backup/file.jpg",
      "weight": 10
    }
  ]
}
```

## 🔧 生产环境配置

### 修改 .env 文件

```bash
# 重定向服务配置
REDIRECT_DOMAIN=short.yourdomain.com
REDIRECT_PROTOCOL=https

# CDN 服务器配置
CDN_NORTH_TELECOM_DOMAIN=cdn-north.yourdomain.com
CDN_NORTH_TELECOM_PROTOCOL=https

CDN_SOUTH_UNICOM_DOMAIN=cdn-south.yourdomain.com
CDN_SOUTH_UNICOM_PROTOCOL=https

# 图床服务器
TC_GO_PRIMARY_DOMAIN=img.yourdomain.com
TC_GO_PRIMARY_PROTOCOL=https

TC_GO_BACKUP_DOMAIN=img-backup.yourdomain.com
TC_GO_BACKUP_PROTOCOL=https

# 降级服务器
CDN_FALLBACK_DOMAIN=cdn-fallback.yourdomain.com
CDN_FALLBACK_PROTOCOL=https
```

### 配置HTTPS证书

在 `docker-compose.yml` 中取消注释：

```yaml
volumes:
  - ./ssl/cert.pem:/etc/nginx/ssl/cert.pem:ro
  - ./ssl/key.pem:/etc/nginx/ssl/key.pem:ro
```

## 🧪 测试本地短链

### 1. 创建指向真实网站的短链

```bash
curl -X POST "http://localhost/api/v1/links" \
  -H "X-API-Key: sk_test_12345678901234567890123456789012" \
  -H "Content-Type: application/json" \
  -d '{
    "short_code": "go2baidu001",
    "service_type": "general",
    "strategy": "weight",
    "targets": [{"url": "https://www.baidu.com", "weight": 1}]
  }'
```

### 2. 访问短链

浏览器访问: `http://localhost/go2baidu001`

应该会重定向到: `https://www.baidu.com`

### 3. 查看短链详情

```bash
curl "http://localhost/api/v1/links/go2baidu001" \
  -H "X-API-Key: sk_test_12345678901234567890123456789012"
```

## 📊 前端创建短链

在Dashboard界面（`http://localhost/dashboard/`）创建短链时：

### 基本信息步骤
1. **短链码**: 自动生成12位或手动输入
2. **服务类型**: 选择 `general`、`imagebed`、`cdn`、`redirect`、`api`

### 目标配置步骤

**选项A: 使用完整URL**
- URL: `https://www.example.com/page`
- 权重: `1`

**选项B: 使用CDN+路径**
- CDN: 选择 `tc_go_primary`、`north_telecom` 等
- 路径: `/uploads/image.jpg`
- 权重: `1`

### 高级设置步骤
- 选择重定向策略（权重、轮询、最少连接等）
- 设置过期时间（可选）

## ⚠️ 注意事项

1. **本地开发环境**
   - 使用 `http://localhost` 而不是 `https`
   - CDN路径指向的资源必须存在，否则会404

2. **生产环境**
   - 配置真实的域名和HTTPS证书
   - 确保CDN服务器可访问
   - 配置防火墙规则

3. **短链码规则**
   - 长度：12个字符（推荐）
   - 字符集：`0-9a-zA-Z`
   - 唯一性：不能重复

4. **Target配置**
   - 必须包含 `url` 或 `cdn + path`
   - 权重总和建议为100（非强制）
   - 至少配置一个target

## 🔍 故障排查

### 问题1: 访问短链返回404
**原因**: 短链不存在或已删除
**解决**: 检查短链是否创建成功，查看status字段

### 问题2: PR_END_OF_FILE_ERROR
**原因**: CDN域名配置错误，使用了不存在的HTTPS域名
**解决**:
- 本地开发：使用完整URL方式创建短链
- 生产环境：配置真实的CDN域名

### 问题3: 重定向循环
**原因**: Target URL指向短链服务本身
**解决**: 检查target配置，避免循环引用

### 问题4: 环境变量不生效
**解决**:
```bash
docker-compose down
docker-compose up -d
```

## 📚 相关文档

- [API_KEY_SETUP.md](./API_KEY_SETUP.md) - API认证配置
- [SERVICE_TYPE_INTEGRATION.md](./SERVICE_TYPE_INTEGRATION.md) - 服务类型集成
- [.env.example](./.env.example) - 环境变量配置示例
