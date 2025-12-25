# 短链服务 (ShortLink Redirect Service)# 🔗 智能短链重定向服务



基于 OpenResty + Lua 的高性能短链接服务，支持地理位置路由、CDN分流和访问统计。## 项目概述



## ✨ 特性基于 OpenResty + Redis + MySQL + Lua + Nginx 的高性能智能短链重定向服务，支持多种分流策略和故障转移，与 TC-GO 图床系统无缝集成。



- 🚀 **高性能**: OpenResty + Lua + Redis，支持高并发访问## 核心功能

- 🌍 **地理路由**: 基于 GeoIP 的智能 CDN 分流

- 📊 **访问统计**: 实时统计短链访问数据### 1. 多维度分流策略

- 🔐 **API 认证**: API Key 认证保护接口安全- **IP 分流** - 根据访客 IP 地址分配服务器

- 💾 **双层缓存**: 本地缓存 + Redis 缓存，降低数据库压力- **GeoIP 分流** - 基于地理位置（国家/省份/城市）

- 🔄 **自动降级**: 主服务器故障时自动切换到备用服务器- **ASN 分流** - 根据运营商 ASN 号码

- **设备类型** - PC/Mobile/Tablet 分流

## 🏗️ 技术栈- **时间段** - 根据时间段分配（高峰/低峰）

- **权重轮询** - 带权重的负载均衡

- **Web服务器**: OpenResty (Nginx + LuaJIT)- **哈希一致性** - 同一用户访问同一服务器

- **数据库**: MySQL 8.0

- **缓存**: Redis 7.0### 2. 高可用特性

- **地理位置**: MaxMind GeoLite2- **健康检查** - 实时检测服务器状态

- **容器化**: Docker + Docker Compose- **故障转移** - 自动切换到备用服务器

- **降级策略** - 服务异常时的降级处理

## 📁 项目结构- **熔断机制** - 防止雪崩效应



```### 3. 动态管理

redirect-service/- **热更新规则** - 无需重启即可更新分流规则

├── conf/                    # OpenResty 配置文件- **实时监控** - 访问统计、错误率、响应时间

│   ├── nginx.conf          # Nginx 主配置- **管理 API** - RESTful API 管理短链和规则

│   ├── config.lua          # Lua 配置加载- **缓存优化** - Redis 多级缓存加速

│   └── upstream.conf       # 上游服务器配置

├── lua/                    # Lua 业务逻辑### 4. 与图床集成

│   ├── core/               # 核心功能- **图片 CDN 加速** - 智能选择最近的图片服务器

│   ├── middleware/         # 中间件（认证、日志等）- **防盗链** - 支持 Referer 和 Token 验证

│   ├── routes/             # 路由处理- **流量统计** - 记录图片访问量和来源

│   ├── storage/            # 数据存储层

│   └── utils/              # 工具函数## 技术架构

├── sql/                    # 数据库初始化脚本

├── geoip/                  # GeoIP 数据库文件```

├── html/                   # 静态页面（404、健康检查等）┌─────────────┐

├── logs/                   # 日志目录│   Client    │

├── docker-compose.prod.yml # 生产环境配置└──────┬──────┘

├── docker-entrypoint.sh    # 容器启动脚本       │

├── .env.production         # 环境变量模板       ↓

└── README.md              # 本文件┌─────────────────────────────────────┐

```│        OpenResty (Nginx)            │

│  ┌───────────────────────────────┐  │

## 🚀 快速开始│  │   Lua 分流逻辑                │  │

│  │   - GeoIP 解析                │  │

### 前置要求│  │   - 规则匹配                  │  │

│  │   - 健康检查                  │  │

- Docker & Docker Compose│  └───────────────────────────────┘  │

- GeoIP 数据库文件（GeoLite2-City.mmdb, GeoLite2-ASN.mmdb）└────┬─────────────────────┬──────────┘

     │                     │

### 开发环境     ↓                     ↓

┌─────────┐          ┌──────────┐

```bash│  Redis  │          │  MySQL   │

# 1. 配置环境变量│  缓存层  │          │  持久化  │

cp .env.example .env└─────────┘          └──────────┘

nano .env     │

     ↓

# 2. 启动服务┌───────────────────────────────────┐

docker-compose up -d│      Upstream Servers             │

│  ┌──────┐  ┌──────┐  ┌──────┐   │

# 3. 查看日志│  │ CDN1 │  │ CDN2 │  │ CDN3 │   │

docker-compose logs -f openresty│  └──────┘  └──────┘  └──────┘   │

└───────────────────────────────────┘

# 4. 健康检查```

curl http://localhost:8081/health

```## 快速开始



### 生产部署### 方式一：Docker 部署（推荐）



详细部署步骤请参考项目根目录的 [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md)#### 1. 环境要求

- Docker 20.10+

```bash- Docker Compose 2.0+

# 1. 配置环境变量

cp .env.production .env#### 2. 配置域名

nano .env

```bash

# 2. 启动服务# 复制环境变量配置文件

docker-compose -f docker-compose.prod.yml up -dcp .env.example .env



# 3. 验证部署# 编辑配置文件，设置你的域名

curl https://short.yourdomain.com/healthnano .env

``````



## 🔧 配置说明关键配置：

```bash

### 关键配置项# 短链服务域名

REDIRECT_DOMAIN=s.yourdomain.com

#### API 密钥配置REDIRECT_PROTOCOL=https

```bash

# ⚠️ 必须与图床服务的 SHORT_LINK_API_KEY 一致# CDN 服务器域名（根据实际情况配置）

DASHBOARD_API_KEY=your_api_key_minimum_60_charactersCDN_NORTH_TELECOM_DOMAIN=cdn-bj.yourdomain.com

API_KEY=your_api_key_minimum_60_charactersCDN_SOUTH_UNICOM_DOMAIN=cdn-gz.yourdomain.com

```CDN_OVERSEAS_DOMAIN=cdn-us.yourdomain.com



#### Redis 配置# TC-GO 图床域名

```bashTC_GO_PRIMARY_DOMAIN=img.yourdomain.com

REDIS_HOST=shortlink-redis-prod

REDIS_PORT=6379# 数据库密码

REDIS_PASSWORD=your_redis_passwordMYSQL_PASSWORD=your_strong_password

REDIS_DB=1  # ⚠️ 必须设置为 1，与图床服务统一```

```

**详细配置指南**: 参考 [CONFIG_GUIDE.md](CONFIG_GUIDE.md)

#### 域名配置

```bash#### 3. 下载 GeoIP 数据库

# 短链服务域名

REDIRECT_DOMAIN=short.yourdomain.com```bash

REDIRECT_PROTOCOL=https# 创建目录

mkdir -p geoip

# 图床服务域名

TC_GO_PRIMARY_DOMAIN=img.yourdomain.com# 访问 https://dev.maxmind.com/geoip/geolite2-free-geolocation-data

TC_GO_PRIMARY_PROTOCOL=https# 注册并下载以下文件到 geoip/ 目录：

```# - GeoLite2-City.mmdb

# - GeoLite2-ASN.mmdb

## 📊 API 接口```



### 创建短链#### 4. 启动服务



```bash```bash

POST /api/v2/imagebed/create# 启动所有服务

Content-Type: application/jsondocker-compose up -d

X-API-Key: your_api_key

# 查看日志

{docker-compose logs -f openresty

  "image_path": "/uploads/test.jpg",

  "service_type": "imagebed"# 验证配置

}docker-compose logs openresty | grep "Redirect service"

``````



**响应示例：**#### 5. 测试

```json

{```bash

  "success": true,# 测试短链（需要先创建短链）

  "data": {curl -I http://localhost/r/test-code

    "short_url": "https://short.yourdomain.com/img-ABC123",```

    "code": "img-ABC123",

    "image_path": "/uploads/test.jpg",**完整示例**: 参考 [QUICKSTART.md](QUICKSTART.md)

    "created_at": 1703500000

  }### 方式二：手动安装

}

```### 环境要求

- OpenResty >= 1.21.4

### 访问短链- Redis >= 6.0

- MySQL >= 5.7

```bash- Lua >= 5.1

GET /img-ABC123

```### 安装步骤



自动跳转到目标图片，根据地理位置智能选择CDN节点。1. **安装 OpenResty**

```bash

### 健康检查# Windows (使用 WSL 或 Docker)

docker pull openresty/openresty:alpine

```bash

GET /health# Linux

```wget https://openresty.org/download/openresty-1.21.4.1.tar.gz

tar -xzf openresty-1.21.4.1.tar.gz

返回服务运行状态和统计信息。cd openresty-1.21.4.1

./configure --with-luajit

## 🔐 安全配置make && make install

```

### API Key 认证

2. **安装依赖模块**

所有创建短链的API请求必须携带有效的API Key：```bash

opm install ledgetech/lua-resty-http

```bashopm install pintsized/lua-resty-redis-connector

X-API-Key: your_api_key_hereopm install spacewander/lua-resty-rsa

```opm install doujiang24/lua-resty-kafka

```

API Key 在容器启动时自动注册到 Redis 数据库1。

3. **配置域名和数据库**

### Redis 数据库隔离```bash

# 复制并编辑配置文件

- **数据库0**: 通用缓存数据cp .env.example .env

- **数据库1**: API Key 和短链数据（⚠️ 重要）nano .env

```

确保 `REDIS_DB=1` 与图床服务配置一致。# 导入数据库表结构

mysql -u root -p < sql/schema.sql

## 🌍 CDN 路由

# 初始化 Redis

### 路由模式redis-cli < sql/redis_init.lua

```

1. **direct**: 所有请求直接访问主服务器（默认）

2. **auto**: 根据访问者IP自动选择最优CDN节点4. **启动服务**

3. **manual**: 使用 routing_rules.yaml 自定义路由规则```bash

# 启动 OpenResty

### 地理位置识别openresty -p /path/to/redirect-service -c conf/nginx.conf



基于 MaxMind GeoLite2 数据库识别用户地区和ISP：# 或使用 Docker

docker-compose up -d

- 🇨🇳 中国 → 按运营商分流（联通/移动/电信）```

- 🌏 亚太 → 亚太CDN节点

- 🌍 欧美 → 海外CDN节点## 目录结构



### 配置 CDN 节点```

redirect-service/

编辑 `.env` 文件配置各运营商的CDN域名：├── conf/

│   ├── nginx.conf              # Nginx 主配置

```bash│   ├── upstream.conf           # 上游服务器配置

# 联通用户│   └── geoip.conf             # GeoIP 配置

CDN_IMAGEBED_UNICOM_DOMAIN=unicom-cdn.yourdomain.com├── lua/

│   ├── core/

# 移动用户│   │   ├── router.lua         # 路由核心

CDN_IMAGEBED_MOBILE_DOMAIN=mobile-cdn.yourdomain.com│   │   ├── balancer.lua       # 负载均衡器

│   │   └── health_checker.lua # 健康检查

# 电信用户│   ├── strategies/

CDN_IMAGEBED_TELECOM_DOMAIN=telecom-cdn.yourdomain.com│   │   ├── ip_strategy.lua    # IP 分流策略

```│   │   ├── geo_strategy.lua   # GeoIP 分流策略

│   │   ├── asn_strategy.lua   # ASN 分流策略

## 📈 监控│   │   └── hash_strategy.lua  # 一致性哈希

│   ├── storage/

### Prometheus 指标│   │   ├── redis_client.lua   # Redis 客户端

│   │   └── mysql_client.lua   # MySQL 客户端

服务暴露 Prometheus 格式的监控指标：│   ├── utils/

│   │   ├── logger.lua         # 日志工具

```bash│   │   └── metrics.lua        # 监控指标

GET /metrics│   └── api/

```│       ├── admin_api.lua      # 管理 API

│       └── stats_api.lua      # 统计 API

主要指标：├── sql/

- `shortlink_requests_total`: 总请求数│   ├── schema.sql             # 数据库表结构

- `shortlink_redirect_success`: 重定向成功数│   └── redis_init.lua         # Redis 初始化

- `shortlink_redirect_errors`: 重定向失败数├── logs/                       # 日志目录

- `shortlink_cache_hits`: 缓存命中数├── docker-compose.yml         # Docker 编排

- `shortlink_cache_misses`: 缓存未命中数└── README.md                  # 项目文档

```

### 日志

## 配置示例

日志文件位置：

- 访问日志: `logs/access.log`### 1. 短链规则配置

- 错误日志: `logs/error.log`

```lua

查看实时日志：-- 添加短链

```bash{

docker exec shortlink-openresty-prod tail -f /usr/local/openresty/nginx/logs/access.log  "short_code": "abc123",

```  "name": "图床图片",

  "targets": [

## 🔧 故障排查    {

      "url": "https://cdn1.example.com/image.jpg",

### 问题1: API认证失败      "weight": 50,

      "region": "cn-north",

**症状**: 返回 "Authentication failed"      "isp": "telecom"

    },

**检查步骤**:    {

```bash      "url": "https://cdn2.example.com/image.jpg",

# 1. 检查 Redis 中的 API Key      "weight": 30,

docker exec shortlink-redis-prod redis-cli -a <password> -n 1 KEYS 'api_key:*'      "region": "cn-south",

      "isp": "unicom"

# 2. 检查环境变量    },

docker exec shortlink-openresty-prod env | grep API_KEY    {

      "url": "https://cdn3.example.com/image.jpg",

# 3. 查看启动日志      "weight": 20,

docker logs --tail 20 shortlink-openresty-prod      "region": "overseas"

```    }

  ],

**解决方案**: 确保 API Key 已注册到 Redis 数据库1。  "strategy": "geo+isp",

  "fallback": "https://backup.example.com/image.jpg"

### 问题2: 短链跳转404}

```

**症状**: 访问短链返回404

### 2. 分流规则示例

**检查步骤**:

```bash```lua

# 1. 检查短链数据库-- GeoIP + ISP 分流

docker exec shortlink-mysql-prod mysql -u short_link -p -e "SELECT * FROM short_links WHERE code='ABC123';"if country == "CN" then

  if province == "Beijing" and isp == "telecom" then

# 2. 检查 Redis 缓存    return "cdn1.example.com"

docker exec shortlink-redis-prod redis-cli -a <password> -n 1 GET 'short:ABC123'  elseif province == "Shanghai" and isp == "unicom" then

    return "cdn2.example.com"

# 3. 查看错误日志  end

docker exec shortlink-openresty-prod tail -50 /usr/local/openresty/nginx/logs/error.logend

```

-- 故障转移

### 问题3: 地理路由不生效if is_server_down("cdn1.example.com") then

  return "cdn2.example.com"

**检查步骤**:end

```bash```

# 1. 验证 GeoIP 数据库

docker exec shortlink-openresty-prod ls -lh /usr/local/openresty/nginx/geoip/## API 文档



# 2. 测试地理位置检测### 管理 API

curl https://short.yourdomain.com/health

#### 创建短链（推荐使用方式2：CDN标识 + 路径）

# 3. 检查路由模式配置```http

docker exec shortlink-openresty-prod env | grep CDN_ROUTING_MODEPOST /api/v1/links

```Content-Type: application/json



## 📚 相关文档{

  "short_code": "img-abc123",

- [GEOIP_ROUTING.md](./GEOIP_ROUTING.md) - GeoIP 路由详细说明  "targets": [

- [ROUTING_README.md](./ROUTING_README.md) - 路由系统架构    {

- [部署指南](../DEPLOYMENT_GUIDE.md) - 完整部署文档      "cdn": "north_telecom",

- [生产配置参考](../PRODUCTION_CONFIG.md) - 生产环境配置示例      "path": "/uploads/2024/12/photo.jpg",

      "region": "cn-north",

## 🤝 集成      "isp": "telecom",

      "weight": 5

### 与图床服务集成    },

    {

短链服务与图床服务通过 API 集成：      "cdn": "south_unicom",

      "path": "/uploads/2024/12/photo.jpg",

1. 图床上传图片后调用短链API创建短链      "region": "cn-south",

2. 短链服务验证API Key      "isp": "unicom",

3. 生成短链码并存储到数据库      "weight": 3

4. 返回短链URL给图床服务    },

    {

**配置要求**:      "cdn": "overseas",

- API Key 必须完全一致      "path": "/uploads/2024/12/photo.jpg",

- Redis 数据库必须一致（db 1）      "region": "overseas",

- 网络必须互通      "weight": 2

    }

## 📄 许可证  ],

  "strategy": "geo+weight"

[MIT License](../LICENSE)}

```

---

#### 更新规则（热更新）

**生产案例**: https://short.oxvxo.link```http

PUT /api/v1/links/abc123/rules
Content-Type: application/json

{
  "strategy": "geo+isp",
  "rules": {...}
}
```

#### 查看统计
```http
GET /api/v1/stats/abc123
```

### 重定向 API

```http
GET /r/abc123
# 根据访客信息 302 重定向到最佳服务器
```

## 性能指标

- **QPS**: > 50,000 (单机)
- **延迟**: < 5ms (P99)
- **缓存命中率**: > 95%
- **可用性**: 99.99%

## 与图床集成

### 场景 1: 图片 CDN 加速（使用方式2：CDN标识 + 路径）

```bash
# TC-GO 上传图片后，创建短链
POST /api/v1/links
{
  "short_code": "img_uuid_123",
  "targets": [
    {
      "cdn": "north_telecom",
      "path": "/uploads/2024/12/uuid.jpg",
      "region": "cn-north",
      "isp": "telecom",
      "weight": 5
    },
    {
      "cdn": "south_unicom",
      "path": "/uploads/2024/12/uuid.jpg",
      "region": "cn-south",
      "isp": "unicom",
      "weight": 3
    },
    {
      "cdn": "overseas",
      "path": "/uploads/2024/12/uuid.jpg",
      "region": "overseas",
      "weight": 2
    }
  ],
  "strategy": "geo+weight",
  "security_config": {
    "referer_whitelist": ["*.tc-go.com", "localhost"]
  }
}
    {"url": "https://cdn3.tc-go.com/uploads/uuid.jpg", "region": "overseas"}
  ],
  "strategy": "geo"
}

-- 用户访问
GET /r/img_uuid_123
# 自动重定向到最近的 CDN
```

### 场景 2: 防盗链

```lua
-- 支持 Referer 验证和 Token 签名
{
  "short_code": "protected_img",
  "targets": [...],
  "security": {
    "referer_whitelist": ["tc-go.com"],
    "token_required": true,
    "expire_time": 3600
  }
}
```

## 监控和日志

### 实时监控指标
- 每秒请求数 (QPS)
- 响应时间 (P50/P90/P99)
- 错误率
- 缓存命中率
- 各服务器健康状态

### 日志格式
```json
{
  "timestamp": "2025-12-05T10:00:00Z",
  "short_code": "abc123",
  "client_ip": "1.2.3.4",
  "country": "CN",
  "province": "Beijing",
  "isp": "telecom",
  "target": "cdn1.example.com",
  "response_time": 3,
  "status": 302
}
```

## 高级特性

### 1. 智能预热
自动预热热点内容到边缘节点

### 2. 流量回源
边缘节点缓存未命中时智能回源

### 3. DDoS 防护
基于 IP 频率限制和黑名单

### 4. A/B 测试
支持灰度发布和 A/B 测试

## 贡献指南

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

---

**联系方式**: GitHub Issues
**文档更新**: 2025-12-05
