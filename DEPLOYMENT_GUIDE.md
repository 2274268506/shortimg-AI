# ShortImg-AI 生产环境部署指南

## 🎯 部署架构

本系统采用前后端分离架构，分为两个服务：

1. **图床服务** (img.oxvxo.link)
   - 前端：Vue.js + Vite
   - 后端：Go + Gin + MySQL + Redis
   - 功能：图片上传、管理、展示

2. **短链服务** (short.oxvxo.link)
   - 前端：OpenResty + Lua
   - 后端：OpenResty + MySQL + Redis
   - 功能：短链生成、跳转、CDN路由

## 📋 前置准备

### 服务器要求

- **操作系统**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- **CPU**: 2核及以上
- **内存**: 4GB及以上
- **磁盘**: 50GB及以上（建议独立数据盘）
- **网络**: 公网IP + 域名

### 软件依赖

```bash
# 安装 Docker
curl -fsSL https://get.docker.com | bash

# 安装 Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 验证安装
docker --version
docker-compose --version
```

### 域名配置

```bash
# A 记录配置
img.yourdomain.com  -> 图床服务器IP
short.yourdomain.com -> 短链服务器IP
```

## 🚀 图床服务部署

### 1. 创建数据目录

```bash
# 创建数据持久化目录
mkdir -p /data/shortimg-ai/{uploads,logs,data}
mkdir -p /root/docker/shortimg-ai/{mysql,redis,backend}

# 设置权限
chown -R 1000:1000 /data/shortimg-ai
```

### 2. 配置环境变量

```bash
cd /root/docker/shortimg-ai/backend

# 复制配置模板
cp .env.production .env

# 编辑配置文件
nano .env
```

**必须修改的配置项：**
- `MYSQL_ROOT_PASSWORD`: MySQL root密码
- `MYSQL_PASSWORD`: 数据库用户密码
- `JWT_SECRET`: JWT密钥（至少32字符）
- `DEFAULT_ADMIN_PASSWORD`: 管理员初始密码
- `SHORT_LINK_API_KEY`: 短链API密钥（与短链服务一致）
- `SHORT_LINK_BASE_URL`: https://short.yourdomain.com
- `SHORT_LINK_PUBLIC_URL`: https://short.yourdomain.com
- `BACKEND_PUBLIC_URL`: https://img.yourdomain.com
- `CORS_ALLOW_ORIGINS`: https://img.yourdomain.com,https://short.yourdomain.com

### 3. 启动服务

```bash
# 启动所有服务
docker-compose -f docker-compose.prod.yml up -d

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f backend

# 等待服务启动完成（约1分钟）
docker-compose -f docker-compose.prod.yml ps
```

### 4. 配置 Nginx 反向代理

```bash
# 前端静态文件目录
mkdir -p /root/docker/nginx/html
# 上传前端 dist/ 文件到此目录

# Nginx 配置文件
nano /root/docker/nginx/config/conf.d/img.yourdomain.com.conf
```

**Nginx 配置示例：**

```nginx
server {
    listen 443 ssl http2;
    server_name img.yourdomain.com;

    # SSL 证书
    ssl_certificate     /etc/nginx/ssl/fullchain.cer;
    ssl_certificate_key /etc/nginx/ssl/yourdomain.com.key;

    # 前端静态文件
    root /usr/share/nginx/html;
    index index.html;

    # 图片访问路径（代理到后端）
    location /i/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # API 请求代理
    location /api/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # SPA 路由支持
    location / {
        try_files $uri $uri/ /index.html =404;
    }
}
```

### 5. 验证部署

```bash
# 健康检查
curl https://img.yourdomain.com/api/health

# 测试上传（需登录获取token）
# 访问 https://img.yourdomain.com 使用管理员账号登录
```

## 🔗 短链服务部署

### 1. 创建数据目录

```bash
mkdir -p /data/shortlink/{mysql,redis}
mkdir -p /root/docker/shortimg-ai/redirect-service
```

### 2. 配置环境变量

```bash
cd /root/docker/shortimg-ai/redirect-service

# 创建 .env 文件
nano .env
```

**关键配置：**

```bash
# MySQL 配置
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_DATABASE=short_links
MYSQL_USER=short_link
MYSQL_PASSWORD=your_secure_password

# Redis 配置
REDIS_HOST=shortlink-redis-prod
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password
REDIS_DB=1

# 短链服务域名
REDIRECT_DOMAIN=short.yourdomain.com
REDIRECT_PROTOCOL=https

# 图床服务地址
TC_GO_PRIMARY_DOMAIN=img.yourdomain.com
TC_GO_PRIMARY_PROTOCOL=https

# API密钥（必须与图床服务的 SHORT_LINK_API_KEY 一致）
DASHBOARD_API_KEY=your_api_key_here_minimum_60_characters
API_KEY=your_api_key_here_minimum_60_characters
```

### 3. 启动服务

```bash
docker-compose -f docker-compose.prod.yml up -d

# 查看日志
docker logs --tail 50 shortlink-openresty-prod

# 验证 API Key 注册
docker exec shortlink-redis-prod redis-cli -a <REDIS_PASSWORD> -n 1 GET 'api_key:<YOUR_API_KEY>'
```

### 4. 验证部署

```bash
# 健康检查
curl https://short.yourdomain.com/health

# 测试短链创建
curl -sk "https://short.yourdomain.com/api/v2/imagebed/create" \
  -X POST \
  -H "X-API-Key: <YOUR_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"image_path":"/uploads/test.jpg","service_type":"imagebed"}'
```

## 🔧 常见问题

### 1. 图片上传后无法访问

**原因：** 文件权限问题或路径配置错误

**解决：**
```bash
# 检查权限
ls -la /data/shortimg-ai/uploads/

# 修复权限
chown -R 1000:1000 /data/shortimg-ai/uploads/
```

### 2. 短链认证失败

**原因：** API Key 配置不一致或未注册到正确的 Redis 数据库

**解决：**
```bash
# 检查图床服务的 API Key
docker exec shortimg-backend-prod env | grep SHORT_LINK_API_KEY

# 检查短链服务的 API Key
docker exec shortlink-openresty-prod env | grep API_KEY

# 检查 Redis 中的 API Key
docker exec shortlink-redis-prod redis-cli -a <REDIS_PASSWORD> -n 1 KEYS 'api_key:*'
```

### 3. 容器启动失败

**解决：**
```bash
# 查看详细日志
docker-compose -f docker-compose.prod.yml logs <service_name>

# 检查端口占用
netstat -tulpn | grep <PORT>

# 重新创建容器
docker-compose -f docker-compose.prod.yml up -d --force-recreate
```

## 📊 数据备份

### MySQL 备份

```bash
# 图床数据库
docker exec shortimg-mysql-prod mysqldump -u root -p<ROOT_PASSWORD> imagebed > imagebed_backup_$(date +%Y%m%d).sql

# 短链数据库
docker exec shortlink-mysql-prod mysqldump -u root -p<ROOT_PASSWORD> short_links > shortlink_backup_$(date +%Y%m%d).sql
```

### Redis 备份

```bash
# 触发 RDB 持久化
docker exec shortlink-redis-prod redis-cli -a <REDIS_PASSWORD> BGSAVE

# 复制 RDB 文件
docker cp shortlink-redis-prod:/data/dump.rdb ./redis_backup_$(date +%Y%m%d).rdb
```

### 文件备份

```bash
# 打包上传文件
tar -czf uploads_backup_$(date +%Y%m%d).tar.gz /data/shortimg-ai/uploads/

# 同步到远程服务器
rsync -avz /data/shortimg-ai/uploads/ user@backup-server:/backup/shortimg-ai/
```

## 🔐 安全建议

1. **使用强密码**: 所有密码至少16个字符，包含大小写字母、数字、特殊字符
2. **定期更新**: 定期更新 Docker 镜像和系统软件包
3. **限制访问**: 使用防火墙限制不必要的端口访问
4. **启用日志**: 保留详细日志用于审计和故障排查
5. **SSL证书**: 使用 Let's Encrypt 或其他CA颁发的证书
6. **备份策略**: 每日自动备份数据库和文件

## 📈 监控

```bash
# 查看容器状态
docker-compose -f docker-compose.prod.yml ps

# 查看资源使用
docker stats

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f --tail 100
```

## 🆘 技术支持

- 项目文档: `docs/`
- 问题反馈: GitHub Issues
- 生产配置示例: 已部署的服务器配置可作为参考
