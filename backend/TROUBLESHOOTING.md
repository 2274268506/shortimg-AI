# 🔧 故障排查指南

## 常见问题及解决方案

### 1. 日志权限错误

**错误信息：**
```
can't open new logfile: open /app/logs/app.log: permission denied
```

**原因：**
容器内的用户 (UID 1000) 没有写入宿主机挂载目录的权限。

**解决方案：**

#### 方案 A：使用修复脚本（推荐）
```bash
sudo chmod +x fix-permissions.sh
sudo ./fix-permissions.sh
docker-compose -f docker-compose.prod.yml restart backend
```

#### 方案 B：手动修复
```bash
# 修改 backend 目录权限
sudo chown -R 1000:1000 /root/docker/shortimg-ai/backend/logs
sudo chmod -R 755 /root/docker/shortimg-ai/backend/logs

# 重启后端服务
docker-compose -f docker-compose.prod.yml restart backend
```

#### 方案 C：临时禁用文件日志
修改 `.env` 文件：
```env
LOG_PATH=stdout  # 日志输出到标准输出
```

---

### 2. 健康检查失败 (404)

**错误信息：**
```
"status": 404, "method": "HEAD", "path": "/health"
```

**原因：**
健康检查端点路径不正确。

**解决方案：**

#### 检查实际的健康检查端点
```bash
# 进入容器测试
docker exec -it shortimg-backend-prod sh
wget -O- http://localhost:8080/health

# 或者从宿主机测试
curl http://localhost:8080/health
```

#### 更新 docker-compose.prod.yml
健康检查路径已修复为：
```yaml
healthcheck:
  test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
```

#### 验证修复
```bash
# 重启容器
docker-compose -f docker-compose.prod.yml up -d --force-recreate backend

# 查看健康状态
docker-compose -f docker-compose.prod.yml ps
```

---

### 3. MySQL 废弃警告

**警告信息：**
```
[Warning] 'default_authentication_plugin' is deprecated
[Warning] 'binlog_format' is deprecated
[Warning] 'expire-logs-days' is deprecated
[Warning] innodb_log_file_size is deprecated
```

**原因：**
MySQL 8.0 部分配置参数已废弃。

**解决方案：**

配置已更新为新的参数：

| 旧参数 | 新参数 |
|--------|--------|
| `--default-authentication-plugin` | `--authentication-policy` |
| `--expire-logs-days` | `--binlog-expire-logs-seconds` |
| `--innodb-log-file-size` | `--innodb-redo-log-capacity` |
| `--binlog-format` | (移除，使用默认 ROW) |

**应用更新：**
```bash
docker-compose -f docker-compose.prod.yml up -d --force-recreate mysql
```

---

### 4. 数据库连接失败

**错误信息：**
```
Error: failed to connect to database
```

**解决方案：**

#### 检查 MySQL 状态
```bash
docker-compose -f docker-compose.prod.yml ps mysql
docker-compose -f docker-compose.prod.yml logs mysql
```

#### 测试数据库连接
```bash
docker exec -it shortimg-mysql-prod mysql -uimagebed_user -p
# 输入 .env 中配置的密码
```

#### 检查网络连接
```bash
# 从 backend 容器测试连接
docker exec -it shortimg-backend-prod sh
# 在容器内
ping mysql
telnet mysql 3306
```

#### 检查 DSN 配置
确保 `.env` 文件中的数据库配置正确：
```env
MYSQL_USER=imagebed_user
MYSQL_PASSWORD=your_password
MYSQL_DATABASE=imagebed
```

---

### 5. Redis 连接失败

**错误信息：**
```
Error: failed to connect to redis
```

**解决方案：**

#### 检查 Redis 状态
```bash
docker-compose -f docker-compose.prod.yml ps redis
docker exec -it shortimg-redis-prod redis-cli ping
```

#### 测试连接
```bash
# 从 backend 容器测试
docker exec -it shortimg-backend-prod sh
telnet redis 6379
```

#### 检查配置
```env
REDIS_ENABLED=true
REDIS_ADDR=redis:6379
REDIS_PASSWORD=
```

---

### 6. 容器启动失败

**症状：**
容器不断重启或退出。

**排查步骤：**

#### 查看容器日志
```bash
docker-compose -f docker-compose.prod.yml logs backend
docker-compose -f docker-compose.prod.yml logs mysql
docker-compose -f docker-compose.prod.yml logs redis
```

#### 检查资源使用
```bash
# 查看容器资源
docker stats

# 查看磁盘空间
df -h

# 查看内存
free -h
```

#### 检查端口占用
```bash
# Linux
netstat -tulpn | grep -E '3306|6379|8080'

# 或使用 ss
ss -tulpn | grep -E '3306|6379|8080'
```

---

### 7. 文件上传失败

**错误信息：**
```
Error: failed to save file
```

**解决方案：**

#### 检查上传目录权限
```bash
ls -la /root/docker/shortimg-ai/backend/uploads
```

#### 修复权限
```bash
sudo chown -R 1000:1000 /root/docker/shortimg-ai/backend/uploads
sudo chmod -R 755 /root/docker/shortimg-ai/backend/uploads
```

#### 检查磁盘空间
```bash
df -h /root/docker/shortimg-ai
```

#### 检查文件大小限制
```env
MAX_FILE_SIZE=100  # MB
```

---

### 8. 容器内存不足

**症状：**
容器被 OOM Killer 杀死。

**解决方案：**

#### 查看容器内存使用
```bash
docker stats --no-stream
```

#### 限制容器内存
修改 `docker-compose.prod.yml`：
```yaml
backend:
  deploy:
    resources:
      limits:
        memory: 2G
      reservations:
        memory: 1G
```

#### 优化应用配置
```env
# 减少 MySQL 缓冲池大小
MYSQL_BUFFER_POOL_SIZE=1G

# 减少 Redis 最大内存
REDIS_MAX_MEMORY=512mb
```

---

### 9. 网络连接问题

**错误信息：**
```
Error: dial tcp: lookup mysql: no such host
```

**解决方案：**

#### 检查网络
```bash
docker network ls
docker network inspect backend_shortimg-prod
```

#### 测试容器间通信
```bash
docker exec -it shortimg-backend-prod ping mysql
docker exec -it shortimg-backend-prod ping redis
```

#### 重建网络
```bash
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d
```

---

### 10. SSL/TLS 证书问题

**警告信息：**
```
[Warning] CA certificate ca.pem is self signed
```

**说明：**
这是正常的自签名证书警告，可以忽略。如需正式证书：

#### 使用 Let's Encrypt
```bash
# 安装 certbot
apt-get install certbot python3-certbot-nginx

# 申请证书
certbot --nginx -d your-domain.com
```

#### 配置 Nginx 使用证书
```nginx
ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
```

---

## 🔍 诊断命令汇总

### 查看服务状态
```bash
docker-compose -f docker-compose.prod.yml ps
```

### 查看日志
```bash
# 所有服务
docker-compose -f docker-compose.prod.yml logs -f

# 特定服务
docker-compose -f docker-compose.prod.yml logs -f backend
docker-compose -f docker-compose.prod.yml logs -f mysql
docker-compose -f docker-compose.prod.yml logs -f redis

# 最近 100 行
docker-compose -f docker-compose.prod.yml logs --tail=100 backend
```

### 进入容器调试
```bash
# Backend
docker exec -it shortimg-backend-prod sh

# MySQL
docker exec -it shortimg-mysql-prod mysql -uroot -p

# Redis
docker exec -it shortimg-redis-prod redis-cli
```

### 检查资源
```bash
# 容器资源使用
docker stats

# 磁盘使用
df -h /root/docker/shortimg-ai

# 内存使用
free -h

# CPU 负载
uptime
```

### 健康检查
```bash
# 运行健康检查脚本
sudo ./health-check.sh

# 手动检查健康端点
curl http://localhost:8080/health

# 详细健康检查
curl http://localhost:8080/health/detailed
```

---

## 🆘 紧急恢复流程

### 完全重启
```bash
# 1. 停止所有服务
docker-compose -f docker-compose.prod.yml down

# 2. 修复权限
sudo ./fix-permissions.sh

# 3. 重新启动
docker-compose -f docker-compose.prod.yml up -d

# 4. 查看状态
docker-compose -f docker-compose.prod.yml ps
docker-compose -f docker-compose.prod.yml logs -f
```

### 从备份恢复
```bash
# 1. 停止服务
docker-compose -f docker-compose.prod.yml down

# 2. 恢复数据库
sudo ./restore-mysql.sh

# 3. 恢复文件（如需要）
sudo rsync -av /root/docker/shortimg-ai/backups/uploads/latest/ /root/docker/shortimg-ai/backend/uploads/

# 4. 启动服务
docker-compose -f docker-compose.prod.yml up -d
```

### 清理并重建
```bash
# ⚠️ 警告：此操作会删除所有数据！

# 1. 备份数据
sudo ./backup-mysql.sh
sudo ./backup-uploads.sh

# 2. 停止并删除容器
docker-compose -f docker-compose.prod.yml down -v

# 3. 清理数据目录（可选）
# sudo rm -rf /root/docker/shortimg-ai/*

# 4. 重新部署
sudo ./deploy-prod.sh
```

---

## 📞 获取帮助

如果以上方法都无法解决问题，请收集以下信息：

```bash
# 系统信息
uname -a
docker --version
docker-compose --version

# 服务状态
docker-compose -f docker-compose.prod.yml ps

# 详细日志
docker-compose -f docker-compose.prod.yml logs > logs.txt

# 资源使用
docker stats --no-stream > stats.txt
df -h > disk.txt
free -h > memory.txt
```

然后提交 Issue 或寻求技术支持。
