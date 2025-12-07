# 🚀 ShortImg-AI Backend 生产环境部署指南

## 📋 目录

- [系统要求](#系统要求)
- [快速部署](#快速部署)
- [详细步骤](#详细步骤)
- [配置说明](#配置说明)
- [数据持久化](#数据持久化)
- [运维管理](#运维管理)
- [故障排查](#故障排查)

---

## 📦 系统要求

### 硬件要求
- **CPU**: 2核及以上
- **内存**: 4GB及以上（推荐8GB）
- **磁盘**: 20GB及以上（根据存储需求调整）

### 软件要求
- **操作系统**: Linux (Ubuntu 20.04+, CentOS 7+, Debian 10+)
- **Docker**: 20.10+
- **Docker Compose**: 1.29+

---

## ⚡ 快速部署

### 1. 创建数据目录

```bash
# 创建项目数据目录
sudo mkdir -p /root/docker/shortimg-ai/{mysql/{data,conf,logs},redis/{data},backend/{uploads,logs,data,config}}

# 设置目录权限
sudo chmod -R 755 /root/docker/shortimg-ai
```

### 2. 配置环境变量

```bash
cd /path/to/backend

# 复制环境变量模板
cp .env.prod .env

# 编辑环境变量（务必修改所有密码和密钥）
nano .env
```

**⚠️ 重要：必须修改以下配置**
- `MYSQL_ROOT_PASSWORD` - MySQL root 密码
- `MYSQL_PASSWORD` - MySQL 用户密码
- `JWT_SECRET` - JWT 密钥（至少32个字符）
- `CORS_ALLOW_ORIGINS` - 允许的前端域名
- `SHORT_LINK_BASE_URL` - 短链服务域名

### 3. 启动服务

```bash
# 构建并启动所有服务
docker-compose -f docker-compose.prod.yml up -d

# 查看服务状态
docker-compose -f docker-compose.prod.yml ps

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f
```

### 4. 验证部署

```bash
# 检查健康状态
curl http://localhost:8080/health

# 查看 API 文档
curl http://localhost:8080/swagger/index.html
```

---

## 📝 详细步骤

### 步骤 1: 准备服务器

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
docker --version
docker-compose --version
```

### 步骤 2: 配置 MySQL

创建 MySQL 配置文件：

```bash
sudo nano /root/docker/shortimg-ai/mysql/conf/my.cnf
```

添加以下内容：

```ini
[mysqld]
# 字符集配置
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# 性能优化
max_connections=1000
innodb_buffer_pool_size=2G
innodb_log_file_size=256M
innodb_flush_log_at_trx_commit=2

# 慢查询日志
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow.log
long_query_time=2

# 二进制日志
log_bin=/var/log/mysql/mysql-bin
binlog_format=ROW
expire_logs_days=7

[client]
default-character-set=utf8mb4
```

### 步骤 3: 配置 Redis

创建 Redis 配置文件（可选）：

```bash
sudo nano /root/docker/shortimg-ai/redis/redis.conf
```

添加以下内容：

```conf
# 持久化配置
appendonly yes
appendfsync everysec

# 内存管理
maxmemory 1gb
maxmemory-policy allkeys-lru

# 保存策略
save 900 1
save 300 10
save 60 10000

# 安全配置（如需密码认证）
# requirepass your_redis_password
```

### 步骤 4: 配置反向代理（推荐）

使用 Nginx 作为反向代理：

```bash
sudo apt install nginx -y
```

创建 Nginx 配置：

```bash
sudo nano /etc/nginx/sites-available/shortimg-ai
```

添加配置：

```nginx
upstream backend {
    server localhost:8080;
}

server {
    listen 80;
    server_name your-domain.com;

    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL 证书配置
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    # SSL 优化
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # 客户端上传大小限制
    client_max_body_size 100M;

    # API 代理
    location /api {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|webp|ico|css|js)$ {
        proxy_pass http://backend;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Swagger 文档
    location /swagger {
        proxy_pass http://backend;
    }

    # 健康检查
    location /health {
        proxy_pass http://backend;
        access_log off;
    }
}
```

启用配置：

```bash
sudo ln -s /etc/nginx/sites-available/shortimg-ai /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## ⚙️ 配置说明

### 环境变量详解

| 变量名 | 说明 | 默认值 | 必填 |
|--------|------|--------|------|
| `MYSQL_ROOT_PASSWORD` | MySQL root 密码 | - | ✅ |
| `MYSQL_DATABASE` | 数据库名称 | imagebed | ✅ |
| `MYSQL_USER` | 数据库用户名 | imagebed_user | ✅ |
| `MYSQL_PASSWORD` | 数据库密码 | - | ✅ |
| `JWT_SECRET` | JWT 加密密钥 | - | ✅ |
| `ALLOW_REGISTRATION` | 允许用户注册 | false | ❌ |
| `MAX_FILE_SIZE` | 最大文件大小(MB) | 100 | ❌ |
| `STORAGE_TYPE` | 存储类型 | local | ❌ |
| `SHORT_LINK_ENABLED` | 启用短链服务 | true | ❌ |
| `CORS_ALLOW_ORIGINS` | 允许的跨域源 | - | ✅ |

### 存储类型配置

#### 本地存储 (默认)
```env
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=/app/uploads
STORAGE_BASE_URL=/api/files
```

#### S3 兼容存储
```env
STORAGE_TYPE=s3
STORAGE_S3_ENDPOINT=https://s3.amazonaws.com
STORAGE_S3_BUCKET=your-bucket-name
STORAGE_S3_ACCESS_KEY=your-access-key
STORAGE_S3_SECRET_KEY=your-secret-key
STORAGE_S3_REGION=us-east-1
```

#### 阿里云 OSS
```env
STORAGE_TYPE=oss
STORAGE_OSS_ENDPOINT=https://oss-cn-hangzhou.aliyuncs.com
STORAGE_OSS_BUCKET=your-bucket-name
STORAGE_OSS_ACCESS_KEY=your-access-key
STORAGE_OSS_SECRET_KEY=your-secret-key
```

---

## 💾 数据持久化

### 目录结构

```
/root/docker/shortimg-ai/
├── mysql/
│   ├── data/           # MySQL 数据文件
│   ├── conf/           # MySQL 配置文件
│   └── logs/           # MySQL 日志
├── redis/
│   ├── data/           # Redis 持久化数据
│   └── redis.conf      # Redis 配置文件
└── backend/
    ├── uploads/        # 上传的图片文件
    ├── logs/           # 应用日志
    ├── data/           # SQLite 数据文件（如使用）
    └── config/         # 应用配置文件
```

### 备份策略

#### 数据库备份

```bash
#!/bin/bash
# backup-mysql.sh

BACKUP_DIR="/root/docker/shortimg-ai/backups/mysql"
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINER="shortimg-mysql-prod"

mkdir -p $BACKUP_DIR

# 备份数据库
docker exec $CONTAINER mysqldump -uroot -p$MYSQL_ROOT_PASSWORD imagebed > $BACKUP_DIR/imagebed_$DATE.sql

# 压缩备份文件
gzip $BACKUP_DIR/imagebed_$DATE.sql

# 删除30天前的备份
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "数据库备份完成: imagebed_$DATE.sql.gz"
```

#### 文件备份

```bash
#!/bin/bash
# backup-uploads.sh

BACKUP_DIR="/root/docker/shortimg-ai/backups/uploads"
SOURCE_DIR="/root/docker/shortimg-ai/backend/uploads"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 使用 rsync 增量备份
rsync -av --delete $SOURCE_DIR/ $BACKUP_DIR/latest/

# 创建每日快照
cp -al $BACKUP_DIR/latest/ $BACKUP_DIR/snapshot_$DATE/

# 删除30天前的快照
find $BACKUP_DIR -name "snapshot_*" -mtime +30 -exec rm -rf {} \;

echo "文件备份完成: snapshot_$DATE"
```

#### 设置定时备份

```bash
# 编辑 crontab
crontab -e

# 添加以下内容
# 每天凌晨2点备份数据库
0 2 * * * /root/scripts/backup-mysql.sh

# 每天凌晨3点备份文件
0 3 * * * /root/scripts/backup-uploads.sh
```

---

## 🛠️ 运维管理

### 常用命令

```bash
# 查看服务状态
docker-compose -f docker-compose.prod.yml ps

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f backend
docker-compose -f docker-compose.prod.yml logs -f mysql
docker-compose -f docker-compose.prod.yml logs -f redis

# 重启服务
docker-compose -f docker-compose.prod.yml restart backend

# 停止服务
docker-compose -f docker-compose.prod.yml stop

# 启动服务
docker-compose -f docker-compose.prod.yml start

# 重新构建并启动
docker-compose -f docker-compose.prod.yml up -d --build

# 清理未使用的资源
docker system prune -a
```

### 扩容与优化

#### 增加 MySQL 连接池

修改 `.env` 文件：

```env
# 增加最大连接数
MYSQL_MAX_CONNECTIONS=2000
```

修改 `docker-compose.prod.yml`：

```yaml
command:
  - --max-connections=2000
  - --innodb-buffer-pool-size=4G  # 增加缓冲池大小
```

#### 增加 Redis 内存

修改 `docker-compose.prod.yml`：

```yaml
command: >
  redis-server
  --maxmemory 2gb  # 增加到 2GB
```

#### 水平扩展后端服务

修改 `docker-compose.prod.yml`：

```yaml
backend:
  # ... 其他配置
  deploy:
    replicas: 3  # 运行3个实例
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '1'
        memory: 1G
```

配置负载均衡器（Nginx）：

```nginx
upstream backend {
    least_conn;  # 最少连接算法
    server backend-1:8080;
    server backend-2:8080;
    server backend-3:8080;
}
```

### 监控与告警

#### 安装 Prometheus + Grafana

```yaml
# 添加到 docker-compose.prod.yml
  prometheus:
    image: prom/prometheus:latest
    container_name: shortimg-prometheus
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - /root/docker/shortimg-ai/prometheus:/prometheus
    ports:
      - "9090:9090"
    networks:
      - shortimg-prod

  grafana:
    image: grafana/grafana:latest
    container_name: shortimg-grafana
    volumes:
      - /root/docker/shortimg-ai/grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    ports:
      - "3000:3000"
    networks:
      - shortimg-prod
```

---

## 🔧 故障排查

### 常见问题

#### 1. 服务无法启动

```bash
# 查看详细日志
docker-compose -f docker-compose.prod.yml logs backend

# 检查端口占用
netstat -tulpn | grep 8080

# 检查磁盘空间
df -h

# 检查内存使用
free -h
```

#### 2. 数据库连接失败

```bash
# 检查 MySQL 服务状态
docker-compose -f docker-compose.prod.yml ps mysql

# 测试数据库连接
docker exec -it shortimg-mysql-prod mysql -uroot -p

# 查看 MySQL 错误日志
docker-compose -f docker-compose.prod.yml logs mysql
```

#### 3. Redis 连接失败

```bash
# 检查 Redis 服务
docker exec -it shortimg-redis-prod redis-cli ping

# 查看 Redis 日志
docker-compose -f docker-compose.prod.yml logs redis
```

#### 4. 文件上传失败

```bash
# 检查上传目录权限
ls -la /root/docker/shortimg-ai/backend/uploads

# 修改权限
sudo chmod -R 755 /root/docker/shortimg-ai/backend/uploads

# 检查磁盘空间
df -h /root/docker/shortimg-ai
```

#### 5. 内存不足

```bash
# 查看容器资源使用
docker stats

# 限制容器内存
docker-compose -f docker-compose.prod.yml up -d --force-recreate \
  --scale backend=1 \
  --memory=2g
```

### 性能调优

#### MySQL 优化

```sql
-- 查看慢查询
SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;

-- 分析表
ANALYZE TABLE images;

-- 优化表
OPTIMIZE TABLE images;

-- 查看索引使用情况
SHOW INDEX FROM images;
```

#### Redis 优化

```bash
# 查看内存使用
docker exec shortimg-redis-prod redis-cli info memory

# 查看键空间
docker exec shortimg-redis-prod redis-cli info keyspace

# 清理过期键
docker exec shortimg-redis-prod redis-cli --scan --pattern "*" | xargs docker exec -i shortimg-redis-prod redis-cli del
```

---

## 🔒 安全建议

1. **修改默认密码**: 务必修改所有默认密码
2. **启用 HTTPS**: 使用 Let's Encrypt 免费证书
3. **配置防火墙**: 只开放必要的端口
4. **定期备份**: 设置自动备份任务
5. **监控日志**: 定期检查异常日志
6. **更新镜像**: 定期更新 Docker 镜像
7. **限制注册**: 生产环境关闭用户注册
8. **API 限流**: 配置请求速率限制

---

## 📞 技术支持

如遇到问题，请提供以下信息：

1. 系统版本: `uname -a`
2. Docker 版本: `docker --version`
3. 错误日志: `docker-compose logs`
4. 服务状态: `docker-compose ps`

---

**部署成功后，请访问：**

- API 文档: `http://your-domain.com/swagger/index.html`
- 健康检查: `http://your-domain.com/health`
- 前端界面: `http://your-domain.com`

🎉 祝部署顺利！
