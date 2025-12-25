# 生产环境配置快速参考

## 📋 配置文件清单

### 图床服务 (img.oxvxo.link - 82.39.86.22)

#### backend/.env
```bash
SHORT_LINK_API_KEY=twmxRnag7fBd6YuEi1KWNJFjTV9OUvqCo2zpXbrLG05HMk83c4hPQelDIyAsSZ
SHORT_LINK_BASE_URL=https://short.oxvxo.link
SHORT_LINK_PUBLIC_URL=https://short.oxvxo.link
BACKEND_PUBLIC_URL=https://img.oxvxo.link
CORS_ALLOW_ORIGINS=https://img.oxvxo.link,https://short.oxvxo.link
```

#### backend/docker-compose.prod.yml
```yaml
volumes:
  - /data/shortimg-ai/uploads:/app/uploads
  - /data/shortimg-ai/logs:/app/logs
  - /data/shortimg-ai/data:/app/data
```

#### Nginx 配置 (/root/docker/nginx/config/conf.d/img.oxvxo.link.conf)
```nginx
# 图片访问路径（代理到后端）
location /i/ {
    proxy_pass http://127.0.0.1:8080;
    expires 30d;
}

# API 请求代理
location /api/ {
    proxy_pass http://127.0.0.1:8080/api/;
}
```

---

### 短链服务 (short.oxvxo.link - 69.166.235.175)

#### redirect-service/.env
```bash
# Redis 配置
REDIS_HOST=shortlink-redis-prod
REDIS_PORT=6379
REDIS_PASSWORD=lrF8De47PIscgY0CjXq9ibRafwNWZ2Hp
REDIS_DB=1  # 重要：必须是数据库1

# API 密钥（必须与图床服务一致）
DASHBOARD_API_KEY=twmxRnag7fBd6YuEi1KWNJFjTV9OUvqCo2zpXbrLG05HMk83c4hPQelDIyAsSZ
API_KEY=twmxRnag7fBd6YuEi1KWNJFjTV9OUvqCo2zpXbrLG05HMk83c4hPQelDIyAsSZ

# 域名配置
REDIRECT_DOMAIN=short.oxvxo.link
TC_GO_PRIMARY_DOMAIN=img.oxvxo.link
```

#### docker-entrypoint.sh (关键修复)
```bash
# Redis CLI 配置 - 包含数据库选择
REDIS_CLI="redis-cli -h $REDIS_HOST -p $REDIS_PORT"
if [ -n "$REDIS_PASSWORD" ]; then
    REDIS_CLI="$REDIS_CLI -a $REDIS_PASSWORD"
fi
if [ -n "$REDIS_DATABASE" ]; then
    REDIS_CLI="$REDIS_CLI -n $REDIS_DATABASE"  # 关键：添加数据库选择
fi
```

#### lua/storage/redis_client.lua (关键修复)
```lua
-- 从配置文件读取 Redis 配置，而不是硬编码
local app_config = require "conf.config"
local config = app_config.redis or {
    host = "127.0.0.1",
    port = 6379,
    password = nil,
    database = 0,
}
```

---

## 🔑 关键配置说明

### 1. API Key 配置
**重要：** 图床服务和短链服务的 API Key 必须完全一致！

- 图床服务: `backend/.env` → `SHORT_LINK_API_KEY`
- 短链服务: `redirect-service/.env` → `DASHBOARD_API_KEY` 和 `API_KEY`

### 2. Redis 数据库选择
**重要：** 短链服务必须使用 Redis 数据库 1（不是默认的 0）

- 环境变量: `REDIS_DB=1`
- docker-entrypoint.sh: 包含 `-n $REDIS_DATABASE`
- API Key 存储在: `redis db 1`

### 3. 数据持久化路径
图床服务数据统一存储在 `/data/shortimg-ai/`：

```bash
/data/shortimg-ai/
├── uploads/     # 图片文件
├── logs/        # 应用日志
└── data/        # 数据库文件（如果使用SQLite）
```

### 4. Nginx 反向代理
图床服务需要 Nginx 配置 `/i/` 路径代理：

```nginx
location /i/ {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
}
```

---

## 🔧 常用命令

### 图床服务 (82.39.86.22)

```bash
# 进入项目目录
cd /root/docker/shortimg-ai/backend

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f backend

# 重启服务
docker-compose -f docker-compose.prod.yml restart backend

# 查看环境变量
docker exec shortimg-backend-prod env | grep SHORT_LINK

# 检查数据目录
ls -lh /data/shortimg-ai/uploads/

# 修复权限
chown -R 1000:1000 /data/shortimg-ai/
```

### 短链服务 (69.166.235.175)

```bash
# 进入项目目录
cd /root/docker/shortimg-ai/redirect-service

# 查看日志
docker logs --tail 50 shortlink-openresty-prod

# 重启服务
docker-compose -f docker-compose.prod.yml restart openresty

# 检查 Redis 中的 API Key
docker exec shortlink-redis-prod redis-cli -a lrF8De47PIscgY0CjXq9ibRafwNWZ2Hp -n 1 KEYS 'api_key:*'

# 查看 API Key 详情
docker exec shortlink-redis-prod redis-cli -a lrF8De47PIscgY0CjXq9ibRafwNWZ2Hp -n 1 GET 'api_key:twmxRnag...'

# 测试 API 认证
curl -sk "https://short.oxvxo.link/api/v2/imagebed/create" \
  -X POST \
  -H "X-API-Key: twmxRnag7fBd6YuEi1KWNJFjTV9OUvqCo2zpXbrLG05HMk83c4hPQelDIyAsSZ" \
  -H "Content-Type: application/json" \
  -d '{"image_path":"/uploads/test.jpg","service_type":"imagebed"}'
```

---

## 🐛 故障排查

### 问题1: 短链认证失败
**症状:** 返回 "Authentication failed"

**检查步骤:**
```bash
# 1. 检查 API Key 是否一致
docker exec shortimg-backend-prod env | grep SHORT_LINK_API_KEY
docker exec shortlink-openresty-prod env | grep API_KEY

# 2. 检查 Redis 数据库
docker exec shortlink-redis-prod redis-cli -a <password> -n 1 KEYS 'api_key:*'

# 3. 检查 Redis 配置
docker exec shortlink-openresty-prod env | grep REDIS
```

### 问题2: 图片访问404
**症状:** 图片URL返回404

**检查步骤:**
```bash
# 1. 检查文件是否存在
ls -lh /data/shortimg-ai/uploads/album_*/

# 2. 检查权限
ls -la /data/shortimg-ai/uploads/

# 3. 测试后端直接访问
docker exec shortimg-backend-prod wget -O - http://localhost:8080/i/xxx

# 4. 检查 Nginx 配置
cat /root/docker/nginx/config/conf.d/img.oxvxo.link.conf | grep '/i/'
```

### 问题3: 容器启动失败
```bash
# 查看详细日志
docker-compose -f docker-compose.prod.yml logs <service_name>

# 检查端口占用
netstat -tulpn | grep <PORT>

# 强制重建
docker-compose -f docker-compose.prod.yml up -d --force-recreate
```

---

## 📊 监控命令

```bash
# 查看容器状态
docker-compose -f docker-compose.prod.yml ps

# 查看资源使用
docker stats

# 查看磁盘使用
df -h /data/shortimg-ai/

# 查看 MySQL 连接数
docker exec shortimg-mysql-prod mysqladmin -u root -p<password> status

# 查看 Redis 信息
docker exec shortlink-redis-prod redis-cli -a <password> info
```

---

## 🔄 更新流程

### 更新图床服务
```bash
cd /root/docker/shortimg-ai/backend
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

### 更新短链服务
```bash
cd /root/docker/shortimg-ai/redirect-service
docker-compose -f docker-compose.prod.yml build --no-cache openresty
docker-compose -f docker-compose.prod.yml up -d
```
