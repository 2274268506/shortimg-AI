# 🚀 ShortImg-AI Backend - 生产环境部署包

## 📦 包含文件

### 配置文件
- `docker-compose.prod.yml` - Docker Compose 生产环境配置
- `.env.prod` - 环境变量模板
- `monitoring/prometheus.yml` - Prometheus 监控配置
- `monitoring/alerts.yml` - 告警规则配置

### 部署脚本
- `deploy-prod.sh` - 一键部署脚本
- `backup-mysql.sh` - MySQL 数据库备份脚本
- `backup-uploads.sh` - 上传文件备份脚本
- `restore-mysql.sh` - MySQL 数据库恢复脚本

### 文档
- `PRODUCTION_DEPLOY.md` - 详细部署文档
- `README.prod.md` - 本文件

## 🎯 快速开始

### 前置要求

- Linux 服务器 (Ubuntu 20.04+, CentOS 7+, Debian 10+)
- Docker 20.10+
- Docker Compose 1.29+
- 至少 4GB 内存
- 至少 20GB 磁盘空间

### 一键部署

```bash
# 1. 上传代码到服务器
cd /path/to/backend

# 2. 赋予执行权限
chmod +x deploy-prod.sh backup-*.sh restore-*.sh

# 3. 运行部署脚本
sudo ./deploy-prod.sh
```

### 手动部署

```bash
# 1. 创建数据目录
sudo mkdir -p /root/docker/shortimg-ai/{mysql/{data,conf,logs},redis/data,backend/{uploads,logs,data,config}}

# 2. 配置环境变量
cp .env.prod .env
nano .env  # 修改密码和密钥

# 3. 启动服务
docker-compose -f docker-compose.prod.yml up -d

# 4. 查看状态
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs -f
```

## 📁 数据持久化

所有数据存储在 `/root/docker/shortimg-ai/` 目录下：

```
/root/docker/shortimg-ai/
├── mysql/
│   ├── data/           # MySQL 数据文件
│   ├── conf/           # MySQL 配置文件
│   └── logs/           # MySQL 日志
├── redis/
│   └── data/           # Redis 持久化数据
├── backend/
│   ├── uploads/        # 用户上传的图片
│   ├── logs/           # 应用日志
│   ├── data/           # SQLite 数据（如使用）
│   └── config/         # 应用配置
└── backups/
    ├── mysql/          # MySQL 备份
    └── uploads/        # 文件备份
```

## ⚙️ 重要配置

### 必须修改的配置

在 `.env` 文件中，务必修改以下配置：

```env
# MySQL 密码
MYSQL_ROOT_PASSWORD=your_secure_root_password_here
MYSQL_PASSWORD=your_secure_password_here

# JWT 密钥（至少32个字符）
JWT_SECRET=your_jwt_secret_key_minimum_32_characters_long

# 允许的跨域源
CORS_ALLOW_ORIGINS=https://your-domain.com

# 短链服务域名
SHORT_LINK_BASE_URL=https://your-domain.com/s
```

### 推荐配置

```env
# 禁用用户注册（生产环境）
ALLOW_REGISTRATION=false

# 最大文件大小（MB）
MAX_FILE_SIZE=100

# 存储类型（local, s3, oss, cos）
STORAGE_TYPE=local
```

## 🔧 常用命令

### 服务管理

```bash
# 查看服务状态
docker-compose -f docker-compose.prod.yml ps

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f
docker-compose -f docker-compose.prod.yml logs -f backend
docker-compose -f docker-compose.prod.yml logs -f mysql

# 重启服务
docker-compose -f docker-compose.prod.yml restart
docker-compose -f docker-compose.prod.yml restart backend

# 停止服务
docker-compose -f docker-compose.prod.yml stop

# 启动服务
docker-compose -f docker-compose.prod.yml start

# 重新构建
docker-compose -f docker-compose.prod.yml up -d --build
```

### 数据备份

```bash
# 备份 MySQL 数据库
sudo ./backup-mysql.sh

# 备份上传文件
sudo ./backup-uploads.sh

# 恢复 MySQL 数据库
sudo ./restore-mysql.sh
```

### 数据库管理

```bash
# 进入 MySQL 容器
docker exec -it shortimg-mysql-prod mysql -uroot -p

# 查看数据库
SHOW DATABASES;
USE imagebed;
SHOW TABLES;

# 导出数据
docker exec shortimg-mysql-prod mysqldump -uroot -p imagebed > backup.sql

# 导入数据
docker exec -i shortimg-mysql-prod mysql -uroot -p imagebed < backup.sql
```

### Redis 管理

```bash
# 进入 Redis 容器
docker exec -it shortimg-redis-prod redis-cli

# 查看键
KEYS *

# 查看内存使用
INFO memory

# 清空缓存
FLUSHDB
```

## 📊 监控

### 健康检查

```bash
# 后端 API
curl http://localhost:8080/health

# MySQL
docker exec shortimg-mysql-prod mysqladmin ping -h localhost -uroot -p

# Redis
docker exec shortimg-redis-prod redis-cli ping
```

### 资源监控

```bash
# 查看容器资源使用
docker stats

# 查看磁盘使用
df -h /root/docker/shortimg-ai

# 查看日志大小
du -sh /root/docker/shortimg-ai/*/logs
```

## 🔒 安全建议

1. **修改默认密码** - 所有默认密码必须修改
2. **启用 HTTPS** - 使用 Nginx + Let's Encrypt
3. **配置防火墙** - 只开放 80/443 端口
4. **定期备份** - 使用 cron 设置自动备份
5. **限制注册** - 生产环境关闭用户注册
6. **监控日志** - 定期检查异常访问
7. **更新镜像** - 定期更新 Docker 镜像

## 🔥 设置自动备份

编辑 crontab：

```bash
crontab -e
```

添加定时任务：

```cron
# 每天凌晨 2 点备份数据库
0 2 * * * /path/to/backend/backup-mysql.sh >> /var/log/backup-mysql.log 2>&1

# 每天凌晨 3 点备份文件
0 3 * * * /path/to/backend/backup-uploads.sh >> /var/log/backup-uploads.log 2>&1

# 每周日凌晨 4 点清理 Docker 资源
0 4 * * 0 docker system prune -af >> /var/log/docker-cleanup.log 2>&1
```

## 🌐 配置 Nginx 反向代理

创建 Nginx 配置文件：

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
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    client_max_body_size 100M;

    location /api {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /swagger {
        proxy_pass http://backend;
    }

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

## 📚 更多文档

- 详细部署文档：[PRODUCTION_DEPLOY.md](PRODUCTION_DEPLOY.md)
- API 文档：访问 `http://your-domain.com/swagger/index.html`
- 项目主页：[GitHub](https://github.com/your-username/shortimg-ai)

## 🆘 故障排查

### 服务无法启动

```bash
# 查看详细日志
docker-compose -f docker-compose.prod.yml logs backend

# 检查端口占用
netstat -tulpn | grep 8080

# 检查磁盘空间
df -h
```

### 数据库连接失败

```bash
# 检查 MySQL 容器
docker-compose -f docker-compose.prod.yml ps mysql

# 测试连接
docker exec -it shortimg-mysql-prod mysql -uroot -p

# 查看 MySQL 日志
docker-compose -f docker-compose.prod.yml logs mysql
```

### 文件上传失败

```bash
# 检查目录权限
ls -la /root/docker/shortimg-ai/backend/uploads

# 修改权限
sudo chmod -R 755 /root/docker/shortimg-ai/backend/uploads

# 检查磁盘空间
df -h /root/docker/shortimg-ai
```

## 📞 技术支持

如遇问题，请提供：

1. 系统版本：`uname -a`
2. Docker 版本：`docker --version`
3. 错误日志：`docker-compose -f docker-compose.prod.yml logs`
4. 服务状态：`docker-compose -f docker-compose.prod.yml ps`

---

**祝部署顺利！** 🎉

如有问题，请查看 [PRODUCTION_DEPLOY.md](PRODUCTION_DEPLOY.md) 获取更详细的信息。
