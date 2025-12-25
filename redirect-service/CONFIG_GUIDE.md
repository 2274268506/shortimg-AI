# 短链服务配置说明

## 📋 配置文件清单

### 环境变量文件
- `.env.production` - 生产环境配置模板
- `.env.example` - 开发环境配置示例
- `.env.prod` - 当前生产环境配置（包含敏感信息，不应提交）
- `.env` - 本地环境配置（包含敏感信息，不应提交）

### Docker 配置
- `docker-compose.yml` - 开发环境 Docker Compose 配置
- `docker-compose.prod.yml` - 生产环境 Docker Compose 配置
- `Dockerfile` - OpenResty 容器镜像构建文件
- `docker-entrypoint.sh` - 容器启动脚本（包含 API Key 自动注册）

### OpenResty 配置
- `conf/nginx.conf` - Nginx 主配置文件
- `conf/config.lua` - Lua 配置加载脚本
- `conf/upstream.conf` - 上游服务器配置

### 路由配置
- `routing_rules.yaml` - 路由规则配置
- `routing_rules.yaml.example` - 路由规则配置示例

## 🔑 关键配置说明

### 1. API Key 配置

**重要**：API Key 必须与图床服务完全一致！

```bash
# redirect-service/.env
DASHBOARD_API_KEY=twmxRnag7fBd6YuEi1KWNJFjTV9OUvqCo2zpXbrLG05HMk83c4hPQelDIyAsSZ
API_KEY=twmxRnag7fBd6YuEi1KWNJFjTV9OUvqCo2zpXbrLG05HMk83c4hPQelDIyAsSZ

# backend/.env
SHORT_LINK_API_KEY=twmxRnag7fBd6YuEi1KWNJFjTV9OUvqCo2zpXbrLG05HMk83c4hPQelDIyAsSZ
```

**API Key 自动注册流程**：
1. 容器启动时执行 `docker-entrypoint.sh`
2. 脚本读取 `IMAGEBED_API_KEY` 或 `API_KEY` 环境变量
3. 自动注册到 Redis 数据库1
4. Key 格式：`api_key:<完整API密钥>`
5. Value 格式：JSON，包含 name, status, expires_at, created_at, permissions

### 2. Redis 配置

**重要**：必须使用数据库1！

```bash
REDIS_HOST=shortlink-redis-prod
REDIS_PORT=6379
REDIS_PASSWORD=lrF8De47PIscgY0CjXq9ibRafwNWZ2Hp
REDIS_DB=1  # ⚠️ 必须是 1，与图床服务统一
```

**Redis 数据库用途**：
- 数据库0：通用缓存
- 数据库1：API Key、短链数据、访问统计

**docker-entrypoint.sh 修复**：
```bash
# 确保 Redis CLI 包含数据库选择参数
REDIS_CLI="redis-cli -h $REDIS_HOST -p $REDIS_PORT"
if [ -n "$REDIS_PASSWORD" ]; then
    REDIS_CLI="$REDIS_CLI -a $REDIS_PASSWORD"
fi
if [ -n "$REDIS_DATABASE" ]; then
    REDIS_CLI="$REDIS_CLI -n $REDIS_DATABASE"  # 关键修复
fi
```

### 3. 域名配置

```bash
# 短链服务域名
REDIRECT_DOMAIN=short.oxvxo.link
REDIRECT_PROTOCOL=https

# 图床服务域名
TC_GO_PRIMARY_DOMAIN=img.oxvxo.link
TC_GO_PRIMARY_PROTOCOL=https
```

### 4. CDN 路由配置

#### 路由模式
```bash
# direct: 直连主服务器（推荐用于单服务器部署）
# auto: 自动根据地理位置路由（需要配置 CDN 节点）
# manual: 使用 routing_rules.yaml 自定义规则
CDN_ROUTING_MODE=direct
```

#### CDN 节点配置
```bash
# 联通用户 CDN
CDN_IMAGEBED_UNICOM_DOMAIN=img.oxvxo.link
CDN_IMAGEBED_UNICOM_PROTOCOL=https

# 移动用户 CDN
CDN_IMAGEBED_MOBILE_DOMAIN=img.oxvxo.link
CDN_IMAGEBED_MOBILE_PROTOCOL=https

# 电信用户 CDN
CDN_IMAGEBED_TELECOM_DOMAIN=img.oxvxo.link
CDN_IMAGEBED_TELECOM_PROTOCOL=https

# 海外用户 CDN
CDN_IMAGEBED_OVERSEAS_DOMAIN=img.oxvxo.link
CDN_IMAGEBED_OVERSEAS_PROTOCOL=https

# 默认 CDN（无法识别地区时使用）
CDN_IMAGEBED_DEFAULT_DOMAIN=img.oxvxo.link
CDN_IMAGEBED_DEFAULT_PROTOCOL=https
```

## 🐛 常见配置问题

### 问题1: API 认证失败

**症状**：创建短链时返回 "Authentication failed"

**原因**：
1. API Key 不一致
2. API Key 未注册到 Redis 数据库1
3. Redis 连接配置错误

**解决步骤**：
```bash
# 1. 检查图床服务的 API Key
ssh imagebed-server
docker exec shortimg-backend-prod env | grep SHORT_LINK_API_KEY

# 2. 检查短链服务的 API Key
ssh shortlink-server
docker exec shortlink-openresty-prod env | grep API_KEY

# 3. 检查 Redis 中的 API Key
docker exec shortlink-redis-prod redis-cli -a <password> -n 1 KEYS 'api_key:*'

# 4. 查看 API Key 详情
docker exec shortlink-redis-prod redis-cli -a <password> -n 1 GET 'api_key:<完整API密钥>'

# 5. 如果不存在，重启容器让其自动注册
docker-compose -f docker-compose.prod.yml restart openresty
```

### 问题2: Redis 连接失败

**症状**：日志显示 "connection refused" 或 "authentication failed"

**解决步骤**：
```bash
# 1. 检查 Redis 容器状态
docker ps | grep redis

# 2. 测试 Redis 连接
docker exec shortlink-openresty-prod redis-cli -h shortlink-redis-prod -p 6379 -a <password> ping

# 3. 检查网络连接
docker exec shortlink-openresty-prod ping shortlink-redis-prod

# 4. 检查环境变量
docker exec shortlink-openresty-prod env | grep REDIS
```

### 问题3: lua/storage/redis_client.lua 硬编码配置

**历史问题**：早期版本使用硬编码配置
```lua
-- 错误的配置（已修复）
local config = {
    host = "127.0.0.1",
    port = 6379,
    password = nil,
    database = 0,
}
```

**正确配置**：
```lua
-- 从环境变量加载配置
local app_config = require "conf.config"
local config = app_config.redis or {
    host = "127.0.0.1",
    port = 6379,
    password = nil,
    database = 0,
}
```

**验证修复**：
```bash
# 查看 redis_client.lua 头部
docker exec shortlink-openresty-prod head -20 /usr/local/openresty/nginx/lua/storage/redis_client.lua
```

## 📝 配置检查清单

部署前请检查以下配置：

### 必须配置
- [ ] `MYSQL_PASSWORD` - MySQL 密码
- [ ] `REDIS_PASSWORD` - Redis 密码
- [ ] `REDIS_DB=1` - Redis 数据库编号
- [ ] `DASHBOARD_API_KEY` - API 密钥（与图床服务一致）
- [ ] `API_KEY` - API 密钥（与 DASHBOARD_API_KEY 相同）
- [ ] `REDIRECT_DOMAIN` - 短链服务域名
- [ ] `TC_GO_PRIMARY_DOMAIN` - 图床服务域名

### 推荐配置
- [ ] `ADMIN_PASSWORD` - 管理员密码
- [ ] `CDN_ROUTING_MODE` - 路由模式（默认 direct）
- [ ] `ENABLE_GEOIP` - 启用地理位置路由
- [ ] `LOG_LEVEL` - 日志级别（生产环境建议 info）

### 可选配置
- [ ] CDN 节点域名（如果使用 auto 路由模式）
- [ ] 备用图床服务器
- [ ] Prometheus 监控
- [ ] 限流配置

## 🔄 配置更新流程

### 更新环境变量
```bash
# 1. 编辑 .env 文件
nano .env

# 2. 重新创建容器（环境变量才会生效）
docker-compose -f docker-compose.prod.yml up -d --force-recreate

# 3. 验证配置
docker exec shortlink-openresty-prod env | grep <KEY_NAME>
```

### 更新 Lua 代码
```bash
# 1. 修改 Lua 文件
nano lua/xxx.lua

# 2. 重启容器（Lua 代码会自动加载）
docker-compose -f docker-compose.prod.yml restart openresty

# 3. 查看日志确认
docker logs --tail 20 shortlink-openresty-prod
```

### 更新 Nginx 配置
```bash
# 1. 修改配置文件
nano conf/nginx.conf

# 2. 测试配置
docker exec shortlink-openresty-prod openresty -t

# 3. 重载配置
docker exec shortlink-openresty-prod openresty -s reload
```

## 📊 配置验证

### 验证 API Key
```bash
# 测试短链创建
curl -sk "https://short.yourdomain.com/api/v2/imagebed/create" \
  -X POST \
  -H "X-API-Key: <YOUR_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"image_path":"/uploads/test.jpg","service_type":"imagebed"}'

# 期望输出：{"success":true,"data":{...}}
```

### 验证 Redis 连接
```bash
# 从容器内测试
docker exec shortlink-openresty-prod redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD -n 1 ping

# 期望输出：PONG
```

### 验证 MySQL 连接
```bash
# 测试数据库连接
docker exec shortlink-mysql-prod mysql -u short_link -p<password> -e "SELECT 1;"

# 期望输出：1
```

### 验证服务健康
```bash
# 健康检查
curl https://short.yourdomain.com/health

# 期望输出：包含 status, uptime, redis_connected 等信息
```
