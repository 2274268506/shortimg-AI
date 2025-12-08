# 🌐 Nginx 配置部署指南

## 📋 前提条件

1. ✅ 已安装 Nginx
2. ✅ 已有 SSL 证书（或准备申请 Let's Encrypt）
3. ✅ 域名 DNS 已正确解析到服务器 IP
4. ✅ 后端服务运行在 `127.0.0.1:8080`

## 🚀 快速部署

### 1️⃣ 复制配置文件

```bash
# 复制配置到 Nginx 配置目录
sudo cp nginx/img.oxvxo.link.conf /etc/nginx/sites-available/img.oxvxo.link.conf

# 创建软链接启用站点
sudo ln -s /etc/nginx/sites-available/img.oxvxo.link.conf /etc/nginx/sites-enabled/

# 或者直接复制到 conf.d 目录（取决于你的 Nginx 配置）
sudo cp nginx/img.oxvxo.link.conf /etc/nginx/conf.d/
```

### 2️⃣ 修改配置（重要！）

编辑配置文件，修改以下内容：

```bash
sudo nano /etc/nginx/sites-available/img.oxvxo.link.conf
```

**必须修改的地方：**

1. **SSL 证书路径：**
   ```nginx
   ssl_certificate     /etc/ssl/certs/img.oxvxo.link.pem;
   ssl_certificate_key /etc/ssl/private/img.oxvxo.link.key;
   ```

2. **前端静态资源路径（如果前后端同域部署）：**
   ```nginx
   root /var/www/img.oxvxo.link/dist;
   ```

   如果前端部署在其他地方，修改此路径或注释掉 `location /` 块

3. **后端服务地址（如果不是 localhost:8080）：**
   ```nginx
   upstream backend_api {
       server 127.0.0.1:8080 max_fails=3 fail_timeout=30s;
   }
   ```

### 3️⃣ 创建必要的目录

```bash
# 创建日志目录
sudo mkdir -p /var/log/nginx

# 创建前端资源目录（如果前后端同域）
sudo mkdir -p /var/www/img.oxvxo.link/dist

# 创建证书验证目录（用于 Let's Encrypt）
sudo mkdir -p /var/www/certbot
```

### 4️⃣ 申请 SSL 证书（如果没有）

**使用 Certbot（Let's Encrypt）：**

```bash
# 安装 Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx

# 自动申请并配置证书
sudo certbot --nginx -d img.oxvxo.link -d www.img.oxvxo.link

# 或手动申请（推荐，更好控制）
sudo certbot certonly --webroot -w /var/www/certbot \
  -d img.oxvxo.link \
  -d www.img.oxvxo.link \
  --email your-email@example.com \
  --agree-tos

# 证书路径通常在：
# /etc/letsencrypt/live/img.oxvxo.link/fullchain.pem
# /etc/letsencrypt/live/img.oxvxo.link/privkey.pem
```

**更新配置中的证书路径：**

```nginx
ssl_certificate     /etc/letsencrypt/live/img.oxvxo.link/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/img.oxvxo.link/privkey.pem;
```

### 5️⃣ 测试配置

```bash
# 测试 Nginx 配置语法
sudo nginx -t

# 如果显示以下内容则配置正确：
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### 6️⃣ 重启 Nginx

```bash
# 重新加载配置（推荐，不中断服务）
sudo nginx -s reload

# 或完全重启
sudo systemctl restart nginx

# 检查服务状态
sudo systemctl status nginx
```

## 📦 部署前端（如果前后端同域）

```bash
# 在本地构建前端
cd frontend
npm run build

# 将 dist 目录上传到服务器
scp -r dist/* user@your-server:/var/www/img.oxvxo.link/dist/

# 或使用 rsync（推荐）
rsync -avz --delete dist/ user@your-server:/var/www/img.oxvxo.link/dist/

# 设置正确的权限
sudo chown -R www-data:www-data /var/www/img.oxvxo.link/dist
sudo chmod -R 755 /var/www/img.oxvxo.link/dist
```

## 🔧 配置说明

### 📍 Map 变量

```nginx
map $http_origin $cors_origin {
    default "";
    "~^https?://img\.oxvxo\.link(:\d+)?$" $http_origin;
    "~^https?://www\.img\.oxvxo\.link(:\d+)?$" $http_origin;
}
```

- 定义允许的 CORS 源
- 支持正则匹配，包含端口号
- 添加更多域名直接复制一行并修改

### 🚦 限流配置

```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/s;
limit_req_zone $binary_remote_addr zone=upload_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/s;
```

- **api_limit**: 通用 API 每秒 100 请求
- **upload_limit**: 上传接口每秒 10 请求
- **auth_limit**: 认证接口每秒 5 请求
- 根据实际需求调整

### 🔐 CORS 配置

配置中的 CORS 头部会：
- ✅ 回显请求的 Origin（仅允许白名单中的源）
- ✅ 支持 Credentials（Cookie）
- ✅ 处理预检请求（OPTIONS）
- ✅ 支持私有网络访问

### 📊 负载均衡（可选）

如果有多个后端实例：

```nginx
upstream backend_api {
    server 127.0.0.1:8080 weight=1 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:8081 weight=1 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:8082 weight=1 max_fails=3 fail_timeout=30s;

    keepalive 32;
}
```

## 🛡️ 安全建议

### 1️⃣ 限制敏感接口访问

```nginx
# Swagger 文档（建议生产环境禁用或限制 IP）
location /swagger/ {
    allow 192.168.1.0/24;  # 仅允许内网访问
    deny all;
    proxy_pass http://backend_api;
}

# Prometheus 监控（仅本地访问）
location /metrics {
    allow 127.0.0.1;
    deny all;
    proxy_pass http://backend_api;
}
```

### 2️⃣ 启用防火墙

```bash
# 仅开放必要端口
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### 3️⃣ 配置 fail2ban（防暴力破解）

```bash
# 安装 fail2ban
sudo apt install fail2ban

# 配置 Nginx 规则
sudo nano /etc/fail2ban/jail.local
```

添加：
```ini
[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/*error.log
maxretry = 5
findtime = 600
bantime = 3600
```

## 📈 监控和日志

### 查看访问日志

```bash
# 实时查看访问日志
sudo tail -f /var/log/nginx/img.oxvxo.link.access.log

# 查看错误日志
sudo tail -f /var/log/nginx/img.oxvxo.link.error.log

# 统计请求数
sudo awk '{print $1}' /var/log/nginx/img.oxvxo.link.access.log | sort | uniq -c | sort -nr | head -20
```

### 日志轮转

```bash
# 配置日志轮转
sudo nano /etc/logrotate.d/nginx
```

内容：
```
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

## 🔄 证书自动续期

```bash
# 测试续期
sudo certbot renew --dry-run

# 添加自动续期 cron 任务
sudo crontab -e

# 添加以下行（每天凌晨2点检查）
0 2 * * * certbot renew --quiet --post-hook "nginx -s reload"
```

## ✅ 验证部署

### 1️⃣ 测试 HTTPS

```bash
# 访问首页
curl -I https://img.oxvxo.link

# 测试 API
curl -H "Origin: https://img.oxvxo.link" https://img.oxvxo.link/api/health

# 测试 CORS
curl -H "Origin: https://img.oxvxo.link" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: authorization" \
     -X OPTIONS https://img.oxvxo.link/api/auth/login -v
```

### 2️⃣ SSL 评级测试

访问 https://www.ssllabs.com/ssltest/ 测试 SSL 配置评分

### 3️⃣ 检查 CORS

在浏览器控制台测试：

```javascript
fetch('https://img.oxvxo.link/api/health', {
  credentials: 'include'
}).then(r => r.json()).then(console.log)
```

## 🐛 故障排查

### 问题 1: 502 Bad Gateway

**原因：** 后端服务未启动或无法连接

**解决：**
```bash
# 检查后端服务
curl http://127.0.0.1:8080/health

# 检查 Docker 容器
docker ps | grep backend

# 查看后端日志
docker logs shortimg-backend-prod
```

### 问题 2: CORS 错误

**原因：** Origin 不在白名单中

**解决：**
```nginx
# 添加域名到 map 配置
map $http_origin $cors_origin {
    default "";
    "~^https?://your-domain\.com$" $http_origin;
}
```

### 问题 3: 413 Request Entity Too Large

**原因：** 上传文件超过限制

**解决：**
```nginx
# 增加上传大小限制
client_max_body_size 100M;
```

### 问题 4: 证书过期

**解决：**
```bash
# 手动续期
sudo certbot renew

# 重新加载 Nginx
sudo nginx -s reload
```

## 📚 相关文档

- [Nginx 官方文档](https://nginx.org/en/docs/)
- [Let's Encrypt 文档](https://letsencrypt.org/docs/)
- [Mozilla SSL 配置生成器](https://ssl-config.mozilla.org/)

## 🎉 完成！

现在你的 ShortImg-AI 应该可以通过 HTTPS 访问了！

访问：https://img.oxvxo.link 🚀
