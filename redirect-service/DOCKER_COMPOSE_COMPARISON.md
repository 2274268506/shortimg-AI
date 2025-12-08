# 📊 Docker Compose 配置对比说明

## 📋 开发环境 vs 生产环境

### 🔄 主要差异

| 配置项 | 开发环境 (`docker-compose.yml`) | 生产环境 (`docker-compose.prod.yml`) |
|--------|--------------------------------|--------------------------------------|
| **端口映射** | `80:80`, `443:443` | `8081:80`, `8444:443` |
| **容器名称** | `short-link-*` | `shortlink-*-prod` |
| **镜像标签** | `latest` | `prod` |
| **卷挂载** | 相对路径 `./conf` | 绝对路径 `/root/docker/...` |
| **卷权限** | 可写 | 只读 `:ro` |
| **监控组件** | ✅ Prometheus, Grafana | ❌ 不包含（建议单独部署） |
| **健康检查** | ❌ 无 | ✅ 完整健康检查 |
| **重启策略** | `unless-stopped` | `always` |
| **网络** | 默认 bridge | 自定义子网 `172.21.0.0/16` |
| **日志** | 本地目录 | 持久化到宿主机 |

---

## 🔧 环境变量完整对比

### ✅ 已优化的生产环境配置

基于 `docker-compose.yml` 的环境变量，我已为 `docker-compose.prod.yml` 添加了以下完整配置：

#### 1️⃣ **数据库连接配置**

```bash
# Redis
REDIS_HOST=shortlink-redis-prod
REDIS_PORT=6379
REDIS_PASSWORD=your_password          # ⚠️ 生产环境必须设置
REDIS_DATABASE=1                       # 数据库编号

# MySQL
MYSQL_HOST=shortlink-mysql-prod
MYSQL_PORT=3306
MYSQL_USER=short_link
MYSQL_PASSWORD=your_password           # ⚠️ 生产环境必须设置
MYSQL_DATABASE=short_links
```

#### 2️⃣ **域名和服务配置**

```bash
# 短链服务域名
REDIRECT_DOMAIN=short.oxvxo.link       # 已更新
REDIRECT_PROTOCOL=https
REDIRECT_PORT=8081                     # 外部访问端口

# 图床服务器（重定向目标）
TC_GO_PRIMARY_DOMAIN=img.oxvxo.link
TC_GO_PRIMARY_PROTOCOL=https
TC_GO_BACKUP_DOMAIN=                   # 备用服务器（可选）
TC_GO_BACKUP_PROTOCOL=https
```

#### 3️⃣ **CDN 分流配置**

```bash
# CDN 路由模式
CDN_ROUTING_MODE=direct                # direct | auto | manual

# 私网配置（内网用户）
CDN_PRIVATE_DOMAIN=localhost
CDN_PRIVATE_PROTOCOL=http
CDN_PRIVATE_PORT=

# 公网配置（外网用户）
CDN_PUBLIC_DOMAIN=dxy.oxvxo.net
CDN_PUBLIC_PROTOCOL=https
CDN_PUBLIC_PORT=18443

# 多区域 CDN（可选）
CDN_NORTH_TELECOM_DOMAIN=              # 北方电信
CDN_SOUTH_UNICOM_DOMAIN=               # 南方联通
CDN_OVERSEAS_DOMAIN=                   # 海外节点

# 降级服务器
CDN_FALLBACK_DOMAIN=img.oxvxo.link
CDN_FALLBACK_PROTOCOL=https
```

#### 4️⃣ **缓存和性能配置**

```bash
# L1 本地缓存（Lua shared dict）
CACHE_LOCAL_TTL=300                    # 5分钟

# L2 Redis 缓存
CACHE_REDIS_TTL=3600                   # 1小时

# 限流配置
RATE_LIMIT_MAX=100                     # 每窗口最大请求数
RATE_LIMIT_WINDOW=60                   # 窗口时间（秒）
```

#### 5️⃣ **GeoIP 地理路由**

```bash
# 启用地理位置分流
ENABLE_GEOIP=false

# GeoIP 数据库路径
GEOIP_CITY_DB=/usr/local/openresty/nginx/geoip/GeoLite2-City.mmdb
GEOIP_ASN_DB=/usr/local/openresty/nginx/geoip/GeoLite2-ASN.mmdb
```

#### 6️⃣ **日志和监控**

```bash
# 日志级别
LOG_LEVEL=info                         # debug | info | warn | error

# Prometheus 监控
ENABLE_METRICS=true
METRICS_PORT=9145
```

#### 7️⃣ **管理和安全**

```bash
# 管理员认证
ADMIN_AUTH_ENABLED=true
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your_admin_password     # ⚠️ 生产环境必须设置

# API 密钥（后端集成）
API_KEY=your_api_key_minimum_32_chars  # ⚠️ 生产环境必须设置
```

---

## 🆚 详细配置对比

### OpenResty 服务

#### 开发环境
```yaml
openresty:
  container_name: short-link-openresty
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./conf/nginx.conf:/usr/local/.../nginx.conf    # 可写
  environment:
    - REDIRECT_DOMAIN=${REDIRECT_DOMAIN:-short.example.com}
  restart: unless-stopped
```

#### 生产环境
```yaml
openresty:
  container_name: shortlink-openresty-prod
  ports:
    - "8081:80"       # 由外部 Nginx 代理
    - "8444:443"
  volumes:
    - /root/docker/.../nginx.conf:/usr/local/.../nginx.conf:ro  # 只读
  environment:
    - REDIRECT_DOMAIN=${REDIRECT_DOMAIN:-short.oxvxo.link}
    - ADMIN_AUTH_ENABLED=${ADMIN_AUTH_ENABLED:-true}  # 新增
    - ENABLE_METRICS=${ENABLE_METRICS:-true}          # 新增
  healthcheck:                                         # 新增
    test: ["CMD", "curl", "-f", "http://localhost/health"]
    interval: 30s
    timeout: 10s
    retries: 3
  depends_on:                                          # 新增健康检查依赖
    redis:
      condition: service_healthy
    mysql:
      condition: service_healthy
  restart: always
```

### Redis 服务

#### 开发环境
```yaml
redis:
  container_name: short-link-redis
  ports:
    - "6379:6379"
  command: redis-server --appendonly yes --maxmemory 2gb
  volumes:
    - redis-data:/data    # 命名卷
```

#### 生产环境
```yaml
redis:
  container_name: shortlink-redis-prod
  ports:
    - "6380:6379"         # 避免端口冲突
  command: >
    redis-server
    --appendonly yes
    --appendfsync everysec
    --maxmemory 2gb
    --maxmemory-policy allkeys-lru
    --save 900 1
    --save 300 10
    --save 60 10000
    --requirepass ${REDIS_PASSWORD}  # 需要密码
  volumes:
    - /root/docker/.../redis:/data   # 宿主机路径
  healthcheck:                        # 新增
    test: ["CMD", "redis-cli", "ping"]
    interval: 30s
```

### MySQL 服务

#### 开发环境
```yaml
mysql:
  container_name: short-link-mysql
  ports:
    - "3306:3306"
  environment:
    - MYSQL_ROOT_PASSWORD=your_password
  volumes:
    - mysql-data:/var/lib/mysql      # 命名卷
    - ./sql/schema.sql:/docker-entrypoint-initdb.d/schema.sql:ro
  command: --character-set-server=utf8mb4
```

#### 生产环境
```yaml
mysql:
  container_name: shortlink-mysql-prod
  ports:
    - "3307:3306"                    # 避免端口冲突
  environment:
    - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
    - TZ=Asia/Shanghai               # 时区
  volumes:
    - /root/docker/.../mysql/data:/var/lib/mysql
    - /root/docker/.../mysql/conf:/etc/mysql/conf.d:ro
    - /root/docker/.../mysql/logs:/var/log/mysql
    - ./sql/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql:ro
    - ./sql/init_data.sql:/docker-entrypoint-initdb.d/02-init_data.sql:ro
  command:
    - --character-set-server=utf8mb4
    - --collation-server=utf8mb4_unicode_ci
    - --authentication-policy=caching_sha2_password
    - --max-connections=500
    - --innodb-buffer-pool-size=1G
    - --innodb-redo-log-capacity=256M
    - --binlog-expire-logs-seconds=604800
  healthcheck:                       # 新增
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    interval: 30s
```

---

## 🔍 监控组件对比

### 开发环境包含的监控组件

```yaml
# Prometheus
prometheus:
  ports: ["9090:9090"]
  volumes:
    - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro

# Grafana  
grafana:
  ports: ["3000:3000"]
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin

# Redis Exporter
redis-exporter:
  ports: ["9121:9121"]
  environment:
    - REDIS_ADDR=redis:6379

# MySQL Exporter
mysql-exporter:
  ports: ["9104:9104"]
```

### 生产环境监控建议

**❌ 不包含在 `docker-compose.prod.yml` 中**

**原因：**
1. 监控组件应该集中部署，而不是每个服务都部署一套
2. 减少资源消耗
3. 统一管理所有服务的监控

**建议：**
- 使用独立的监控服务器
- 或者使用后端已部署的 `docker-compose.monitoring.yml`
- OpenResty 内置 Prometheus 导出器，通过 `/metrics` 端点暴露指标

---

## 📝 迁移检查清单

### 从开发环境迁移到生产环境

- [ ] **修改端口映射**
  - 开发：`80:80`, `443:443`
  - 生产：`8081:80`, `8444:443`（由外部 Nginx 代理）

- [ ] **更新域名配置**
  - `REDIRECT_DOMAIN=short.oxvxo.link`
  - `TC_GO_PRIMARY_DOMAIN=img.oxvxo.link`

- [ ] **设置所有密码**
  - `MYSQL_ROOT_PASSWORD`
  - `MYSQL_PASSWORD`
  - `REDIS_PASSWORD`
  - `ADMIN_PASSWORD`
  - `API_KEY`

- [ ] **配置 CDN 分流**（如果需要）
  - `CDN_ROUTING_MODE=direct` 或 `auto`
  - 设置公网 CDN 域名

- [ ] **启用健康检查**
  - OpenResty: `/health` 端点
  - Redis: `redis-cli ping`
  - MySQL: `mysqladmin ping`

- [ ] **配置日志路径**
  - OpenResty 日志: `/root/docker/.../logs`
  - MySQL 日志: `/root/docker/.../mysql/logs`

- [ ] **更新卷挂载路径**
  - 从相对路径 `./conf` → 绝对路径 `/root/docker/...`
  - 设置只读权限 `:ro`

- [ ] **配置监控**
  - 设置 `ENABLE_METRICS=true`
  - 配置 Prometheus 抓取 `http://host:8081/metrics`

- [ ] **配置外部 Nginx**
  - 部署 `nginx/short.oxvxo.link.conf`
  - 申请 SSL 证书
  - 配置反向代理到 `127.0.0.1:8081`

---

## 🎯 最佳实践建议

### 生产环境优化

1. **安全性**
   - ✅ 所有服务密码必须设置且强度足够
   - ✅ API 密钥至少 32 字符
   - ✅ 配置文件设为只读 `:ro`
   - ✅ 启用管理员认证
   - ✅ Redis 必须设置密码

2. **性能优化**
   - ✅ Redis 最大内存设为 2GB
   - ✅ MySQL 缓冲池设为 1GB
   - ✅ 启用两级缓存（本地 + Redis）
   - ✅ 配置合理的 TTL（本地 5分钟，Redis 1小时）

3. **高可用性**
   - ✅ 重启策略设为 `always`
   - ✅ 配置健康检查和依赖关系
   - ✅ 设置备用服务器（`TC_GO_BACKUP_DOMAIN`）
   - ✅ 配置降级服务器（`CDN_FALLBACK_DOMAIN`）

4. **监控和日志**
   - ✅ 启用 Prometheus 监控
   - ✅ 设置合理的日志级别（生产：info）
   - ✅ 日志持久化到宿主机
   - ✅ 配置日志轮转

5. **网络隔离**
   - ✅ 使用自定义网络和子网
   - ✅ 外部端口与内部端口分离
   - ✅ 通过外部 Nginx 代理，不直接暴露服务

---

## 📚 相关文档

- 📖 [生产环境部署指南](./PRODUCTION_DEPLOYMENT.md)
- 📖 [配置文件说明](./CONFIG_FILES_GUIDE.md)
- 📖 [环境变量配置](./.env.prod)
- 📖 [Nginx 反向代理配置](../nginx/short.oxvxo.link.conf)

---

## ✅ 总结

### 已完成的优化

1. ✅ 参考 `docker-compose.yml` 补全所有环境变量
2. ✅ 更新域名从 `s.img.oxvxo.link` → `short.oxvxo.link`
3. ✅ 添加完整的 CDN 分流配置
4. ✅ 添加 GeoIP 地理路由配置
5. ✅ 添加管理员认证配置
6. ✅ 添加日志级别配置
7. ✅ 优化缓存配置（L1 + L2）
8. ✅ 保持生产环境简洁（不包含开发用监控组件）

### 关键差异

| 特性 | 开发环境 | 生产环境 |
|------|---------|---------|
| 目的 | 开发调试 | 生产运行 |
| 端口 | 标准端口 80/443 | 自定义端口 8081/8444 |
| 卷挂载 | 可写，相对路径 | 只读，绝对路径 |
| 监控 | 内置完整监控栈 | 仅导出指标 |
| 安全 | 弱密码可接受 | 强制强密码 |
| 健康检查 | 可选 | 必须 |

🚀 **现在生产环境配置已完全参考开发环境优化，可以安全部署！**
