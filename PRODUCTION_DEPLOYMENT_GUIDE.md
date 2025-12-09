# 🚀 ShortImg-AI 生产环境部署指南

## 📋 目录

1. [系统架构](#系统架构)
2. [分开部署配置](#分开部署配置)
3. [API密钥配置](#api密钥配置)
4. [部署步骤](#部署步骤)
5. [网络配置](#网络配置)
6. [健康检查](#健康检查)
7. [故障排查](#故障排查)

---

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                        用户浏览器                             │
│                   https://yourdomain.com                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Nginx 反向代理                           │
│          (处理 SSL/TLS, 负载均衡, 缓存)                      │
└─────────────────────────────────────────────────────────────┘
         │                                        │
         │                                        │
         ▼                                        ▼
┌──────────────────────┐              ┌───────────────────────┐
│   图床后端服务        │              │   短链重定向服务        │
│   :8080              │◄────────────►│   :8081               │
│                      │   API调用     │                       │
│ ┌──────────────────┐ │              │ ┌───────────────────┐ │
│ │ Backend API      │ │              │ │ OpenResty         │ │
│ │ (Go/Gin)         │ │              │ │ (Lua)             │ │
│ └──────────────────┘ │              │ └───────────────────┘ │
│                      │              │                       │
│ ┌──────────────────┐ │              │ ┌───────────────────┐ │
│ │ MySQL (图床DB)   │ │              │ │ MySQL (短链DB)    │ │
│ │ :3306            │ │              │ │ :3307             │ │
│ └──────────────────┘ │              │ └───────────────────┘ │
│                      │              │                       │
│ ┌──────────────────┐ │              │ ┌───────────────────┐ │
│ │ Redis (缓存)     │ │              │ │ Redis (缓存)      │ │
│ │ :6379            │ │              │ │ :6380             │ │
│ └──────────────────┘ │              │ └───────────────────┘ │
└──────────────────────┘              └───────────────────────┘
```

---

## 🔧 分开部署配置

### 方案一: 同一服务器分开部署 (推荐)

#### 目录结构
```bash
/root/docker/shortimg-ai/
├── backend/                 # 图床后端
│   ├── docker-compose.prod.yml
│   ├── .env               # 从 .env.prod 复制并修改
│   ├── uploads/           # 上传文件
│   ├── logs/              # 日志
│   └── mysql/             # MySQL数据
│       └── data/
├── redirect-service/        # 短链服务
│   ├── docker-compose.prod.yml
│   ├── .env               # 从 .env.prod 复制并修改
│   ├── logs/              # 日志
│   ├── mysql/             # MySQL数据
│   │   └── data/
│   └── redis/             # Redis数据
```

#### 部署命令
```bash
# 1. 部署图床后端
cd /root/docker/shortimg-ai/backend
cp .env.prod .env
nano .env  # 修改配置
docker-compose -f docker-compose.prod.yml up -d

# 2. 部署短链服务
cd /root/docker/shortimg-ai/redirect-service
cp .env.prod .env
nano .env  # 修改配置
docker-compose -f docker-compose.prod.yml up -d
```

### 方案二: 不同服务器部署

#### 服务器A: 图床后端 (192.168.1.10)
```bash
# backend/.env
SHORT_LINK_BASE_URL=http://192.168.1.20:8081  # 短链服务器IP
SHORT_LINK_API_KEY=your_shared_api_key_here
```

#### 服务器B: 短链服务 (192.168.1.20)
```bash
# redirect-service/.env
DASHBOARD_API_KEY=your_shared_api_key_here    # 与backend一致
REDIRECT_PORT=8081
```

---

## 🔑 API密钥配置 (非常重要!)

### 密钥一致性要求

**关键点**: 以下两个配置必须完全一致:

1. **图床后端** (`backend/.env`):
   ```bash
   SHORT_LINK_API_KEY=abc123def456xyz789...
   ```

2. **短链服务** (`redirect-service/.env`):
   ```bash
   DASHBOARD_API_KEY=abc123def456xyz789...
   ```

### 生成强密钥

```bash
# 生成32字节(64字符)的密钥
openssl rand -hex 32

# 示例输出:
# e5f8a7b3c2d1e9f4a6b8c3d7e2f1a9b4c5d6e8f3a7b2c9d4e6f1a8b3c5d7e9f2

# 使用此密钥同时配置两个服务
```

### 配置示例

#### backend/.env
```bash
# 短链服务配置
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://192.168.9.5:8081
SHORT_LINK_PUBLIC_URL=https://s.yourdomain.com
SHORT_LINK_API_KEY=e5f8a7b3c2d1e9f4a6b8c3d7e2f1a9b4c5d6e8f3a7b2c9d4e6f1a8b3c5d7e9f2
SHORT_LINK_EXPIRE=0
```

#### redirect-service/.env
```bash
# API密钥配置
DASHBOARD_API_KEY=e5f8a7b3c2d1e9f4a6b8c3d7e2f1a9b4c5d6e8f3a7b2c9d4e6f1a8b3c5d7e9f2
```

---

## 📦 部署步骤

### Step 1: 准备环境

```bash
# 创建目录结构
mkdir -p /root/docker/shortimg-ai/backend/{uploads,logs,mysql/data,mysql/conf,mysql/logs}
mkdir -p /root/docker/shortimg-ai/redirect-service/{logs,mysql/data,mysql/conf,mysql/logs,redis,geoip,ssl}

# 设置权限
chmod -R 755 /root/docker/shortimg-ai/
```

### Step 2: 配置图床后端

```bash
cd /root/docker/shortimg-ai/backend

# 1. 复制配置文件
cp .env.prod .env

# 2. 生成密钥
API_KEY=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)
MYSQL_PASSWORD=$(openssl rand -base64 24)

echo "生成的密钥:"
echo "API_KEY: $API_KEY"
echo "JWT_SECRET: $JWT_SECRET"
echo "MYSQL_PASSWORD: $MYSQL_PASSWORD"

# 3. 修改 .env 文件
nano .env

# 修改以下配置:
# MYSQL_PASSWORD=<上面生成的密码>
# JWT_SECRET=<上面生成的密钥>
# SHORT_LINK_BASE_URL=http://192.168.9.5:8081  # 改为实际IP
# SHORT_LINK_PUBLIC_URL=https://s.yourdomain.com
# SHORT_LINK_API_KEY=<上面生成的API_KEY>
# CORS_ALLOW_ORIGINS=https://yourdomain.com

# 4. 启动服务
docker-compose -f docker-compose.prod.yml up -d

# 5. 查看日志
docker-compose -f docker-compose.prod.yml logs -f
```

### Step 3: 配置短链服务

```bash
cd /root/docker/shortimg-ai/redirect-service

# 1. 复制配置文件
cp .env.prod .env

# 2. 修改 .env 文件
nano .env

# 修改以下配置（使用Step 2中生成的API_KEY）:
# DASHBOARD_API_KEY=<与backend的SHORT_LINK_API_KEY一致>
# MYSQL_PASSWORD=<自定义强密码>
# REDIRECT_DOMAIN=s.yourdomain.com
# TC_GO_PRIMARY_DOMAIN=img.yourdomain.com

# 3. 创建API Key在Redis中
# (服务启动后自动执行，也可手动创建)

# 4. 启动服务
docker-compose -f docker-compose.prod.yml up -d

# 5. 查看日志
docker-compose -f docker-compose.prod.yml logs -f
```

### Step 4: 初始化API密钥到Redis

```bash
# 进入短链服务的Redis容器
docker exec -it shortlink-redis-prod redis-cli

# 设置API Key (使用你在.env中配置的DASHBOARD_API_KEY)
SET api_key:your_api_key_here '{"name":"backend","status":"active","created_at":"2025-12-09","permissions":["read","write"]}'

# 验证
GET api_key:your_api_key_here

# 退出
exit
```

### Step 5: 配置Nginx反向代理 (可选)

```nginx
# /etc/nginx/sites-available/shortimg

# 图床后端
server {
    listen 443 ssl http2;
    server_name img.yourdomain.com;

    ssl_certificate /etc/nginx/ssl/yourdomain.com.crt;
    ssl_certificate_key /etc/nginx/ssl/yourdomain.com.key;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 大文件上传
        client_max_body_size 100M;
    }
}

# 短链服务
server {
    listen 443 ssl http2;
    server_name s.yourdomain.com;

    ssl_certificate /etc/nginx/ssl/yourdomain.com.crt;
    ssl_certificate_key /etc/nginx/ssl/yourdomain.com.key;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 🌐 网络配置

### 同一服务器部署

#### 选项1: 使用宿主机IP (推荐)
```bash
# backend/.env
SHORT_LINK_BASE_URL=http://127.0.0.1:8081
# 或使用内网IP
SHORT_LINK_BASE_URL=http://192.168.9.5:8081
```

#### 选项2: 创建共享Docker网络
```bash
# 创建共享网络
docker network create shortimg-shared-network

# 修改两个docker-compose.prod.yml,添加外部网络:
# networks:
#   shortimg-shared-network:
#     external: true

# backend/.env
SHORT_LINK_BASE_URL=http://shortlink-openresty-prod
```

### 不同服务器部署

```bash
# 确保两台服务器网络互通
ping 192.168.1.20

# 配置防火墙允许8081端口
firewall-cmd --permanent --add-port=8081/tcp
firewall-cmd --reload

# backend/.env (服务器A)
SHORT_LINK_BASE_URL=http://192.168.1.20:8081
```

---

## 🏥 健康检查

### 图床后端健康检查

```bash
# 检查服务状态
docker ps | grep shortimg-backend-prod

# 检查健康状态
docker inspect shortimg-backend-prod | grep -A 10 Health

# 测试API
curl http://localhost:8080/health

# 预期响应: {"status":"ok"}
```

### 短链服务健康检查

```bash
# 检查服务状态
docker ps | grep shortlink-openresty-prod

# 测试API
curl http://localhost:8081/health

# 测试短链API (需要API Key)
curl -H "X-API-Key: your_api_key_here" http://localhost:8081/api/v2/imagebed
```

### 数据库健康检查

```bash
# MySQL (图床)
docker exec shortimg-mysql-prod mysqladmin ping -uroot -p

# MySQL (短链)
docker exec shortlink-mysql-prod mysqladmin ping -uroot -p

# Redis (图床)
docker exec shortimg-redis-prod redis-cli ping

# Redis (短链)
docker exec shortlink-redis-prod redis-cli ping
```

---

## 🔍 故障排查

### 问题1: 图片上传后没有生成短链

**原因**: API密钥不匹配或网络不通

**检查步骤**:
```bash
# 1. 检查API密钥是否一致
cd /root/docker/shortimg-ai/backend
grep SHORT_LINK_API_KEY .env

cd /root/docker/shortimg-ai/redirect-service
grep DASHBOARD_API_KEY .env

# 2. 检查网络连接
docker exec shortimg-backend-prod curl -v http://192.168.9.5:8081/health

# 3. 查看后端日志
docker logs shortimg-backend-prod | grep "短链"

# 4. 查看短链服务日志
docker logs shortlink-openresty-prod | tail -50
```

**解决方法**:
```bash
# 确保两个API Key完全一致
# 更新Redis中的API Key
docker exec -it shortlink-redis-prod redis-cli
SET api_key:your_api_key_here '{"name":"backend","status":"active","created_at":"2025-12-09","permissions":["read","write"]}'
exit

# 重启服务
docker-compose -f docker-compose.prod.yml restart backend
```

### 问题2: 短链服务返回401错误

**原因**: Redis中没有API密钥或密钥格式错误

**解决方法**:
```bash
# 1. 检查Redis
docker exec -it shortlink-redis-prod redis-cli
GET api_key:your_api_key_here

# 2. 如果为空,创建密钥
SET api_key:your_api_key_here '{"name":"backend","status":"active","created_at":"2025-12-09","permissions":["read","write"]}'

# 3. 验证
GET api_key:your_api_key_here

# 4. 退出并重启
exit
docker-compose -f docker-compose.prod.yml restart openresty
```

### 问题3: 数据库连接失败

**检查步骤**:
```bash
# 查看容器状态
docker ps -a | grep mysql

# 查看数据库日志
docker logs shortimg-mysql-prod
docker logs shortlink-mysql-prod

# 测试连接
docker exec -it shortimg-mysql-prod mysql -uroot -p
```

**常见原因**:
- 密码不正确
- 数据库未就绪 (等待健康检查)
- 端口冲突
- 磁盘空间不足

### 问题4: 查看实时日志

```bash
# 图床后端
docker-compose -f docker-compose.prod.yml logs -f backend

# 短链服务
docker-compose -f docker-compose.prod.yml logs -f openresty

# 特定时间段的日志
docker logs --since 30m shortimg-backend-prod
docker logs --tail 100 shortlink-openresty-prod
```

---

## 📊 监控和维护

### 日志管理

```bash
# 日志轮转配置 (logrotate)
cat > /etc/logrotate.d/shortimg <<EOF
/root/docker/shortimg-ai/*/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF
```

### 备份脚本

```bash
#!/bin/bash
# /root/scripts/backup-shortimg.sh

BACKUP_DIR="/root/backups/shortimg"
DATE=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份MySQL数据库
docker exec shortimg-mysql-prod mysqldump -uroot -p$MYSQL_ROOT_PASSWORD imagebed > $BACKUP_DIR/imagebed_$DATE.sql
docker exec shortlink-mysql-prod mysqldump -uroot -p$MYSQL_ROOT_PASSWORD short_links > $BACKUP_DIR/shortlinks_$DATE.sql

# 备份Redis
docker exec shortimg-redis-prod redis-cli SAVE
docker exec shortlink-redis-prod redis-cli SAVE

# 备份上传文件
tar -czf $BACKUP_DIR/uploads_$DATE.tar.gz /root/docker/shortimg-ai/backend/uploads/

# 删除30天前的备份
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "备份完成: $DATE"
```

### 定时任务

```bash
# 添加到crontab
crontab -e

# 每天凌晨2点备份
0 2 * * * /root/scripts/backup-shortimg.sh >> /var/log/shortimg-backup.log 2>&1
```

---

## 🔒 安全建议

1. **修改所有默认密码**
   - MySQL root密码
   - 管理员密码
   - API密钥

2. **使用强密钥**
   ```bash
   openssl rand -hex 32  # API密钥
   openssl rand -base64 24  # 数据库密码
   ```

3. **限制端口访问**
   ```bash
   # 只允许本地访问数据库端口
   firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="127.0.0.1" port port="3306" protocol="tcp" accept'
   ```

4. **启用HTTPS**
   - 使用Let's Encrypt免费证书
   - 配置SSL/TLS强加密

5. **定期更新**
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

---

## 📞 技术支持

如有问题,请查看:
- [GitHub Issues](https://github.com/yourusername/shortimg-ai/issues)
- [文档](./README.md)
- [FAQ](./FAQ.md)
