# 🔑 API KEY 使用指南

短链服务API KEY认证配置和使用说明。

---

## 📋 什么是API KEY

API KEY是用于验证外部应用访问短链服务API的密钥。启用后，所有创建、修改、删除短链的API请求都需要提供有效的API KEY。

**适用场景：**
- ✅ 多个应用共享同一个短链服务
- ✅ 需要控制API访问权限
- ✅ 防止未授权的短链创建
- ✅ 跟踪不同应用的API使用情况

---

## 🚀 快速开始

### 1. 生成API KEY

**方法1: 使用OpenSSL（推荐）**
```bash
# 生成32字节随机密钥
openssl rand -hex 32
# 输出示例: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0
```

**方法2: 使用Python**
```python
import secrets
print(secrets.token_hex(32))
```

**方法3: 使用PowerShell**
```powershell
$bytes = New-Object byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
[BitConverter]::ToString($bytes).Replace("-","").ToLower()
```

**方法4: 在线生成**
```
https://www.random.org/strings/
- 长度: 64
- 字符集: 十六进制
```

### 2. 配置API KEY

编辑 `.env` 文件：

```bash
# 启用API KEY验证
API_KEY_ENABLED=true

# 单个API KEY
API_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0

# 或多个API KEY（用逗号分隔）
API_KEY=imagebed-key-abc123,blog-key-def456,app-key-xyz789
```

### 3. 重启服务

```bash
docker-compose restart redirect-service
```

### 4. 测试API KEY

```bash
# 创建短链（带API KEY）
curl -X POST http://localhost/api/create \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key-here" \
  -d '{
    "url": "https://example.com/image.jpg",
    "expire": 0
  }'

# 成功响应
{
  "code": 200,
  "data": {
    "short_code": "abc123",
    "short_url": "http://localhost/abc123"
  }
}

# 无效API KEY响应
{
  "code": 401,
  "message": "Invalid API Key"
}
```

---

## 🎯 使用场景

### 场景1: 单应用接入

**适用于:** 只有一个应用（如图床）使用短链服务

```bash
# .env 配置
API_KEY_ENABLED=true
API_KEY=imagebed-secret-key-2024
API_RATE_LIMIT_MAX=1000
```

**应用侧配置:**
```go
// backend/utils/shortlink_client.go
client := NewShortLinkClient(
    "http://localhost",
    "imagebed-secret-key-2024"
)
```

---

### 场景2: 多应用接入

**适用于:** 多个应用共享短链服务，每个应用独立的API KEY

```bash
# .env 配置
API_KEY_ENABLED=true
API_KEY=imagebed-key-abc,blog-key-def,cms-key-xyz
API_RATE_LIMIT_MAX=1000
```

**应用1 - 图床:**
```go
client := NewShortLinkClient(
    "http://localhost",
    "imagebed-key-abc"
)
```

**应用2 - 博客:**
```go
client := NewShortLinkClient(
    "http://localhost",
    "blog-key-def"
)
```

**应用3 - CMS:**
```go
client := NewShortLinkClient(
    "http://localhost",
    "cms-key-xyz"
)
```

---

### 场景3: 开发/测试环境

**适用于:** 本地开发，不需要API KEY验证

```bash
# .env 配置
API_KEY_ENABLED=false
# API_KEY 可以留空
```

---

## 🔧 配置选项详解

### API_KEY_ENABLED

**类型:** Boolean
**默认值:** false
**说明:** 是否启用API KEY验证

```bash
# 启用
API_KEY_ENABLED=true

# 禁用（开发环境）
API_KEY_ENABLED=false
```

### API_KEY

**类型:** String
**格式:** 单个密钥或逗号分隔的多个密钥
**说明:** 有效的API密钥列表

```bash
# 单个密钥
API_KEY=secret-key-123

# 多个密钥（推荐）
API_KEY=key1,key2,key3

# 带标识的密钥（便于管理）
API_KEY=imagebed-2024-key,blog-prod-key,test-dev-key
```

### API_RATE_LIMIT_MAX

**类型:** Integer
**默认值:** 1000
**说明:** 每个API KEY在时间窗口内的最大请求数

```bash
# 高并发应用
API_RATE_LIMIT_MAX=5000

# 普通应用
API_RATE_LIMIT_MAX=1000

# 限制较严
API_RATE_LIMIT_MAX=100
```

### API_RATE_LIMIT_WINDOW

**类型:** Integer
**默认值:** 60
**单位:** 秒
**说明:** 限流时间窗口

```bash
# 每分钟
API_RATE_LIMIT_WINDOW=60

# 每小时
API_RATE_LIMIT_WINDOW=3600
```

---

## 📡 API调用方式

### HTTP Header方式（推荐）

```bash
curl -X POST http://localhost/api/create \
  -H "X-API-Key: your-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/file.jpg"}'
```

### Query参数方式

```bash
curl -X POST "http://localhost/api/create?api_key=your-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/file.jpg"}'
```

### Body方式（不推荐，密钥可能被记录）

```bash
curl -X POST http://localhost/api/create \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com/file.jpg",
    "api_key": "your-api-key-here"
  }'
```

**最佳实践:** 使用HTTP Header方式，安全且不会被URL记录。

---

## 🔐 安全建议

### ✅ DO（推荐做法）

1. **使用强随机密钥**
   ```bash
   # 至少32字节（64个十六进制字符）
   openssl rand -hex 32
   ```

2. **定期轮换密钥**
   ```bash
   # 每3-6个月更换一次
   # 使用多个密钥实现平滑过渡
   ```

3. **不同应用使用不同密钥**
   ```bash
   API_KEY=app1-key,app2-key,app3-key
   ```

4. **启用限流保护**
   ```bash
   API_RATE_LIMIT_MAX=1000
   API_RATE_LIMIT_WINDOW=60
   ```

5. **使用环境变量**
   ```bash
   # 不要硬编码在代码中
   apiKey := os.Getenv("SHORT_LINK_API_KEY")
   ```

6. **记录API使用日志**
   ```bash
   LOG_LEVEL=info  # 记录API调用
   ```

### ❌ DON'T（避免做法）

1. **不要使用弱密钥**
   ```bash
   # ❌ 太简单
   API_KEY=123456

   # ❌ 可预测
   API_KEY=admin,password,secret
   ```

2. **不要在URL中传递**
   ```bash
   # ❌ 会被日志记录
   curl http://localhost/api/create?api_key=secret
   ```

3. **不要提交到Git**
   ```bash
   # 确保 .env 在 .gitignore 中
   echo ".env" >> .gitignore
   ```

4. **不要共享密钥**
   ```bash
   # ❌ 所有应用用同一个密钥
   # ✅ 每个应用独立密钥
   ```

5. **不要禁用限流**
   ```bash
   # ❌ 容易被滥用
   API_RATE_LIMIT_MAX=999999
   ```

---

## 🔍 监控和审计

### 查看API使用情况

```sql
-- 查询各API KEY的使用次数
SELECT
    api_key,
    COUNT(*) as total_requests,
    DATE(created_at) as date
FROM short_links
WHERE api_key IS NOT NULL
GROUP BY api_key, DATE(created_at)
ORDER BY date DESC, total_requests DESC;
```

### 查看限流日志

```bash
# 查看被限流的请求
docker-compose logs redirect-service | grep "Rate limit exceeded"

# 查看特定API KEY的请求
docker-compose logs redirect-service | grep "api_key=imagebed-key"
```

### 实时监控

```bash
# 监控API调用
tail -f logs/access.log | grep "X-API-Key"

# 统计每个API KEY的请求数
tail -f logs/access.log | awk -F'api_key=' '{print $2}' | sort | uniq -c
```

---

## 🚨 故障排查

### ❓ 401 Unauthorized

**错误信息:**
```json
{
  "code": 401,
  "message": "API Key required"
}
```

**原因:** 启用了API KEY验证但未提供密钥

**解决方案:**
```bash
# 方法1: 添加API KEY
curl -H "X-API-Key: your-key" ...

# 方法2: 禁用验证（仅开发环境）
API_KEY_ENABLED=false
```

---

### ❓ 401 Invalid API Key

**错误信息:**
```json
{
  "code": 401,
  "message": "Invalid API Key"
}
```

**原因:** 提供的API KEY不在允许列表中

**解决方案:**
```bash
# 检查 .env 中的 API_KEY 配置
cat .env | grep API_KEY

# 确认使用的密钥是否匹配
```

---

### ❓ 429 Too Many Requests

**错误信息:**
```json
{
  "code": 429,
  "message": "Rate limit exceeded"
}
```

**原因:** 超过API KEY的请求限制

**解决方案:**
```bash
# 方法1: 增加限流配置
API_RATE_LIMIT_MAX=5000

# 方法2: 等待限流窗口重置
# 默认60秒后自动重置

# 方法3: 使用多个API KEY分散请求
API_KEY=key1,key2,key3
```

---

### ❓ API KEY配置未生效

**检查清单:**

1. **确认.env文件已加载**
   ```bash
   docker-compose config | grep API_KEY
   ```

2. **重启服务**
   ```bash
   docker-compose restart redirect-service
   ```

3. **检查配置语法**
   ```bash
   # 确保没有多余空格
   API_KEY=key1,key2,key3  # ✅
   API_KEY= key1, key2     # ❌ 有空格
   ```

4. **查看服务日志**
   ```bash
   docker-compose logs redirect-service | grep -i "api"
   ```

---

## 📊 性能影响

### API KEY验证性能

| 操作 | 延迟 | 说明 |
|------|------|------|
| 无验证 | ~1ms | 直接处理 |
| 单密钥验证 | ~2ms | 简单字符串比较 |
| 多密钥验证 | ~3ms | 遍历密钥列表 |
| 限流检查 | ~5ms | Redis计数器 |

**优化建议:**
- ✅ 将API KEY配置缓存到内存
- ✅ 使用Redis存储限流计数器
- ✅ 合理设置限流参数
- ✅ 监控API响应时间

---

## 🔄 密钥轮换策略

### 无缝轮换流程

**步骤1: 添加新密钥（不删除旧密钥）**
```bash
# 当前配置
API_KEY=old-key

# 添加新密钥
API_KEY=old-key,new-key
```

**步骤2: 更新应用配置使用新密钥**
```go
// 逐步迁移各个应用
apiKey := "new-key"
```

**步骤3: 监控旧密钥使用情况**
```sql
-- 查看旧密钥是否还在使用
SELECT COUNT(*) FROM access_logs
WHERE api_key = 'old-key'
AND created_at > NOW() - INTERVAL 7 DAY;
```

**步骤4: 移除旧密钥**
```bash
# 确认无使用后移除
API_KEY=new-key
```

### 定期轮换计划

```bash
# 建议每季度轮换一次
Q1: key-2024-q1
Q2: key-2024-q2
Q3: key-2024-q3
Q4: key-2024-q4
```

---

## 📚 相关文档

- [配置向导](./CONFIG_WIZARD.md) - 完整配置指南
- [API文档](./API.md) - 短链API详细说明
- [安全指南](./SECURITY.md) - 安全最佳实践

---

## 💡 常见问题

**Q: 可以为每个API KEY设置不同的限流吗？**
A: 当前版本所有API KEY共享限流配置。如需独立限流，建议在应用层实现。

**Q: API KEY可以设置过期时间吗？**
A: 当前版本不支持自动过期，建议定期手动轮换密钥。

**Q: 如何追踪哪个应用使用了哪个API KEY？**
A: 建议在密钥中包含应用标识，如 `imagebed-key-abc`，便于日志分析。

**Q: 忘记API KEY怎么办？**
A: 检查 `.env` 文件或联系管理员。可以生成新密钥并更新配置。

---

**更新日期:** 2024-12-07
**版本:** v1.0
