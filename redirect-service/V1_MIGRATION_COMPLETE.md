# ✅ V1 API 迁移完成报告

## 📋 迁移内容总结

### 已完成的工作

#### 1️⃣ **更新 `imagebed.lua` (V1 API)**

已将 V1 API 完全迁移到新的路由架构，使用 `cdn_builder` 工具。

**主要改动：**

```lua
-- 新增依赖
local cdn_builder = require "utils.cdn_builder"

-- create() 函数改动
- 旧: targets = cjson.encode({{path = image_path, weight = 100}})
+ 新: local link_config = cdn_builder.build_image_targets(image_path, enable_geo_routing)
      targets_json = cjson.encode(link_config.targets)
      strategy = link_config.strategy
      fallback_url = link_config.fallback_url

-- 支持新参数
- enable_geo_routing: true/false（默认true）
  * true: 生成 4 个 CDN targets，strategy="geo+weight"
  * false: 生成 1 个 target，strategy="weight"

-- 数据库改动
+ 新增 fallback_url 字段（GeoIP 模式）
+ strategy 字段现在动态设置（"geo+weight" 或 "weight"）
```

**响应格式增强：**

```json
{
  "success": true,
  "data": {
    "code": "img-abc123def456",
    "short_url": "https://short.oxvxo.link/img-abc123def456",
    "long_url": "/uploads/2024/photo.jpg",
    "strategy": "geo+weight",              // 新增
    "geo_routing_enabled": true,           // 新增
    "targets_count": 4,                    // 新增
    "expire_at": null,
    "created_at": 1733616000
  }
}
```

#### 2️⃣ **创建测试脚本**

创建了 `test-new-routing.ps1`，包含以下测试用例：

**V1 API 测试：**
- ✅ 创建图床短链 - 默认启用 GeoIP（4个CDN，geo+weight策略）
- ✅ 创建图床短链 - 禁用 GeoIP（1个CDN，weight策略）
- ✅ 创建通用短链（完整URL）
- ✅ 批量创建 - 启用 GeoIP

**V2 API 测试：**
- ✅ 创建图床短链 - 启用 GeoIP
- ✅ 创建图床短链 - 禁用 GeoIP
- ✅ 批量创建
- ✅ 创建通用短链

**路由功能测试：**
- ✅ 访问 GeoIP 路由短链（模拟北京电信用户）
- ✅ 访问简单路由短链
- ✅ 查询短链信息

## 📊 新旧架构对比

### 旧架构（已移除）

```json
// 请求
{
  "image_path": "/uploads/photo.jpg"
}

// 数据库存储
{
  "targets": [{"path": "/uploads/photo.jpg", "weight": 100}],
  "strategy": "weight"
}

// 路由时
router.lua 调用 config.select_cdn_by_geo(client_ip)
→ 返回 "public" 或 "private"
→ config.get_cdn_url("public", "/uploads/photo.jpg")
→ 返回 "https://img.oxvxo.link/uploads/photo.jpg"
```

### 新架构（已实现）

```json
// 请求
{
  "image_path": "/uploads/photo.jpg",
  "enable_geo_routing": true
}

// 创建时（cdn_builder）
cdn_builder.build_image_targets(path, true)
→ 生成 4 个完整 URL targets

// 数据库存储
{
  "targets": [
    {"url": "https://cdn-north.com/uploads/photo.jpg", "region": "cn-north", "isp": "telecom", "weight": 100},
    {"url": "https://cdn-south.com/uploads/photo.jpg", "region": "cn-south", "isp": "unicom", "weight": 100},
    {"url": "https://cdn-overseas.com/uploads/photo.jpg", "region": "overseas", "weight": 100},
    {"url": "https://img.oxvxo.link/uploads/photo.jpg", "weight": 50}
  ],
  "strategy": "geo+weight",
  "fallback_url": "https://img.oxvxo.link/uploads/photo.jpg"
}

// 路由时
router.lua 只需：
→ 读取 targets 和 strategy
→ 调用 strategies.select(strategy, targets, client_info)
→ 返回选中的 target.url（已经是完整URL）
```

## 🎯 优势分析

### 1. **性能提升**
- ❌ 旧: 每次访问都调用 `config.select_cdn_by_geo()`
- ✅ 新: 创建时生成URL，访问时直接使用

### 2. **路由灵活性**
- ❌ 旧: 只支持简单的 public/private 切换
- ✅ 新: 支持 geo、ip、asn、weight、hash、组合策略

### 3. **可扩展性**
- ❌ 旧: 添加新CDN需要修改 `config.lua` 和 `router.lua`
- ✅ 新: 只需在 `config.lua` 添加 CDN，`cdn_builder` 自动处理

### 4. **可维护性**
- ❌ 旧: 路由逻辑分散在多个地方（config.lua, router.lua）
- ✅ 新: 创建逻辑在 `cdn_builder`，路由逻辑在 `strategies/`

### 5. **可观测性**
- ❌ 旧: 难以追踪使用了哪个CDN
- ✅ 新: 日志清晰显示策略和选中的URL

## 🚀 如何测试

### 前提条件

1. **启动服务：**

```bash
cd c:\Users\DXY\Documents\shortimg-AI
docker-compose up -d
```

2. **检查服务状态：**

```bash
docker ps | findstr openresty
```

### 运行测试

```powershell
cd c:\Users\DXY\Documents\shortimg-AI\redirect-service
powershell -ExecutionPolicy Bypass -File test-new-routing.ps1
```

### 手动测试示例

#### 测试 1: 创建 GeoIP 路由短链

```powershell
$body = @{
    image_path = "/uploads/2024/test.jpg"
    enable_geo_routing = $true
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "http://localhost:8081/api/imagebed/create" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

**预期响应：**
```json
{
  "success": true,
  "data": {
    "code": "img-xxxxxxxxxxxx",
    "strategy": "geo+weight",
    "targets_count": 4,
    "geo_routing_enabled": true
  }
}
```

#### 测试 2: 创建简单路由短链

```powershell
$body = @{
    image_path = "/uploads/2024/simple.jpg"
    enable_geo_routing = $false
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "http://localhost:8081/api/imagebed/create" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body
```

**预期响应：**
```json
{
  "success": true,
  "data": {
    "code": "img-xxxxxxxxxxxx",
    "strategy": "weight",
    "targets_count": 1,
    "geo_routing_enabled": false
  }
}
```

#### 测试 3: 访问短链（验证路由）

```powershell
# 模拟北京电信用户访问
Invoke-WebRequest `
    -Uri "http://localhost:8081/img-xxxxxxxxxxxx" `
    -Headers @{"X-Forwarded-For" = "123.45.67.89"} `
    -MaximumRedirection 0 `
    -ErrorAction SilentlyContinue
```

**预期：**
- 返回 302 重定向
- Location 头包含北方或电信相关的 CDN URL

## 📝 配置 CDN 服务器

在 `conf/config.lua` 中配置实际的 CDN 地址：

```lua
_M.cdn_servers = {
    -- 北方电信 CDN
    north_telecom = {
        domain = "cdn-north-telecom.example.com",
        protocol = "https",
        port = nil
    },
    
    -- 南方联通 CDN
    south_unicom = {
        domain = "cdn-south-unicom.example.com",
        protocol = "https",
        port = nil
    },
    
    -- 海外 CDN
    overseas = {
        domain = "cdn-global.example.com",
        protocol = "https",
        port = nil
    },
    
    -- 主图床（腾讯云）
    tc_go_primary = {
        domain = "img.oxvxo.link",
        protocol = "https",
        port = nil
    },
    
    -- 降级地址
    fallback = {
        domain = "img.oxvxo.link",
        protocol = "https",
        port = nil
    }
}
```

## 🔍 调试日志

启用 GeoIP 路由后，日志会显示详细信息：

```
[INFO] 创建图床短链(新架构): img-abc123 -> /uploads/photo.jpg, 策略=geo+weight, 目标数=4, GeoIP=true
[INFO] Using routing strategy: geo+weight
[INFO] GeoIP: IP=123.45.67.89, Country=CN, Province=北京, ISP=China Telecom
[INFO] Selected target: https://cdn-north-telecom.example.com/uploads/photo.jpg
```

查看日志：

```powershell
docker logs shortlink-openresty-1 --tail 50 -f
```

## ✅ 检查清单

- [x] V1 API 已迁移到 `cdn_builder`
- [x] 支持 `enable_geo_routing` 参数
- [x] 响应包含 `strategy` 和 `targets_count`
- [x] 批量创建支持 GeoIP 路由
- [x] 测试脚本已创建
- [x] 文档已更新

## 📚 相关文档

- `ADVANCED_ROUTING_GUIDE.md` - 高级路由引擎使用指南
- `lua/utils/cdn_builder.lua` - CDN URL 构建器
- `lua/api/imagebed.lua` - V1 API（已迁移）
- `lua/api/imagebed_v2.lua` - V2 API（新架构示例）
- `lua/core/router.lua` - 路由核心（已简化）

## 🎉 总结

V1 API (`imagebed.lua`) 已成功迁移到新的路由架构：

1. ✅ **向后兼容** - 旧的 `image_path` 和 `image_url` 字段仍然支持
2. ✅ **功能增强** - 新增 `enable_geo_routing` 参数控制路由策略
3. ✅ **响应更丰富** - 返回 `strategy`、`targets_count` 等信息
4. ✅ **性能提升** - 创建时生成URL，访问时直接使用
5. ✅ **易于维护** - 路由逻辑集中在 `cdn_builder` 和 `strategies/`

现在可以启动服务并运行测试脚本验证新架构！🚀
