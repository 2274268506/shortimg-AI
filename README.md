# 🖼️ ShortImg-AI - 智能图床与短链系统

<div align="center">

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Go](https://img.shields.io/badge/Go-1.21+-00ADD8?logo=go)
![Vue](https://img.shields.io/badge/Vue-3.3+-4FC08D?logo=vue.js)
![OpenResty](https://img.shields.io/badge/OpenResty-1.21+-00ADD8?logo=nginx)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)

一个功能强大的图床管理与智能短链系统，支持多CDN分流、地理位置路由、图片格式转换、权限管理等功能。

[功能特性](#-功能特性) • [快速开始](#-快速开始) • [架构设计](#-架构设计) • [文档](#-文档) • [演示](#-演示)

</div>

---

## 📸 项目简介

**ShortImg-AI** 是一个企业级的图床管理与智能短链系统，整合了三大核心服务：

- 🖼️ **图床服务** (Backend) - Go + Gin 构建的高性能图片存储与管理系统
- 🔗 **短链服务** (Redirect Service) - OpenResty + Lua 实现的智能 CDN 分流引擎
- 🎨 **管理界面** (Frontend) - Vue 3 + Element Plus 现代化管理控制台

### 🌟 核心亮点

- ✨ **智能路由** - 基于地理位置、运营商、IP段的多维度 CDN 分流
- 🚀 **高性能** - OpenResty + Redis 缓存，支持百万级短链访问
- 🎯 **灵活配置** - 声明式 YAML 配置，支持热更新，无需重启
- 🔐 **安全可靠** - JWT 认证、权限管理、访问统计、审计日志
- 📊 **可观测性** - Prometheus 监控、AlertManager 告警、实时日志
- 🐳 **容器化** - Docker Compose 一键部署，生产环境就绪

---

## 🎯 功能特性

### 📷 图床服务 (Backend)

<details>
<summary><b>核心功能</b></summary>

- ✅ **图片上传与管理**
  - 支持拖拽上传、批量上传、粘贴上传
  - 实时上传进度、断点续传
  - 图片裁剪、缩放、旋转

- ✅ **格式转换**
  - 支持 JPG、PNG、WebP、AVIF 互转
  - 智能压缩优化
  - 自定义质量参数

- ✅ **存储后端**
  - 本地文件系统
  - 腾讯云 COS
  - 阿里云 OSS（规划中）
  - AWS S3（规划中）

- ✅ **相册管理**
  - 创建相册分组
  - 图片分类标签
  - 批量操作

- ✅ **权限控制**
  - 用户认证（JWT）
  - 角色权限管理
  - 图片访问控制（公开/私有/密码）

- ✅ **统计分析**
  - 访问量统计
  - 存储空间分析
  - 热门图片排行

</details>

### 🔗 短链服务 (Redirect Service)

<details>
<summary><b>核心功能</b></summary>

- ✅ **智能路由引擎**
  - 🌍 **地理位置路由** - 根据省份、城市选择最近 CDN
  - 📡 **运营商路由** - 电信/联通/移动智能分流
  - 🔢 **IP 段路由** - 企业内网/公网自动识别
  - 🎲 **权重路由** - 灰度发布、A/B 测试
  - 🔄 **一致性哈希** - 会话保持、缓存优化
  - 🧩 **组合策略** - 多种策略组合使用

- ✅ **高级特性**
  - ⚡ **热更新配置** - 修改规则自动生效，无需重启
  - 🚀 **高性能缓存** - Redis + 本地缓存双层架构
  - 📊 **实时监控** - Prometheus 指标采集
  - 🔍 **访问日志** - 完整的请求追踪
  - 🛡️ **安全防护** - 频率限制、黑白名单

- ✅ **API 支持**
  - 创建图床短链（单个/批量）
  - 创建通用短链
  - 自定义短链代码
  - 过期时间设置
  - 统计信息查询

</details>

### 🎨 管理界面 (Frontend)

<details>
<summary><b>核心功能</b></summary>

- ✅ **图片管理**
  - 网格/列表视图切换
  - 图片预览与编辑
  - 批量下载/删除
  - 快速搜索过滤

- ✅ **相册管理**
  - 相册创建与编辑
  - 图片拖拽分组
  - 权限设置

- ✅ **短链管理**
  - 短链创建与查看
  - 访问统计图表
  - 批量导入/导出

- ✅ **数据统计**
  - 实时数据看板
  - 图表可视化（ECharts）
  - 存储空间分析
  - 流量统计

- ✅ **用户管理**
  - 用户注册/登录
  - 个人资料编辑
  - 密码修改
  - API 密钥管理

</details>

---

## 🏗️ 架构设计

### 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                         用户访问                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
         ┌────────────┴────────────┐
         │                         │
    图片上传/管理              短链访问
         │                         │
         ▼                         ▼
┌─────────────────┐      ┌──────────────────┐
│  Nginx (HTTPS)  │      │  Nginx (HTTPS)   │
│   Port 443      │      │    Port 443      │
└────────┬────────┘      └────────┬─────────┘
         │                        │
         ▼                        ▼
┌─────────────────┐      ┌──────────────────┐
│   Frontend      │      │  OpenResty       │
│   Vue 3 SPA     │      │  (Lua Engine)    │
└────────┬────────┘      └────────┬─────────┘
         │                        │
         ▼                        │
┌─────────────────┐               │
│   Backend       │◄──────────────┘
│   Go + Gin      │    短链创建 API
└────────┬────────┘
         │
    ┌────┴────┬─────────┬──────────┐
    │         │         │          │
    ▼         ▼         ▼          ▼
┌────────┐┌────────┐┌────────┐┌────────┐
│ MySQL  ││ Redis  ││ 腾讯云 ││ 本地   │
│ 8.0    ││ 7.0    ││  COS   ││ 存储   │
└────────┘└────────┘└────────┘└────────┘
```

### 技术栈

#### 后端 (Backend)

- **语言**: Go 1.21+
- **框架**: Gin Web Framework
- **数据库**: MySQL 8.0
- **缓存**: Redis 7.0
- **存储**: 本地文件系统 / 腾讯云 COS
- **文档**: Swagger/OpenAPI
- **监控**: Prometheus + Grafana

#### 短链服务 (Redirect Service)

- **引擎**: OpenResty (Nginx + LuaJIT)
- **语言**: Lua
- **GeoIP**: MaxMind GeoLite2
- **配置**: YAML (声明式)
- **缓存**: Redis + ngx.shared.DICT

#### 前端 (Frontend)

- **框架**: Vue 3 (Composition API)
- **UI**: Element Plus
- **状态**: Pinia
- **路由**: Vue Router
- **构建**: Vite
- **图表**: ECharts
- **HTTP**: Axios

#### 基础设施

- **容器化**: Docker + Docker Compose
- **监控**: Prometheus + AlertManager
- **日志**: Zap (Go) + Nginx Access Log
- **反向代理**: Nginx

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
