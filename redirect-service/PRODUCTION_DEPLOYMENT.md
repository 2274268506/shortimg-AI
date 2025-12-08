# 🔗 短链服务生产环境部署指南

## 📋 前提条件

- ✅ 已安装 Docker 和 Docker Compose
- ✅ 已安装 Nginx
- ✅ 域名 DNS 已正确解析（例如: s.img.oxvxo.link）
- ✅ 后端图床服务已部署运行
- ✅ SSL 证书已准备（或使用 Let's Encrypt）

## 🚀 快速部署

### 1️⃣ 准备部署文件

```bash
# 上传文件到服务器
cd /root/docker/shortimg-ai
mkdir -p redirect-service
cd redirect-service

# 上传以下文件：
# - docker-compose.prod.yml
# - .env.prod
# - deploy-prod.sh
# - conf/ 目录
# - lua/ 目录
# - html/ 目录
# - sql/ 目录
# - lib/ 目录
```

### 2️⃣ 修改配置文件

```bash
# 复制环境变量模板
cp .env.prod .env

# 编辑配置
nano .env
```

**必须修改的配置：**

```bash
# MySQL 密码
MYSQL_ROOT_PASSWORD=your_secure_mysql_root_password_123
MYSQL_PASSWORD=your_secure_mysql_password_123

# Redis 密码
REDIS_PASSWORD=your_secure_redis_password_123

# 短链域名
REDIRECT_DOMAIN=short.oxvxo.link
REDIRECT_PROTOCOL=https

# 后端图床地址
TC_GO_PRIMARY_DOMAIN=img.oxvxo.link
TC_GO_PRIMARY_PROTOCOL=https

# API 密钥（需要与后端图床一致）
API_KEY=your_api_key_minimum_32_characters_long
```

### 3️⃣ 运行部署脚本

```bash
# 添加执行权限
chmod +x deploy-prod.sh

# 运行部署
./deploy-prod.sh
```

或手动部署：

```bash
# 创建必要目录
mkdir -p /root/docker/shortimg-ai/redirect-service/{mysql/{data,conf,logs},redis,logs,ssl,geoip}

# 启动服务
docker-compose -f docker-compose.prod.yml up -d

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f
```

### 4️⃣ 配置 Nginx 反向代理

```bash
# 复制 Nginx 配置
sudo cp s.img.oxvxo.link.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/s.img.oxvxo.link.conf /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重新加载 Nginx
sudo nginx -s reload
```

### 5️⃣ 申请 SSL 证书

```bash
# 使用 Certbot
sudo certbot certonly --webroot -w /var/www/certbot \
  -d s.img.oxvxo.link \
  --email your-email@example.com \
  --agree-tos

# 证书路径：
# /etc/letsencrypt/live/s.img.oxvxo.link/fullchain.pem
# /etc/letsencrypt/live/s.img.oxvxo.link/privkey.pem
```

## 🔧 配置详解

### 环境变量说明

| 变量名 | 说明 | 示例值 | 必填 |
|--------|------|--------|------|
| `MYSQL_ROOT_PASSWORD` | MySQL root 密码 | `SecurePass123!` | ✅ |
| `MYSQL_PASSWORD` | MySQL 用户密码 | `UserPass123!` | ✅ |
| `REDIS_PASSWORD` | Redis 密码 | `RedisPass123!` | ✅ |
| `REDIRECT_DOMAIN` | 短链域名 | `s.img.oxvxo.link` | ✅ |
| `REDIRECT_PROTOCOL` | 协议 | `https` | ✅ |
| `TC_GO_PRIMARY_DOMAIN` | 图床域名 | `img.oxvxo.link` | ✅ |
| `API_KEY` | API 密钥 | `your_key_32chars` | ✅ |
| `CDN_ROUTING_MODE` | CDN 模式 | `direct` | ⭕ |
| `CACHE_TTL` | 缓存时间(秒) | `3600` | ⭕ |
| `RATE_LIMIT` | 限流(req/s) | `100` | ⭕ |

### 端口映射

| 服务 | 内部端口 | 外部端口 | 说明 |
|------|---------|---------|------|
| OpenResty | 80 | 8081 | HTTP（Nginx 代理） |
| OpenResty | 443 | 8444 | HTTPS（可选） |
| Redis | 6379 | 6380 | Redis 数据库 |
| MySQL | 3306 | 3307 | MySQL 数据库 |

### 数据持久化目录

```
/root/docker/shortimg-ai/redirect-service/
├── mysql/
│   ├── data/          # MySQL 数据文件
│   ├── conf/          # MySQL 配置
│   └── logs/          # MySQL 日志
├── redis/             # Redis 数据文件
├── logs/              # OpenResty 日志
├── ssl/               # SSL 证书
├── geoip/             # GeoIP 数据库
├── conf/              # 配置文件
├── lua/               # Lua 脚本
└── html/              # 静态文件
```

## 🔗 后端集成

### 1️⃣ 配置后端 API 密钥

在后端图床的 `.env` 文件中添加：

```bash
# 短链服务配置
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=https://s.img.oxvxo.link
SHORT_LINK_API_KEY=your_api_key_minimum_32_characters_long
```

### 2️⃣ 重启后端服务

```bash
cd /root/docker/shortimg-ai/backend
docker-compose -f docker-compose.prod.yml restart backend
```

### 3️⃣ 测试集成

在后端服务中创建短链接：

```bash
# 测试创建短链接
curl -X POST https://img.oxvxo.link/api/images/123/short-link \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"

# 响应示例
{
  "short_url": "https://s.img.oxvxo.link/abc123",
  "original_url": "https://img.oxvxo.link/i/uuid-123",
  "expires_at": "2025-12-31T23:59:59Z"
}
```

## ✅ 验证部署

### 1️⃣ 检查服务状态

```bash
# 查看容器状态
docker-compose -f docker-compose.prod.yml ps

# 应该显示 3 个服务都是 Up (healthy)
```

### 2️⃣ 测试健康检查

```bash
# 测试内部健康检查
curl http://localhost:8081/health

# 测试外部访问
curl https://s.img.oxvxo.link/health

# 预期响应
{"status":"ok","timestamp":"2025-12-07T12:00:00Z"}
```

### 3️⃣ 测试短链接重定向

```bash
# 假设已创建短链接 abc123
curl -I https://s.img.oxvxo.link/abc123

# 应该返回 302 重定向
HTTP/2 302
location: https://img.oxvxo.link/i/uuid-123
```

### 4️⃣ 检查日志

```bash
# 查看 OpenResty 日志
docker logs shortlink-openresty-prod

# 查看 Nginx 日志
tail -f /var/log/nginx/shortlink.access.log
tail -f /var/log/nginx/shortlink.error.log
```

## 🔒 安全配置

### 1️⃣ 防火墙配置

```bash
# 仅开放必要端口
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable

# 内部服务端口不对外开放
# 8081, 8444, 6380, 3307 仅允许本地访问
```

### 2️⃣ 限流配置

在 Nginx 配置中已启用限流：

```nginx
# 在 nginx.conf 的 http 块中添加
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=redirect_limit:10m rate=100r/s;
```

### 3️⃣ API 密钥管理

```bash
# 生成强 API 密钥
openssl rand -base64 32

# 定期轮换密钥（建议每 90 天）
```

### 4️⃣ 数据库安全

- ✅ 使用强密码
- ✅ 禁用远程 root 登录
- ✅ 定期备份数据库
- ✅ 限制连接来源

## 📊 监控和维护

### Prometheus 监控

访问监控指标：

```bash
# 仅本地访问
curl http://localhost:8081/metrics
```

指标包括：
- 请求总数
- 重定向成功/失败率
- 响应时间
- 缓存命中率
- Redis/MySQL 连接状态

### 日志轮转

配置日志轮转：

```bash
sudo nano /etc/logrotate.d/shortlink
```

内容：

```
/var/log/nginx/shortlink*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        nginx -s reload
    endscript
}

/root/docker/shortimg-ai/redirect-service/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
}
```

### 数据备份

```bash
# 创建备份脚本
nano /root/scripts/backup-shortlink.sh
```

内容：

```bash
#!/bin/bash
BACKUP_DIR="/root/backups/shortlink"
DATE=$(date +%Y%m%d_%H%M%S)

# 备份 MySQL
docker exec shortlink-mysql-prod mysqldump -u root -p$MYSQL_ROOT_PASSWORD short_links \
  > $BACKUP_DIR/mysql_$DATE.sql

# 备份 Redis
docker exec shortlink-redis-prod redis-cli --rdb /data/dump.rdb
cp /root/docker/shortimg-ai/redirect-service/redis/dump.rdb $BACKUP_DIR/redis_$DATE.rdb

# 保留最近 30 天的备份
find $BACKUP_DIR -type f -mtime +30 -delete
```

添加到 crontab：

```bash
# 每天凌晨 3 点备份
0 3 * * * /root/scripts/backup-shortlink.sh
```

## 🐛 故障排查

### 问题 1: 服务无法启动

**检查：**

```bash
# 查看容器日志
docker-compose -f docker-compose.prod.yml logs

# 检查端口占用
netstat -tlnp | grep -E '8081|6380|3307'
```

**解决：**

```bash
# 修改 .env 中的端口
REDIRECT_PORT=8082
REDIS_EXTERNAL_PORT=6381
MYSQL_EXTERNAL_PORT=3308
```

### 问题 2: 短链接 404

**原因：** 短链接不存在或已过期

**检查：**

```bash
# 连接 MySQL 检查
docker exec -it shortlink-mysql-prod mysql -u root -p

USE short_links;
SELECT * FROM links WHERE short_code='abc123';
```

### 问题 3: 重定向失败

**检查：**

```bash
# 查看 OpenResty 错误日志
docker logs shortlink-openresty-prod

# 检查 Redis 连接
docker exec -it shortlink-redis-prod redis-cli
> AUTH your_redis_password
> PING
```

### 问题 4: 性能问题

**优化：**

1. **增加 Redis 内存：**
   ```bash
   # 修改 docker-compose.prod.yml
   command: >
     redis-server
     --maxmemory 4gb  # 增加到 4GB
   ```

2. **增加 MySQL 缓冲池：**
   ```bash
   # 修改 my.cnf
   innodb_buffer_pool_size=2G
   ```

3. **启用 Nginx 缓存：**
   ```nginx
   proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=shortlink_cache:10m max_size=1g;
   
   location / {
       proxy_cache shortlink_cache;
       proxy_cache_valid 200 1h;
       proxy_cache_key "$scheme$host$uri";
   }
   ```

## 📞 获取帮助

如有问题，请：

1. 查看日志: `docker-compose logs -f`
2. 检查配置: `docker exec shortlink-openresty-prod cat /etc/nginx/conf/config.lua`
3. 查看文档: 本项目的各个 `*.md` 文件
4. 提交 Issue: GitHub Issues

## 🎉 完成！

现在你的短链服务应该已经成功部署并运行了！

**快速测试：**

```bash
# 1. 创建一个短链接（通过后端 API）
# 2. 访问短链接
curl -I https://s.img.oxvxo.link/YOUR_SHORT_CODE

# 3. 应该看到 302 重定向到原始图片地址
```

🚀 **享受你的短链服务吧！**
