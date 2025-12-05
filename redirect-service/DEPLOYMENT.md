# 部署指南

## 环境要求

- Docker 20.10+
- Docker Compose 2.0+
- 4GB+ 内存
- 50GB+ 磁盘空间

## 快速开始

### 1. 下载 GeoIP 数据库

```bash
# 创建 GeoIP 目录
mkdir -p geoip

# 下载 MaxMind GeoLite2 数据库（需要注册账号）
# 访问: https://dev.maxmind.com/geoip/geolite2-free-geolocation-data
# 下载以下文件并解压到 geoip 目录:
# - GeoLite2-City.mmdb
# - GeoLite2-ASN.mmdb
```

### 2. 配置域名

**重要**: 在启动服务前，需要配置域名。

#### 2.1 复制环境变量配置文件

```bash
# 复制示例配置文件
cp .env.example .env
```

#### 2.2 编辑 `.env` 文件，配置你的域名

```bash
# 编辑配置文件
nano .env  # 或使用其他编辑器
```

关键配置项：

```bash
# 重定向服务域名（短链域名）
REDIRECT_DOMAIN=short.yourdomain.com
REDIRECT_PROTOCOL=https

# CDN 服务器域名（根据实际 CDN 提供商配置）
CDN_NORTH_TELECOM_DOMAIN=cdn-bj.yourdomain.com
CDN_SOUTH_UNICOM_DOMAIN=cdn-gz.yourdomain.com
CDN_OVERSEAS_DOMAIN=cdn-us.yourdomain.com

# TC-GO 图床域名
TC_GO_PRIMARY_DOMAIN=img.yourdomain.com
TC_GO_BACKUP_DOMAIN=img-backup.yourdomain.com

# MySQL 密码（必须修改）
MYSQL_PASSWORD=your_strong_password
```

**配置说明**:
- `REDIRECT_DOMAIN`: 用户访问的短链域名，如 `s.yourdomain.com`
- `CDN_*_DOMAIN`: 各个 CDN 节点的实际域名
- `TC_GO_*_DOMAIN`: 图床服务器域名

详细配置指南请参考 [CONFIG_GUIDE.md](CONFIG_GUIDE.md)

### 3. 修改 Docker Compose 配置

编辑 `docker-compose.yml`，检查环境变量是否正确：

```yaml
environment:
  - MYSQL_PASSWORD=${MYSQL_PASSWORD:-your_strong_password}  # 会从 .env 读取
  - REDIRECT_DOMAIN=${REDIRECT_DOMAIN:-short.example.com}   # 会从 .env 读取
  # ... 其他配置会自动从 .env 加载
```

### 4. 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f openresty

# 检查服务状态
docker-compose ps

# 验证配置加载
docker-compose logs openresty | grep "Loading configuration"
# 应该看到:
# Loading configuration...
# Redirect service: https://short.yourdomain.com
# Redis initialized: redis:6379
# MySQL initialized: mysql:3306
```

### 5. 初始化数据库

数据库会在首次启动时自动初始化（通过 `sql/schema.sql`）。

验证数据库：

```bash
# 连接 MySQL
docker exec -it short-link-mysql mysql -uroot -p${MYSQL_PASSWORD} short_links

# 查看表
SHOW TABLES;

# 查看示例数据
SELECT * FROM short_links;
```

### 6. 配置域名 DNS 解析

在你的 DNS 服务商处添加记录：

```
# 短链服务
A    short.yourdomain.com    -> 服务器IP

# CDN 服务器（示例）
CNAME cdn-bj.yourdomain.com  -> 实际CDN地址
CNAME cdn-gz.yourdomain.com  -> 实际CDN地址
CNAME cdn-us.yourdomain.com  -> 实际CDN地址
```

### 7. 配置 SSL 证书（可选但推荐）

```bash
# 使用 Let's Encrypt 自动获取证书
docker run -it --rm \
  -v ./certs:/etc/letsencrypt \
  certbot/certbot certonly --standalone \
  -d short.yourdomain.com

# 修改 nginx.conf 启用 HTTPS
# 详见配置文件示例
```

### 8. 测试重定向

```bash
# 测试示例短链
curl -I http://localhost/r/tc-go-demo

# 应该返回 302 重定向
```

## 配置说明

### OpenResty 配置

主配置文件：`conf/nginx.conf`

关键配置项：

```nginx
# Worker 进程数（建议等于 CPU 核心数）
worker_processes auto;

# Lua 共享内存（根据短链数量调整）
lua_shared_dict short_links 100m;  # 本地缓存
lua_shared_dict stats 50m;         # 统计数据

# GeoIP 数据库路径
lua_package_path "/usr/local/openresty/nginx/lua/?.lua;;";
```

### Redis 配置

Redis 用于二级缓存，配置参数：

```yaml
command:
  - redis-server
  - --appendonly yes           # 启用持久化
  - --maxmemory 2gb            # 最大内存
  - --maxmemory-policy allkeys-lru  # LRU 淘汰策略
```

### MySQL 配置

MySQL 用于持久化存储，建议配置：

```sql
-- 调整缓冲池大小（根据内存调整）
SET GLOBAL innodb_buffer_pool_size = 1073741824; -- 1GB

-- 启用慢查询日志
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
```

## 性能调优

### 1. 系统参数

编辑 `/etc/sysctl.conf`：

```bash
# 最大文件描述符
fs.file-max = 1000000

# TCP 优化
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# 应用设置
sudo sysctl -p
```

### 2. OpenResty 优化

```nginx
# 增加 worker 连接数
events {
    worker_connections 10240;
}

# 调整 keepalive
upstream {
    keepalive 128;
    keepalive_requests 1000;
}

# 启用缓存
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:100m;
```

### 3. Redis 优化

```bash
# 禁用持久化（如果可以接受数据丢失）
docker-compose.yml 修改:
command: redis-server --save ""

# 或使用 RDB 快照
command: redis-server --save 900 1 --save 300 10
```

## 监控

### Grafana 面板

访问 http://localhost:3000（默认账号：admin/admin）

配置数据源：

1. 添加 MySQL 数据源（连接到 short-link-mysql）
2. 创建 Dashboard 展示：
   - 总访问量
   - QPS
   - 延迟分布
   - 地域分布
   - 设备类型分布

### 日志分析

```bash
# 实时查看访问日志
tail -f logs/access.log

# 统计 QPS
awk '{print $1}' logs/access.log | uniq -c

# 分析慢请求
grep '"response_time":[0-9]\{4,\}' logs/access.log
```

## 扩展

### 水平扩展

1. 部署多个 OpenResty 实例
2. 在前面部署 Nginx/LVS 做负载均衡
3. Redis 使用集群模式
4. MySQL 使用主从复制

```yaml
# docker-compose.yml
openresty:
  deploy:
    replicas: 3  # 部署 3 个实例
```

### 垂直扩展

增加单机资源：

```yaml
openresty:
  deploy:
    resources:
      limits:
        cpus: '4'
        memory: 8G
```

## 故障排查

### 1. 服务无法启动

```bash
# 查看日志
docker-compose logs openresty

# 检查配置文件语法
docker exec short-link-openresty nginx -t

# 检查端口占用
netstat -tlnp | grep 80
```

### 2. 数据库连接失败

```bash
# 测试 MySQL 连接
docker exec -it short-link-openresty ping mysql

# 检查 MySQL 状态
docker exec -it short-link-mysql mysqladmin -uroot -p status
```

### 3. Redis 连接失败

```bash
# 测试 Redis 连接
docker exec -it short-link-openresty redis-cli -h redis ping

# 检查 Redis 状态
docker exec -it short-link-redis redis-cli info
```

### 4. GeoIP 数据库加载失败

```bash
# 检查文件是否存在
docker exec -it short-link-openresty ls -lh /usr/local/openresty/nginx/geoip/

# 查看错误日志
docker-compose logs openresty | grep GeoIP
```

## 安全建议

1. **修改默认密码**：MySQL、Grafana 密码
2. **启用 HTTPS**：配置 SSL 证书
3. **限制访问**：配置防火墙规则
4. **启用认证**：管理 API 添加 Basic Auth
5. **定期备份**：备份 MySQL 数据和 Redis 快照

## 生产部署清单

- [ ] 修改所有默认密码
- [ ] 配置 SSL 证书
- [ ] 下载 GeoIP 数据库
- [ ] 调整 Worker 进程数
- [ ] 配置日志轮转
- [ ] 设置监控告警
- [ ] 配置自动备份
- [ ] 压力测试验证性能
- [ ] 准备回滚方案

## 更新升级

```bash
# 拉取最新镜像
docker-compose pull

# 重启服务（零停机）
docker-compose up -d --no-deps --build openresty

# 回滚到之前版本
docker-compose down
docker-compose up -d
```

## 支持

如有问题，请查看：

- 项目文档：[README.md](README.md)
- 问题追踪：GitHub Issues
- 邮件支持：support@example.com
