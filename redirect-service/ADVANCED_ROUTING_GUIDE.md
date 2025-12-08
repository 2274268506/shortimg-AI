# 🔄 高级路由引擎使用指南

## 📋 架构变更说明

### ✅ **新架构（统一使用高级路由）**

所有短链的 `targets` 必须包含完整的 `url` 字段，路由策略统一由高级路由引擎处理。

```
短链数据（MySQL）
    ↓
targets: [
  { url: "https://cdn1.example.com/image.jpg", region: "cn-north", isp: "telecom" },
  { url: "https://cdn2.example.com/image.jpg", region: "cn-south", isp: "unicom" }
]
    ↓
高级路由引擎（strategies/）
    ↓
根据策略选择最优 target
    ↓
返回 target.url 进行重定向
```

### ❌ **旧架构（已移除）**

- ~~方式2: `cdn + path`~~ - 已移除
- ~~方式3: 仅 `path`~~ - 已移除
- ~~`config.select_cdn_by_geo()`~~ - 不再在路由时调用

---

## 🚀 创建短链的新方式

### 方法1：使用 CDN 构建器（推荐）

在创建短链时，使用 `cdn_builder` 工具生成完整的 URL。

```lua
local cdn_builder = require "utils.cdn_builder"

-- 为图片生成多CDN配置
local image_path = "/uploads/2024/photo.jpg"
local link_config = cdn_builder.build_image_targets(image_path, true)

-- link_config 包含：
-- {
--   targets = [
--     { url = "https://cdn-north.example.com/uploads/2024/photo.jpg", region = "cn-north", isp = "telecom", weight = 100 },
--     { url = "https://cdn-south.example.com/uploads/2024/photo.jpg", region = "cn-south", isp = "unicom", weight = 100 },
--     { url = "https://cdn-overseas.example.com/uploads/2024/photo.jpg", region = "overseas", weight = 100 },
--     { url = "https://img.oxvxo.link/uploads/2024/photo.jpg", weight = 50 }
--   ],
--   strategy = "geo+weight",
--   fallback_url = "https://fallback.example.com/uploads/2024/photo.jpg"
-- }
```

### 方法2：使用新的 API（推荐）

使用 `imagebed_v2.lua` API 创建短链。

#### 创建图床短链（启用 GeoIP 路由）

```bash
curl -X POST http://localhost:8081/api/v2/imagebed/create \
  -H "Content-Type: application/json" \
  -d '{
    "image_path": "/uploads/2024/photo.jpg",
    "enable_geo_routing": true,
    "expire_time": 86400
  }'
```

**响应：**
```json
{
  "success": true,
  "data": {
    "code": "img-abc123def456",
    "short_url": "https://short.oxvxo.link/img-abc123def456",
    "image_path": "/uploads/2024/photo.jpg",
    "strategy": "geo+weight",
    "geo_routing_enabled": true,
    "targets_count": 4,
    "expire_at": 1733702400,
    "created_at": 1733616000
  }
}
```

#### 创建图床短链（简单模式）

```bash
curl -X POST http://localhost:8081/api/v2/imagebed/create \
  -H "Content-Type: application/json" \
  -d '{
    "image_path": "/uploads/2024/photo.jpg",
    "enable_geo_routing": false
  }'
```

**响应：**
```json
{
  "success": true,
  "data": {
    "code": "img-xyz789uvw012",
    "short_url": "https://short.oxvxo.link/img-xyz789uvw012",
    "image_path": "/uploads/2024/photo.jpg",
    "strategy": "weight",
    "geo_routing_enabled": false,
    "targets_count": 1,
    "created_at": 1733616000
  }
}
```

#### 批量创建

```bash
curl -X POST http://localhost:8081/api/v2/imagebed/batch \
  -H "Content-Type: application/json" \
  -d '{
    "enable_geo_routing": true,
    "images": [
      {"image_path": "/uploads/2024/photo1.jpg"},
      {"image_path": "/uploads/2024/photo2.jpg"},
      {"image_path": "/uploads/2024/photo3.jpg", "custom_code": "my-photo"}
    ]
  }'
```

#### 创建通用短链

```bash
curl -X POST http://localhost:8081/api/v2/generic/create \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.example.com/page",
    "custom_code": "example",
    "expire_time": 604800
  }'
```

---

## 📊 数据库结构

### `short_links` 表

```sql
{
  "short_code": "img-abc123",
  "targets": '[
    {
      "url": "https://cdn-north.example.com/uploads/photo.jpg",
      "region": "cn-north",
      "isp": "telecom",
      "weight": 100
    },
    {
      "url": "https://cdn-south.example.com/uploads/photo.jpg",
      "region": "cn-south",
      "isp": "unicom",
      "weight": 100
    },
    {
      "url": "https://img.oxvxo.link/uploads/photo.jpg",
      "weight": 50
    }
  ]',
  "strategy": "geo+weight",
  "fallback_url": "https://fallback.example.com/uploads/photo.jpg",
  "service_type": "imagebed"
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `targets` | JSON Array | 目标列表，每个target必须包含`url`字段 |
| `strategy` | String | 路由策略：`geo`, `ip`, `asn`, `hash`, `weight`, `geo+weight`等 |
| `fallback_url` | String | 降级URL（所有target都不可用时使用） |

---

## 🎯 路由策略详解

### 1️⃣ **地理位置路由（geo）**

根据用户的地理位置（省份、城市）选择最近的 CDN。

```json
{
  "targets": [
    {
      "url": "https://cdn-beijing.example.com/image.jpg",
      "region": "cn-north"
    },
    {
      "url": "https://cdn-guangzhou.example.com/image.jpg",
      "region": "cn-south"
    }
  ],
  "strategy": "geo"
}
```

**匹配规则：**
- 北京、天津、河北等 → `region: "cn-north"`
- 广东、广西、海南等 → `region: "cn-south"`
- 海外 → `region: "overseas"`

### 2️⃣ **运营商路由（geo + ISP）**

根据用户的地理位置和运营商选择CDN。

```json
{
  "targets": [
    {
      "url": "https://cdn-north-telecom.example.com/image.jpg",
      "region": "cn-north",
      "isp": "telecom"
    },
    {
      "url": "https://cdn-south-unicom.example.com/image.jpg",
      "region": "cn-south",
      "isp": "unicom"
    }
  ],
  "strategy": "geo"
}
```

**ISP 识别：**
- `China Telecom` → `telecom`
- `China Unicom` → `unicom`
- `China Mobile` → `mobile`

### 3️⃣ **IP 段路由（ip）**

根据客户端 IP 段选择目标（适用于企业内网）。

```json
{
  "targets": [
    {
      "url": "https://internal.example.com/file.pdf",
      "ip_ranges": ["10.0.0.0/8", "192.168.0.0/16"]
    },
    {
      "url": "https://public.example.com/file.pdf"
    }
  ],
  "strategy": "ip"
}
```

### 4️⃣ **权重路由（weight）**

根据权重分配流量（A/B 测试、灰度发布）。

```json
{
  "targets": [
    {
      "url": "https://cdn-new.example.com/image.jpg",
      "weight": 20
    },
    {
      "url": "https://cdn-old.example.com/image.jpg",
      "weight": 80
    }
  ],
  "strategy": "weight"
}
```

**流量分配：**
- 20% → cdn-new
- 80% → cdn-old

### 5️⃣ **哈希路由（hash）**

根据客户端 IP 或其他标识进行一致性哈希（会话保持）。

```json
{
  "targets": [
    {"url": "https://cdn1.example.com/image.jpg"},
    {"url": "https://cdn2.example.com/image.jpg"},
    {"url": "https://cdn3.example.com/image.jpg"}
  ],
  "strategy": "hash"
}
```

### 6️⃣ **组合策略（geo+weight）**

先按地理位置过滤，再按权重选择。

```json
{
  "targets": [
    {
      "url": "https://cdn-north-1.example.com/image.jpg",
      "region": "cn-north",
      "weight": 60
    },
    {
      "url": "https://cdn-north-2.example.com/image.jpg",
      "region": "cn-north",
      "weight": 40
    },
    {
      "url": "https://cdn-default.example.com/image.jpg",
      "weight": 100
    }
  ],
  "strategy": "geo+weight"
}
```

**流程：**
1. 北京用户 → 过滤出 `region: "cn-north"` 的 targets
2. 60% → cdn-north-1，40% → cdn-north-2
3. 上海用户（不匹配任何region）→ cdn-default

---

## 🔧 CDN 构建器 API

### `cdn_builder.build_url(cdn_name, path)`

生成单个 CDN 的完整 URL。

```lua
local url = cdn_builder.build_url("tc_go_primary", "/uploads/photo.jpg")
-- 返回: "https://img.oxvxo.link/uploads/photo.jpg"
```

### `cdn_builder.build_targets(path, options)`

为多个 CDN 生成 targets 数组。

```lua
local targets = cdn_builder.build_targets("/uploads/photo.jpg", {
    cdns = {"north_telecom", "south_unicom", "tc_go_primary"},
    attributes = {
        north_telecom = {region = "cn-north", isp = "telecom", weight = 100},
        south_unicom = {region = "cn-south", isp = "unicom", weight = 100},
        tc_go_primary = {weight = 50}
    }
})
```

### `cdn_builder.build_image_targets(path, enable_geo_routing)`

为图床服务生成标准配置（推荐）。

```lua
-- 启用 GeoIP 路由
local config = cdn_builder.build_image_targets("/uploads/photo.jpg", true)
-- 返回包含 4 个 CDN 的配置 + geo+weight 策略

-- 禁用 GeoIP 路由
local config = cdn_builder.build_image_targets("/uploads/photo.jpg", false)
-- 返回仅包含主图床的配置 + weight 策略
```

### `cdn_builder.build_generic_target(url)`

为通用短链生成配置。

```lua
local config = cdn_builder.build_generic_target("https://www.example.com")
-- 返回: {targets = [{url = "https://www.example.com"}], strategy = "weight"}
```

---

## 📝 配置 `config.lua` 的 CDN 列表

```lua
-- config.lua
_M.cdn_servers = {
    private = {
        domain = "localhost",
        protocol = "http",
        port = nil
    },
    public = {
        domain = "img.oxvxo.link",
        protocol = "https",
        port = nil
    },
    north_telecom = {
        domain = "cdn-north.example.com",
        protocol = "https"
    },
    south_unicom = {
        domain = "cdn-south.example.com",
        protocol = "https"
    },
    overseas = {
        domain = "cdn-overseas.example.com",
        protocol = "https"
    },
    tc_go_primary = {
        domain = "img.oxvxo.link",
        protocol = "https"
    },
    fallback = {
        domain = "img.oxvxo.link",
        protocol = "https"
    }
}
```

---

## 🔍 调试和监控

### 查看路由日志

```bash
# 查看 OpenResty 日志
docker logs shortlink-openresty-prod

# 日志示例
[INFO] Using routing strategy: geo+weight
[INFO] GeoIP: IP=123.45.67.89, Country=CN, Province=北京, ISP=China Telecom
[INFO] Selected target: https://cdn-north.example.com/uploads/photo.jpg
```

### Prometheus 监控指标

```promql
# 各策略的使用次数
shortlink_strategy_usage{strategy="geo"}
shortlink_strategy_usage{strategy="weight"}
shortlink_strategy_usage{strategy="geo+weight"}

# 各 CDN 的命中次数
shortlink_cdn_hits{cdn="north_telecom"}
shortlink_cdn_hits{cdn="south_unicom"}
```

---

## ✅ 迁移指南

### 从旧版本迁移

如果你有使用旧的 `path` 模式的短链：

```json
// 旧版本
{
  "targets": [{"path": "/uploads/photo.jpg"}],
  "strategy": "weight"
}
```

需要更新为：

```json
// 新版本
{
  "targets": [{"url": "https://img.oxvxo.link/uploads/photo.jpg"}],
  "strategy": "weight"
}
```

**迁移脚本：**

```sql
-- 查找所有使用 path 模式的短链
SELECT short_code, targets FROM short_links 
WHERE targets LIKE '%"path":%';

-- 手动或通过脚本将 path 转换为完整 URL
```

---

## 🎉 总结

### ✅ **新架构优势**

1. **统一路由逻辑** - 所有路由由高级引擎处理
2. **更强大的分流能力** - 支持地理位置、ISP、IP段、权重等多种策略
3. **更灵活的组合** - 支持策略组合（geo+weight、ip+asn等）
4. **更易维护** - 创建时生成完整URL，路由时只需选择
5. **更好的性能** - 避免在每次请求时调用 `config.select_cdn_by_geo()`

### 📚 **参考文档**

- 策略管理器：`lua/strategies/strategy_manager.lua`
- 地理位置策略：`lua/strategies/geo_strategy.lua`
- IP段策略：`lua/strategies/ip_strategy.lua`
- 权重策略：`lua/strategies/weight_strategy.lua`
- CDN构建器：`lua/utils/cdn_builder.lua`
- V2 API：`lua/api/imagebed_v2.lua`
