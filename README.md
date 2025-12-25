# ShortImg-AI 图床系统# 🖼️ ShortImg-AI - 智能图床与短链系统



一个功能完整的现代化图床系统，支持图片上传、管理、短链生成和CDN分流。<div align="center">



## ✨ 特性![License](https://img.shields.io/badge/license-MIT-blue.svg)

![Go](https://img.shields.io/badge/Go-1.21+-00ADD8?logo=go)

- 🖼️ **图片管理**: 支持多格式图片上传、相册管理、缩略图生成![Vue](https://img.shields.io/badge/Vue-3.3+-4FC08D?logo=vue.js)

- 🔗 **短链服务**: 自动生成短链接，支持地域路由和CDN分流![OpenResty](https://img.shields.io/badge/OpenResty-1.21+-00ADD8?logo=nginx)

- 👥 **用户系统**: 多用户支持、权限管理、JWT认证![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)

- 📊 **统计功能**: 访问统计、存储统计、实时监控

- 🎨 **标签系统**: 图片标签分类、批量管理一个功能强大的图床管理与智能短链系统，支持多CDN分流、地理位置路由、图片格式转换、权限管理等功能。

- 🚀 **高性能**: Redis缓存、数据库优化、静态资源CDN

- 🔐 **安全可靠**: API密钥认证、HTTPS加密、数据备份[功能特性](#-功能特性) • [快速开始](#-快速开始) • [架构设计](#-架构设计) • [文档](#-文档) • [演示](#-演示)



## 🏗️ 技术栈</div>



### 图床服务---

- **前端**: Vue 3 + TypeScript + Vite + Element Plus

- **后端**: Go + Gin + GORM + MySQL + Redis## 📸 项目简介

- **部署**: Docker + Docker Compose + Nginx

**ShortImg-AI** 是一个企业级的图床管理与智能短链系统，整合了三大核心服务：

### 短链服务

- **前端/后端**: OpenResty + Lua + Redis + MySQL- 🖼️ **图床服务** (Backend) - Go + Gin 构建的高性能图片存储与管理系统

- **功能**: 短链生成、地理路由、CDN分流、访问统计- 🔗 **短链服务** (Redirect Service) - OpenResty + Lua 实现的智能 CDN 分流引擎

- 🎨 **管理界面** (Frontend) - Vue 3 + Element Plus 现代化管理控制台

## 📁 项目结构

### 🌟 核心亮点

```

shortimg-AI/- ✨ **智能路由** - 基于地理位置、运营商、IP段的多维度 CDN 分流

├── backend/              # 后端服务- 🚀 **高性能** - OpenResty + Redis 缓存，支持百万级短链访问

│   ├── controllers/      # 控制器- 🎯 **灵活配置** - 声明式 YAML 配置，支持热更新，无需重启

│   ├── models/          # 数据模型- 🔐 **安全可靠** - JWT 认证、权限管理、访问统计、审计日志

│   ├── routes/          # 路由- 📊 **可观测性** - Prometheus 监控、AlertManager 告警、实时日志

│   ├── middleware/      # 中间件- 🐳 **容器化** - Docker Compose 一键部署，生产环境就绪

│   ├── storage/         # 存储层

│   ├── docker-compose.prod.yml  # 生产环境配置---

│   └── .env.production  # 环境变量模板

├── frontend/            # 前端服务## 🎯 功能特性

│   ├── src/

│   │   ├── views/       # 页面组件### 📷 图床服务 (Backend)

│   │   ├── components/  # 通用组件

│   │   ├── utils/       # 工具函数<details>

│   │   └── router/      # 路由配置<summary><b>核心功能</b></summary>

│   └── vite.config.ts   # Vite 配置

├── redirect-service/    # 短链服务- ✅ **图片上传与管理**

│   ├── lua/             # Lua 脚本  - 支持拖拽上传、批量上传、粘贴上传

│   ├── conf/            # OpenResty 配置  - 实时上传进度、断点续传

│   ├── sql/             # 数据库脚本  - 图片裁剪、缩放、旋转

│   └── docker-compose.prod.yml

├── docs/                # 文档- ✅ **格式转换**

│   ├── IMAGE_PROCESSING.md     # 图片处理说明  - 支持 JPG、PNG、WebP、AVIF 互转

│   ├── USER_MANAGEMENT.md      # 用户管理说明  - 智能压缩优化

│   ├── 统计功能说明.md         # 统计功能文档  - 自定义质量参数

│   ├── 标签功能实现.md         # 标签功能文档

│   ├── 图片格式转换功能说明.md # 格式转换文档- ✅ **存储后端**

│   ├── 性能优化与监控.md       # 性能优化指南  - 本地文件系统

│   └── 系统日志功能说明.md     # 日志功能说明  - 腾讯云 COS

├── DEPLOYMENT_GUIDE.md  # 部署指南  - 阿里云 OSS（规划中）

└── README.md           # 本文件  - AWS S3（规划中）

```

- ✅ **相册管理**

## 🚀 快速开始  - 创建相册分组

  - 图片分类标签

### 开发环境  - 批量操作



#### 前置要求- ✅ **权限控制**

- Go 1.21+  - 用户认证（JWT）

- Node.js 18+  - 角色权限管理

- MySQL 8.0+  - 图片访问控制（公开/私有/密码）

- Redis 7+

- Docker & Docker Compose- ✅ **统计分析**

  - 访问量统计

#### 后端启动  - 存储空间分析

  - 热门图片排行

```bash

cd backend</details>

cp .env.example .env  # 配置环境变量

go mod download### 🔗 短链服务 (Redirect Service)

go run main.go

```<details>

<summary><b>核心功能</b></summary>

#### 前端启动

- ✅ **智能路由引擎**

```bash  - 🌍 **地理位置路由** - 根据省份、城市选择最近 CDN

cd frontend  - 📡 **运营商路由** - 电信/联通/移动智能分流

npm install  - 🔢 **IP 段路由** - 企业内网/公网自动识别

npm run dev  - 🎲 **权重路由** - 灰度发布、A/B 测试

```  - 🔄 **一致性哈希** - 会话保持、缓存优化

  - 🧩 **组合策略** - 多种策略组合使用

### 生产部署

- ✅ **高级特性**

详细部署文档请参考：[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)  - ⚡ **热更新配置** - 修改规则自动生效，无需重启

  - 🚀 **高性能缓存** - Redis + 本地缓存双层架构

#### 快速部署（图床服务）  - 📊 **实时监控** - Prometheus 指标采集

  - 🔍 **访问日志** - 完整的请求追踪

```bash  - 🛡️ **安全防护** - 频率限制、黑白名单

# 1. 克隆项目

git clone <repository-url>- ✅ **API 支持**

cd shortimg-AI/backend  - 创建图床短链（单个/批量）

  - 创建通用短链

# 2. 配置环境变量  - 自定义短链代码

cp .env.production .env  - 过期时间设置

nano .env  # 编辑配置  - 统计信息查询



# 3. 启动服务</details>

docker-compose -f docker-compose.prod.yml up -d

### 🎨 管理界面 (Frontend)

# 4. 检查状态

docker-compose -f docker-compose.prod.yml ps<details>

docker-compose -f docker-compose.prod.yml logs -f backend<summary><b>核心功能</b></summary>

```

- ✅ **图片管理**

#### 快速部署（短链服务）  - 网格/列表视图切换

  - 图片预览与编辑

```bash  - 批量下载/删除

cd redirect-service  - 快速搜索过滤



# 1. 配置环境变量- ✅ **相册管理**

nano .env  # 配置 API Key、域名等  - 相册创建与编辑

  - 图片拖拽分组

# 2. 启动服务  - 权限设置

docker-compose -f docker-compose.prod.yml up -d

- ✅ **短链管理**

# 3. 验证  - 短链创建与查看

curl https://short.yourdomain.com/health  - 访问统计图表

```  - 批量导入/导出



## 📖 文档- ✅ **数据统计**

  - 实时数据看板

- [部署指南](./DEPLOYMENT_GUIDE.md) - 生产环境部署完整指南  - 图表可视化（ECharts）

- [图片处理](./docs/IMAGE_PROCESSING.md) - 图片上传、压缩、格式转换  - 存储空间分析

- [用户管理](./docs/USER_MANAGEMENT.md) - 用户系统和权限管理  - 流量统计

- [统计功能](./docs/统计功能说明.md) - 访问统计和数据分析

- [标签系统](./docs/标签功能实现.md) - 图片标签分类管理- ✅ **用户管理**

- [性能优化](./docs/性能优化与监控.md) - 系统性能优化指南  - 用户注册/登录

- [格式转换](./docs/图片格式转换功能说明.md) - 图片格式转换功能  - 个人资料编辑

- [系统日志](./docs/系统日志功能说明.md) - 日志查看和管理  - 密码修改

  - API 密钥管理

## 🔧 配置说明

</details>

### 关键配置项

---

#### 图床服务 (backend/.env)

## 🏗️ 架构设计

```bash

# 数据库### 系统架构图

MYSQL_PASSWORD=your_secure_password

MYSQL_DATABASE=imagebed```

┌─────────────────────────────────────────────────────────────┐

# JWT 密钥│                         用户访问                             │

JWT_SECRET=your_jwt_secret_minimum_32_characters└─────────────────────┬───────────────────────────────────────┘

                      │

# 短链服务         ┌────────────┴────────────┐

SHORT_LINK_API_KEY=your_api_key_minimum_60_characters         │                         │

SHORT_LINK_BASE_URL=https://short.yourdomain.com    图片上传/管理              短链访问

SHORT_LINK_PUBLIC_URL=https://short.yourdomain.com         │                         │

         ▼                         ▼

# 后端公开地址┌─────────────────┐      ┌──────────────────┐

BACKEND_PUBLIC_URL=https://img.yourdomain.com│  Nginx (HTTPS)  │      │  Nginx (HTTPS)   │

```│   Port 443      │      │    Port 443      │

└────────┬────────┘      └────────┬─────────┘

#### 短链服务 (redirect-service/.env)         │                        │

         ▼                        ▼

```bash┌─────────────────┐      ┌──────────────────┐

# Redis 配置│   Frontend      │      │  OpenResty       │

REDIS_PASSWORD=your_redis_password│   Vue 3 SPA     │      │  (Lua Engine)    │

REDIS_DB=1└────────┬────────┘      └────────┬─────────┘

         │                        │

# API 密钥（必须与图床服务一致）         ▼                        │

DASHBOARD_API_KEY=your_api_key_minimum_60_characters┌─────────────────┐               │

API_KEY=your_api_key_minimum_60_characters│   Backend       │◄──────────────┘

│   Go + Gin      │    短链创建 API

# 域名配置└────────┬────────┘

REDIRECT_DOMAIN=short.yourdomain.com         │

TC_GO_PRIMARY_DOMAIN=img.yourdomain.com    ┌────┴────┬─────────┬──────────┐

```    │         │         │          │

    ▼         ▼         ▼          ▼

## 🔒 安全┌────────┐┌────────┐┌────────┐┌────────┐

│ MySQL  ││ Redis  ││ 腾讯云 ││ 本地   │

- ✅ JWT Token 认证│ 8.0    ││ 7.0    ││  COS   ││ 存储   │

- ✅ API Key 验证└────────┘└────────┘└────────┘└────────┘

- ✅ HTTPS 加密传输```

- ✅ SQL 注入防护

- ✅ XSS 防护### 技术栈

- ✅ CORS 跨域控制

- ✅ 文件类型验证#### 后端 (Backend)

- ✅ 文件大小限制

- **语言**: Go 1.21+

## 📊 系统要求- **框架**: Gin Web Framework

- **数据库**: MySQL 8.0

### 最低配置- **缓存**: Redis 7.0

- CPU: 2核- **存储**: 本地文件系统 / 腾讯云 COS

- 内存: 4GB- **文档**: Swagger/OpenAPI

- 磁盘: 50GB- **监控**: Prometheus + Grafana

- 带宽: 10Mbps

#### 短链服务 (Redirect Service)

### 推荐配置

- CPU: 4核+- **引擎**: OpenResty (Nginx + LuaJIT)

- 内存: 8GB+- **语言**: Lua

- 磁盘: 100GB+ (SSD)- **GeoIP**: MaxMind GeoLite2

- 带宽: 100Mbps+- **配置**: YAML (声明式)

- **缓存**: Redis + ngx.shared.DICT

## 🤝 贡献

#### 前端 (Frontend)

欢迎提交 Issue 和 Pull Request！

- **框架**: Vue 3 (Composition API)

## 📄 许可证- **UI**: Element Plus

- **状态**: Pinia

[MIT License](LICENSE)- **路由**: Vue Router

- **构建**: Vite

## 🙏 致谢- **图表**: ECharts

- **HTTP**: Axios

感谢所有开源项目的贡献者！

#### 基础设施

---

- **容器化**: Docker + Docker Compose

**部署成功案例：**- **监控**: Prometheus + AlertManager

- 图床服务: https://img.oxvxo.link- **日志**: Zap (Go) + Nginx Access Log

- 短链服务: https://short.oxvxo.link- **反向代理**: Nginx


---

## 🚀 快速开始

### 环境要求

- Docker 20.10+
- Docker Compose 2.0+
- 至少 2GB 可用内存
- 端口 80、443、8080、8081、3306、6379 未被占用

### 一键部署（不支持）

```bash
# 1. 克隆项目
git clone https://github.com/yourusername/shortimg-ai.git
cd shortimg-ai

# 2. 复制环境变量配置
cp .env.example .env

# 3. 编辑配置（可选）
nano .env

# 4. 启动所有服务
docker-compose up -d

# 5. 查看服务状态
docker-compose ps
```

### 访问服务

| 服务 | 地址 | 默认凭据 |
|------|------|----------|
| 管理界面 | http://localhost | admin / admin123 |
| 图床 API | http://localhost:8080/api | - |
| 短链服务 | http://localhost:8081 | - |
| Swagger 文档 | http://localhost:8080/swagger/index.html | - |
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3000 | admin / admin |

### 配置说明

<details>
<summary><b>环境变量配置</b></summary>

编辑 `.env` 文件：

```bash
# ========== 基础配置 ==========
# 域名配置
REDIRECT_DOMAIN=short.example.com
BACKEND_DOMAIN=api.example.com

# ========== 数据库配置 ==========
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_DATABASE=shortimg_db
MYSQL_USER=shortimg
MYSQL_PASSWORD=your_db_password

# ========== Redis 配置 ==========
REDIS_PASSWORD=your_redis_password

# ========== CDN 配置 ==========
# 国内通用 CDN
CDN_CHINA_DOMAIN=img.example.com
CDN_CHINA_PROTOCOL=https

# 电信 CDN
CDN_TELECOM_DOMAIN=cdn-telecom.example.com
CDN_TELECOM_PROTOCOL=https

# 联通 CDN
CDN_UNICOM_DOMAIN=cdn-unicom.example.com
CDN_UNICOM_PROTOCOL=https

# 移动 CDN
CDN_MOBILE_DOMAIN=cdn-mobile.example.com
CDN_MOBILE_PROTOCOL=https

# 海外 CDN
CDN_OVERSEAS_DOMAIN=cdn-global.example.com
CDN_OVERSEAS_PROTOCOL=https

# ========== 存储配置 ==========
# 腾讯云 COS
TENCENT_SECRET_ID=your_secret_id
TENCENT_SECRET_KEY=your_secret_key
TENCENT_BUCKET=your-bucket-name
TENCENT_REGION=ap-guangzhou

# ========== JWT 配置 ==========
JWT_SECRET=your_jwt_secret_key_change_in_production
```

</details>

<details>
<summary><b>CDN 分流配置</b></summary>

编辑 `redirect-service/routing_rules.yaml`：

```yaml
cdn_nodes:
  - id: telecom
    name: 电信CDN
    domain_env: CDN_TELECOM_DOMAIN
    default_domain: cdn-telecom.example.com
    default_protocol: https

routing_rules:
  - priority: 10
    name: 电信用户分流
    conditions:
      - type: isp
        isps: ["China Telecom", "电信"]
    targets:
      - cdn_id: telecom
        weight: 100

default_routing:
  targets:
    - cdn_id: china
      weight: 80
    - cdn_id: backup
      weight: 20
```

</details>

---

## 📖 文档

### 用户文档

- [快速入门指南](docs/QUICKSTART.md)
- [API 接口文档](docs/API.md)
- [配置说明](docs/CONFIGURATION.md)
- [部署指南](docs/DEPLOYMENT.md)

### 开发文档

- [架构设计](docs/ARCHITECTURE.md)
- [高级路由配置](redirect-service/ADVANCED_ROUTING_GUIDE.md)
- [CDN 配置指南](redirect-service/ROUTING_CONFIG_GUIDE.md)
- [监控告警配置](MONITORING_INTEGRATION.md)

### API 文档

- Swagger UI: http://localhost:8080/swagger/index.html
- [V2 API 文档](redirect-service/V2_API_GUIDE.md)

---

## 🎬 演示

### 图片上传

![图片上传演示](docs/images/upload-demo.gif)

### 短链创建与访问

```bash
# 创建图床短链（启用智能路由）
curl -X POST http://localhost:8081/api/v2/imagebed/create \
  -H "Content-Type: application/json" \
  -d '{
    "image_path": "/uploads/2024/photo.jpg",
    "enable_geo_routing": true
  }'

# 响应
{
  "success": true,
  "data": {
    "code": "img-abc123def456",
    "short_url": "http://localhost:8081/img-abc123def456",
    "strategy": "geo+weight",
    "targets_count": 5
  }
}

# 访问短链（自动分流到最优 CDN）
curl -L http://localhost:8081/img-abc123def456
# → 302 重定向到 https://cdn-telecom.example.com/uploads/2024/photo.jpg
```

### 批量创建

```bash
curl -X POST http://localhost:8081/api/v2/imagebed/batch \
  -H "Content-Type: application/json" \
  -d '{
    "enable_geo_routing": true,
    "images": [
      {"image_path": "/uploads/2024/photo1.jpg"},
      {"image_path": "/uploads/2024/photo2.jpg"},
      {"image_path": "/uploads/2024/photo3.jpg"}
    ]
  }'
```

---

## 🔧 高级配置

### 多 CDN 智能分流

系统支持多种路由策略组合：

```yaml
# 电信用户 → 电信 CDN
# 联通用户 → 联通 CDN
# 移动用户 → 移动 CDN
# 海外用户 → 海外 CDN
# 其他用户 → 国内通用 CDN + 备用 CDN（权重分配）
```

### Prometheus 监控

内置监控指标：

- `shortlink_redirect_total` - 重定向总数
- `shortlink_redirect_duration_seconds` - 重定向延迟
- `shortlink_cache_hit_rate` - 缓存命中率
- `shortlink_cdn_hits` - 各 CDN 命中次数
- `shortlink_strategy_usage` - 策略使用统计

### 告警规则

预配置告警：

- 服务宕机告警
- 重定向失败率过高
- 缓存命中率过低
- MySQL/Redis 连接失败
- 请求流量激增

---

## 🧪 测试

### 运行测试

```bash
# 后端单元测试
cd backend
go test ./...

# 短链服务测试
cd redirect-service
./test-quick.ps1

# 前端测试
cd frontend
npm run test
```

### 性能测试

```bash
# 使用 wrk 进行压力测试
wrk -t4 -c100 -d30s http://localhost:8081/test-code

# 预期性能：
# - QPS: 10,000+
# - 延迟: P99 < 50ms
# - 缓存命中率: > 95%
```

---

## 📊 监控与运维

### 查看日志

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务
docker-compose logs -f shortlink-openresty

# 查看最近 100 行
docker-compose logs --tail=100 backend
```

### 备份与恢复

```bash
# 备份数据库
docker exec shortlink-mysql-1 mysqldump -u root -p shortimg_db > backup.sql

# 恢复数据库
docker exec -i shortlink-mysql-1 mysql -u root -p shortimg_db < backup.sql

# 备份 Redis
docker exec shortlink-redis-1 redis-cli SAVE
```

---

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

### 代码规范

- Go: `gofmt` + `golangci-lint`
- Lua: LuaCheck
- Vue: ESLint + Prettier

---

## 📝 更新日志

### v2.0.0 (2024-12-08)

- ✨ 新增智能路由引擎（支持地理位置、运营商、IP段分流）
- ✨ 配置统一到 YAML（支持热更新）
- 🚀 性能优化（Redis 缓存、连接池优化）
- 📊 新增 Prometheus 监控和告警
- 🐛 修复已知问题

### v1.0.0 (2024-11-01)

- 🎉 首次发布
- ✅ 图床基础功能
- ✅ 短链基础功能
- ✅ 管理界面

[查看完整更新日志](CHANGELOG.md)

---

## 📄 许可证

本项目采用 [MIT License](LICENSE) 许可证。

---

## 👥 联系方式

- 作者:
- 邮箱: support@example.com
- 项目主页: https://github.com/yourusername/shortimg-ai
- 问题反馈: https://github.com/yourusername/shortimg-ai/issues

---

## 🙏 致谢

感谢以下开源项目：

- [OpenResty](https://openresty.org/)
- [Gin](https://gin-gonic.com/)
- [Vue.js](https://vuejs.org/)
- [Element Plus](https://element-plus.org/)
- [Prometheus](https://prometheus.io/)

---

<div align="center">

**如果觉得有帮助，请给个 ⭐ Star！**

Made with ❤️ by

</div>
