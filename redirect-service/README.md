# 🔗 智能短链重定向服务

## 项目概述

基于 OpenResty + Redis + MySQL + Lua + Nginx 的高性能智能短链重定向服务，支持多种分流策略和故障转移，与 TC-GO 图床系统无缝集成。

## 核心功能

### 1. 多维度分流策略
- **IP 分流** - 根据访客 IP 地址分配服务器
- **GeoIP 分流** - 基于地理位置（国家/省份/城市）
- **ASN 分流** - 根据运营商 ASN 号码
- **设备类型** - PC/Mobile/Tablet 分流
- **时间段** - 根据时间段分配（高峰/低峰）
- **权重轮询** - 带权重的负载均衡
- **哈希一致性** - 同一用户访问同一服务器

### 2. 高可用特性
- **健康检查** - 实时检测服务器状态
- **故障转移** - 自动切换到备用服务器
- **降级策略** - 服务异常时的降级处理
- **熔断机制** - 防止雪崩效应

### 3. 动态管理
- **热更新规则** - 无需重启即可更新分流规则
- **实时监控** - 访问统计、错误率、响应时间
- **管理 API** - RESTful API 管理短链和规则
- **缓存优化** - Redis 多级缓存加速

### 4. 与图床集成
- **图片 CDN 加速** - 智能选择最近的图片服务器
- **防盗链** - 支持 Referer 和 Token 验证
- **流量统计** - 记录图片访问量和来源

## 技术架构

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ↓
┌─────────────────────────────────────┐
│        OpenResty (Nginx)            │
│  ┌───────────────────────────────┐  │
│  │   Lua 分流逻辑                │  │
│  │   - GeoIP 解析                │  │
│  │   - 规则匹配                  │  │
│  │   - 健康检查                  │  │
│  └───────────────────────────────┘  │
└────┬─────────────────────┬──────────┘
     │                     │
     ↓                     ↓
┌─────────┐          ┌──────────┐
│  Redis  │          │  MySQL   │
│  缓存层  │          │  持久化  │
└─────────┘          └──────────┘
     │
     ↓
┌───────────────────────────────────┐
│      Upstream Servers             │
│  ┌──────┐  ┌──────┐  ┌──────┐   │
│  │ CDN1 │  │ CDN2 │  │ CDN3 │   │
│  └──────┘  └──────┘  └──────┘   │
└───────────────────────────────────┘
```

## 快速开始

### 方式一：Docker 部署（推荐）

#### 1. 环境要求
- Docker 20.10+
- Docker Compose 2.0+

#### 2. 配置域名

```bash
# 复制环境变量配置文件
cp .env.example .env

# 编辑配置文件，设置你的域名
nano .env
```

关键配置：
```bash
# 短链服务域名
REDIRECT_DOMAIN=s.yourdomain.com
REDIRECT_PROTOCOL=https

# CDN 服务器域名（根据实际情况配置）
CDN_NORTH_TELECOM_DOMAIN=cdn-bj.yourdomain.com
CDN_SOUTH_UNICOM_DOMAIN=cdn-gz.yourdomain.com
CDN_OVERSEAS_DOMAIN=cdn-us.yourdomain.com

# TC-GO 图床域名
TC_GO_PRIMARY_DOMAIN=img.yourdomain.com

# 数据库密码
MYSQL_PASSWORD=your_strong_password
```

**详细配置指南**: 参考 [CONFIG_GUIDE.md](CONFIG_GUIDE.md)

#### 3. 下载 GeoIP 数据库

```bash
# 创建目录
mkdir -p geoip

# 访问 https://dev.maxmind.com/geoip/geolite2-free-geolocation-data
# 注册并下载以下文件到 geoip/ 目录：
# - GeoLite2-City.mmdb
# - GeoLite2-ASN.mmdb
```

#### 4. 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f openresty

# 验证配置
docker-compose logs openresty | grep "Redirect service"
```

#### 5. 测试

```bash
# 测试短链（需要先创建短链）
curl -I http://localhost/r/test-code
```

**完整示例**: 参考 [QUICKSTART.md](QUICKSTART.md)

### 方式二：手动安装

### 环境要求
- OpenResty >= 1.21.4
- Redis >= 6.0
- MySQL >= 5.7
- Lua >= 5.1

### 安装步骤

1. **安装 OpenResty**
```bash
# Windows (使用 WSL 或 Docker)
docker pull openresty/openresty:alpine

# Linux
wget https://openresty.org/download/openresty-1.21.4.1.tar.gz
tar -xzf openresty-1.21.4.1.tar.gz
cd openresty-1.21.4.1
./configure --with-luajit
make && make install
```

2. **安装依赖模块**
```bash
opm install ledgetech/lua-resty-http
opm install pintsized/lua-resty-redis-connector
opm install spacewander/lua-resty-rsa
opm install doujiang24/lua-resty-kafka
```

3. **配置域名和数据库**
```bash
# 复制并编辑配置文件
cp .env.example .env
nano .env
```
# 导入数据库表结构
mysql -u root -p < sql/schema.sql

# 初始化 Redis
redis-cli < sql/redis_init.lua
```

4. **启动服务**
```bash
# 启动 OpenResty
openresty -p /path/to/redirect-service -c conf/nginx.conf

# 或使用 Docker
docker-compose up -d
```

## 目录结构

```
redirect-service/
├── conf/
│   ├── nginx.conf              # Nginx 主配置
│   ├── upstream.conf           # 上游服务器配置
│   └── geoip.conf             # GeoIP 配置
├── lua/
│   ├── core/
│   │   ├── router.lua         # 路由核心
│   │   ├── balancer.lua       # 负载均衡器
│   │   └── health_checker.lua # 健康检查
│   ├── strategies/
│   │   ├── ip_strategy.lua    # IP 分流策略
│   │   ├── geo_strategy.lua   # GeoIP 分流策略
│   │   ├── asn_strategy.lua   # ASN 分流策略
│   │   └── hash_strategy.lua  # 一致性哈希
│   ├── storage/
│   │   ├── redis_client.lua   # Redis 客户端
│   │   └── mysql_client.lua   # MySQL 客户端
│   ├── utils/
│   │   ├── logger.lua         # 日志工具
│   │   └── metrics.lua        # 监控指标
│   └── api/
│       ├── admin_api.lua      # 管理 API
│       └── stats_api.lua      # 统计 API
├── sql/
│   ├── schema.sql             # 数据库表结构
│   └── redis_init.lua         # Redis 初始化
├── logs/                       # 日志目录
├── docker-compose.yml         # Docker 编排
└── README.md                  # 项目文档
```

## 配置示例

### 1. 短链规则配置

```lua
-- 添加短链
{
  "short_code": "abc123",
  "name": "图床图片",
  "targets": [
    {
      "url": "https://cdn1.example.com/image.jpg",
      "weight": 50,
      "region": "cn-north",
      "isp": "telecom"
    },
    {
      "url": "https://cdn2.example.com/image.jpg",
      "weight": 30,
      "region": "cn-south",
      "isp": "unicom"
    },
    {
      "url": "https://cdn3.example.com/image.jpg",
      "weight": 20,
      "region": "overseas"
    }
  ],
  "strategy": "geo+isp",
  "fallback": "https://backup.example.com/image.jpg"
}
```

### 2. 分流规则示例

```lua
-- GeoIP + ISP 分流
if country == "CN" then
  if province == "Beijing" and isp == "telecom" then
    return "cdn1.example.com"
  elseif province == "Shanghai" and isp == "unicom" then
    return "cdn2.example.com"
  end
end

-- 故障转移
if is_server_down("cdn1.example.com") then
  return "cdn2.example.com"
end
```

## API 文档

### 管理 API

#### 创建短链（推荐使用方式2：CDN标识 + 路径）
```http
POST /api/v1/links
Content-Type: application/json

{
  "short_code": "img-abc123",
  "targets": [
    {
      "cdn": "north_telecom",
      "path": "/uploads/2024/12/photo.jpg",
      "region": "cn-north",
      "isp": "telecom",
      "weight": 5
    },
    {
      "cdn": "south_unicom",
      "path": "/uploads/2024/12/photo.jpg",
      "region": "cn-south",
      "isp": "unicom",
      "weight": 3
    },
    {
      "cdn": "overseas",
      "path": "/uploads/2024/12/photo.jpg",
      "region": "overseas",
      "weight": 2
    }
  ],
  "strategy": "geo+weight"
}
```

#### 更新规则（热更新）
```http
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
