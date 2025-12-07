# 🧙‍♂️ 短链服务配置向导

一步步引导您完成短链服务的配置，5分钟快速上手！

---

## 📋 配置前准备

在开始配置前，请准备以下信息：

- [ ] 短链访问域名（如：`s.yourdomain.com`）
- [ ] CDN或服务器域名
- [ ] Redis 服务器信息
- [ ] MySQL 数据库信息

---

## 🎯 第一步：选择部署场景

根据您的实际情况，选择对应的场景：

### 场景A：本地开发测试 🏠

**适用于：** 开发调试、功能测试

```bash
# .env 配置
CDN_ROUTING_MODE=private
REDIRECT_DOMAIN=localhost
REDIRECT_PROTOCOL=http

CDN_PRIVATE_DOMAIN=localhost
CDN_PRIVATE_PROTOCOL=http

REDIS_HOST=127.0.0.1
MYSQL_HOST=127.0.0.1
```

✅ **验证方式：**
```bash
# 访问短链
curl http://localhost/abc123

# 应该重定向到
http://localhost/your-image-path
```

---

### 场景B：单服务器生产环境 🌐

**适用于：**
- 单台服务器部署
- NAT网络环境
- 没有多个CDN节点

```bash
# .env 配置
CDN_ROUTING_MODE=public
REDIRECT_DOMAIN=s.yourdomain.com
REDIRECT_PROTOCOL=https

CDN_PUBLIC_DOMAIN=img.yourdomain.com
CDN_PUBLIC_PORT=443
CDN_PUBLIC_PROTOCOL=https

TC_GO_PRIMARY_DOMAIN=img.yourdomain.com
TC_GO_PRIMARY_PROTOCOL=https

REDIS_HOST=your-redis-server
MYSQL_HOST=your-mysql-server
```

✅ **验证方式：**
```bash
# 访问短链
curl https://s.yourdomain.com/abc123

# 应该重定向到
https://img.yourdomain.com/your-image-path
```

⚠️ **注意事项：**
1. 确保 DNS 已正确配置
2. SSL 证书已部署
3. 防火墙已开放 443 端口

---

### 场景C：多CDN智能分流 🚀

**适用于：**
- 有多个CDN节点
- 需要根据用户地理位置优化访问
- 国内外用户访问优化

```bash
# .env 配置
CDN_ROUTING_MODE=auto
REDIRECT_DOMAIN=s.yourdomain.com
REDIRECT_PROTOCOL=https

# 公网默认CDN
CDN_PUBLIC_DOMAIN=cdn-default.yourdomain.com
CDN_PUBLIC_PROTOCOL=https

# 北方电信CDN（可选）
CDN_NORTH_TELECOM_DOMAIN=cdn-telecom.yourdomain.com
CDN_NORTH_TELECOM_PROTOCOL=https

# 南方联通CDN（可选）
CDN_SOUTH_UNICOM_DOMAIN=cdn-unicom.yourdomain.com
CDN_SOUTH_UNICOM_PROTOCOL=https

# 海外CDN（可选）
CDN_OVERSEAS_DOMAIN=cdn-global.yourdomain.com
CDN_OVERSEAS_PROTOCOL=https

# GeoIP数据库（必需）
GEOIP_COUNTRY_DB=/path/to/GeoLite2-Country.mmdb
GEOIP_CITY_DB=/path/to/GeoLite2-City.mmdb
GEOIP_ASN_DB=/path/to/GeoLite2-ASN.mmdb
```

✅ **验证方式：**
```bash
# 国内电信用户访问
curl https://s.yourdomain.com/abc123
# → https://cdn-telecom.yourdomain.com/path

# 国内联通用户访问
curl https://s.yourdomain.com/abc123
# → https://cdn-unicom.yourdomain.com/path

# 海外用户访问
curl https://s.yourdomain.com/abc123
# → https://cdn-global.yourdomain.com/path
```

📥 **下载 GeoIP 数据库：**
```bash
# 注册并下载（免费）
https://dev.maxmind.com/geoip/geoip2/geolite2/

# 或使用脚本自动下载
./scripts/download_geoip.sh
```

---

## 🔧 第二步：配置数据库

### Redis 配置

```bash
# 本地 Redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DATABASE=0

# 远程 Redis（推荐生产环境）
REDIS_HOST=your-redis-server.com
REDIS_PORT=6379
REDIS_PASSWORD=your-strong-password
REDIS_DATABASE=0
```

**测试连接：**
```bash
redis-cli -h 127.0.0.1 -p 6379 ping
# 应该返回: PONG
```

### MySQL 配置

```bash
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_DATABASE=short_links
MYSQL_USER=root
MYSQL_PASSWORD=your_strong_password
```

**初始化数据库：**
```sql
-- 创建数据库
CREATE DATABASE short_links CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 导入表结构
mysql -u root -p short_links < schema.sql
```

**测试连接：**
```bash
mysql -h 127.0.0.1 -u root -p short_links -e "SELECT 1"
```

---

## 🔐 第三步：安全配置

### 修改默认密钥

⚠️ **重要：生产环境必须修改！**

```bash
# 生成随机密钥（Linux/macOS）
openssl rand -base64 32

# 生成随机密钥（Windows PowerShell）
[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 }))

# 更新 .env
DEFAULT_TOKEN_SECRET=your-generated-random-string
```

### 修改管理员账号

```bash
ADMIN_USERNAME=your_admin_name
ADMIN_PASSWORD=your_strong_password_here
```

### 配置访问限流

```bash
# 防止API滥用
RATE_LIMIT_MAX=100      # 每分钟最多100次请求
RATE_LIMIT_WINDOW=60    # 时间窗口60秒
```

---

## 🎨 第四步：优化配置（可选）

### 缓存优化

```bash
# 本地缓存（Nginx共享内存）
CACHE_LOCAL_TTL=300     # 5分钟，适合高频访问短链

# Redis缓存
CACHE_REDIS_TTL=3600    # 1小时，平衡性能和实时性
```

**调优建议：**
- 热门短链增加缓存时间
- 临时短链减少缓存时间
- 静态资源增加缓存时间

### 健康检查调优

```bash
HEALTH_CHECK_INTERVAL=5    # 检查频率，建议5-10秒
HEALTH_CHECK_TIMEOUT=2000  # 超时时间，建议2-5秒
HEALTH_CHECK_FALL=3        # 失败3次标记下线
HEALTH_CHECK_RISE=2        # 成功2次标记上线
```

### 日志级别

```bash
# 开发环境
LOG_LEVEL=debug

# 生产环境
LOG_LEVEL=info    # 推荐
# 或
LOG_LEVEL=warn    # 只记录警告和错误
```

---

## ✅ 第五步：验证配置

### 1. 检查配置文件语法

```bash
# 检查 .env 文件
cat .env | grep -v '^#' | grep -v '^$'

# 应该看到所有配置项
```

### 2. 测试数据库连接

```bash
# 测试脚本
./scripts/test_connections.sh

# 或手动测试
redis-cli -h $REDIS_HOST ping
mysql -h $MYSQL_HOST -u $MYSQL_USER -p -e "SELECT 1"
```

### 3. 启动服务

```bash
# Docker 启动
docker-compose up -d

# 查看日志
docker-compose logs -f redirect-service
```

### 4. 功能测试

```bash
# 1. 创建短链
curl -X POST http://localhost/api/create \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com/image.jpg",
    "expire": 0
  }'

# 2. 访问短链
curl -I http://localhost/abc123

# 3. 检查重定向
# 应该看到 Location 头指向正确的CDN地址
```

---

## 🚨 常见问题排查

### ❓ 短链无法访问

**检查清单：**
```bash
# 1. 检查服务是否运行
docker-compose ps

# 2. 检查端口是否监听
netstat -tlnp | grep 80

# 3. 检查日志
docker-compose logs redirect-service | tail -50

# 4. 检查DNS解析
nslookup s.yourdomain.com

# 5. 检查防火墙
iptables -L -n | grep 80
```

### ❓ 重定向到错误的CDN

**场景1：NAT环境重定向到localhost**
```bash
# 解决方案：强制使用public模式
CDN_ROUTING_MODE=public
```

**场景2：GeoIP判断错误**
```bash
# 检查GeoIP数据库
ls -lh /path/to/geoip/*.mmdb

# 更新GeoIP数据库
./scripts/download_geoip.sh

# 检查X-Forwarded-For头
# 确保Nginx配置了proxy_set_header
```

### ❓ Redis/MySQL连接失败

**Redis连接失败：**
```bash
# 检查Redis服务
systemctl status redis

# 测试连接
redis-cli -h $REDIS_HOST -p $REDIS_PORT ping

# 检查密码
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD ping
```

**MySQL连接失败：**
```bash
# 检查MySQL服务
systemctl status mysql

# 测试连接
mysql -h $MYSQL_HOST -u $MYSQL_USER -p

# 检查权限
GRANT ALL ON short_links.* TO 'user'@'%' IDENTIFIED BY 'password';
FLUSH PRIVILEGES;
```

### ❓ 管理后台无法登录

```bash
# 检查配置
echo $ADMIN_AUTH_ENABLED
echo $ADMIN_USERNAME
echo $ADMIN_PASSWORD

# 重置密码
# 1. 修改 .env
ADMIN_PASSWORD=new_password

# 2. 重启服务
docker-compose restart redirect-service
```

---

## 📊 性能监控

### 监控指标

```bash
# Redis监控
redis-cli info stats

# MySQL监控
mysql -e "SHOW GLOBAL STATUS LIKE 'Threads%'"

# Nginx监控
curl http://localhost/nginx_status
```

### 推荐工具

- **Grafana + Prometheus** - 可视化监控
- **ELK Stack** - 日志分析
- **Redis Commander** - Redis可视化管理
- **phpMyAdmin** - MySQL可视化管理

---

## 🔄 配置更新流程

### 修改配置

```bash
# 1. 备份当前配置
cp .env .env.backup

# 2. 修改配置
vim .env

# 3. 验证配置
./scripts/validate_config.sh

# 4. 重启服务
docker-compose restart redirect-service

# 5. 检查日志
docker-compose logs -f redirect-service
```

### 回滚配置

```bash
# 如果出现问题，立即回滚
cp .env.backup .env
docker-compose restart redirect-service
```

---

## 📚 进阶配置

### 多环境配置

```bash
# 开发环境
.env.development

# 测试环境
.env.staging

# 生产环境
.env.production

# 使用指定环境
docker-compose --env-file .env.production up -d
```

### 配置模板

```bash
# 创建配置模板
cp .env.example .env.template

# 使用模板
cp .env.template .env
# 然后修改具体值
```

---

## 🎓 最佳实践

### ✅ DO（推荐做法）

- ✅ 使用环境变量管理敏感信息
- ✅ 定期更新GeoIP数据库
- ✅ 启用访问限流防止滥用
- ✅ 配置健康检查自动恢复
- ✅ 生产环境使用强密码
- ✅ 定期备份配置文件
- ✅ 使用HTTPS保护数据传输
- ✅ 监控服务运行状态

### ❌ DON'T（避免做法）

- ❌ 不要将 .env 提交到版本控制
- ❌ 不要使用默认密码
- ❌ 不要在日志中记录敏感信息
- ❌ 不要忽略健康检查警告
- ❌ 不要在生产环境使用 debug 日志级别
- ❌ 不要频繁修改配置（会导致缓存失效）

---

## 📞 获取帮助

- 📖 **详细文档：** [CONFIG_GUIDE.md](./CONFIG_GUIDE.md)
- 🐛 **问题反馈：** GitHub Issues
- 💬 **社区讨论：** GitHub Discussions
- 📧 **技术支持：** support@yourdomain.com

---

**恭喜！您已完成短链服务配置！** 🎉

现在可以开始使用短链服务了。如有问题，请参考本文档的故障排查部分。
