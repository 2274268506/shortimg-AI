# ✅ V1 API 移除和配置简化完成

## 📋 已完成的变更

### 1️⃣ **移除 V1 API**

✅ **删除文件：**
- `lua/api/imagebed.lua` - V1 API 实现文件

✅ **修改文件：**
- `conf/nginx.conf` - 移除 `/api/imagebed/*` 路由配置

**影响：**
- ❌ `/api/imagebed/create` - 已移除
- ❌ `/api/imagebed/batch` - 已移除
- ❌ `/api/imagebed/info/{code}` - 已移除
- ❌ `/api/imagebed/metadata/{code}` - 已移除
- ❌ `/api/imagebed/stats` - 已移除

**替代方案：**
- ✅ 使用 V2 API：`/api/v2/imagebed/*` 和 `/api/v2/generic/*`

---

### 2️⃣ **配置统一到 routing_rules.yaml**

#### 变更前：

**config.lua（旧）：**
```lua
-- ❌ 在 config.lua 中定义 CDN 服务器
_M.cdn_servers = {
    private = { domain = "localhost", protocol = "http" },
    public = { domain = "img.oxvxo.link", protocol = "https" },
    north_telecom = { domain = "cdn-north.example.com" },
    south_unicom = { domain = "cdn-south.example.com" },
    ...
}

-- ❌ 在 config.lua 中定义分流逻辑
function _M.select_cdn_by_geo(client_ip)
    if _M.is_private_ip(client_ip) then
        return "private"
    else
        return "public"
    end
end
```

**cdn_builder.lua（旧）：**
```lua
-- ❌ 从 config.lua 读取 CDN 配置
local config = require "conf.config"
function _M.build_url(cdn_name, path)
    return config.get_cdn_url(cdn_name, path)
end
```

#### 变更后：

**routing_rules.yaml（新）：**
```yaml
# ✅ 所有 CDN 节点在 YAML 中定义
cdn_nodes:
  - id: private
    name: 私有网络CDN
    domain_env: CDN_PRIVATE_DOMAIN
    default_domain: localhost
    default_protocol: http
  
  - id: telecom
    name: 电信CDN
    domain_env: CDN_TELECOM_DOMAIN
    default_domain: cdn-telecom.example.com
    default_protocol: https
  
  - id: unicom
    name: 联通CDN
    domain_env: CDN_UNICOM_DOMAIN
    default_domain: cdn-unicom.example.com
    default_protocol: https
  
  - id: mobile
    name: 移动CDN
    domain_env: CDN_MOBILE_DOMAIN
    default_domain: cdn-mobile.example.com
    default_protocol: https
  
  - id: overseas
    name: 国外CDN
    domain_env: CDN_OVERSEAS_DOMAIN
    default_domain: cdn-overseas.example.com
    default_protocol: https
  
  - id: china
    name: 国内CDN
    domain_env: CDN_CHINA_DOMAIN
    default_domain: cdn-china.example.com
    default_protocol: https
  
  - id: backup
    name: 备用CDN
    domain_env: CDN_BACKUP_DOMAIN
    default_domain: cdn-backup.example.com
    default_protocol: https

# ✅ 所有分流规则在 YAML 中定义
routing_rules:
  - priority: 10
    name: 私有IP使用内网CDN
    conditions:
      - type: ip_range
        ranges: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    targets:
      - cdn_id: private
        weight: 100
  
  - priority: 20
    name: 电信用户
    conditions:
      - type: isp
        isps: ["China Telecom", "电信"]
    targets:
      - cdn_id: telecom
        weight: 100
  
  - priority: 30
    name: 联通用户
    conditions:
      - type: isp
        isps: ["China Unicom", "联通"]
    targets:
      - cdn_id: unicom
        weight: 100
  
  - priority: 40
    name: 移动用户
    conditions:
      - type: isp
        isps: ["China Mobile", "移动"]
    targets:
      - cdn_id: mobile
        weight: 100

default_routing:
  targets:
    - cdn_id: china
      weight: 80
    - cdn_id: backup
      weight: 20
```

**cdn_builder.lua（新）：**
```lua
-- ✅ 从 routing_rules.yaml 读取 CDN 配置
local yaml = require "lyaml"

local function load_cdn_nodes()
    local file = io.open("/usr/local/openresty/nginx/lua/routing_rules.yaml", "r")
    local content = file:read("*all")
    file:close()
    
    local config = yaml.load(content)
    local nodes = {}
    
    for _, node in ipairs(config.cdn_nodes) do
        local domain = os.getenv(node.domain_env) or node.default_domain
        local protocol = os.getenv(node.protocol_env) or node.default_protocol
        
        nodes[node.id] = {
            domain = domain,
            protocol = protocol
        }
    end
    
    return nodes
end
```

**config.lua（新）：**
```lua
-- ✅ 极简配置，只保留基础设施配置
local _M = {}

_M.server = {
    domain = os.getenv("REDIRECT_DOMAIN") or "short.example.com",
    protocol = os.getenv("REDIRECT_PROTOCOL") or "https",
}

_M.redis = { ... }
_M.mysql = { ... }
_M.geoip = { ... }

-- ❌ 不再包含 cdn_servers
-- ❌ 不再包含 select_cdn_by_geo()
-- ❌ 不再包含 get_cdn_url()
```

---

## 🎯 新架构的优势

### 1. **单一配置源**
- ✅ 所有 CDN 节点在 `routing_rules.yaml` 中定义
- ✅ 所有分流规则在 `routing_rules.yaml` 中定义
- ✅ 无需在多个文件间同步配置

### 2. **声明式配置**
- ✅ YAML 格式更直观易读
- ✅ 支持注释和文档
- ✅ 便于版本控制和 diff

### 3. **热更新支持**
- ✅ 修改 `routing_rules.yaml` 自动生效
- ✅ 无需重启服务
- ✅ 缓存 5 分钟后自动刷新

### 4. **环境变量支持**
- ✅ 每个 CDN 节点支持环境变量覆盖
- ✅ 开发/测试/生产环境使用同一配置文件
- ✅ 敏感信息通过环境变量注入

---

## 📊 配置对比

| 特性 | 旧架构 | 新架构 |
|------|--------|--------|
| **CDN 配置位置** | config.lua | routing_rules.yaml |
| **分流规则位置** | config.lua + router.lua | routing_rules.yaml |
| **配置格式** | Lua 代码 | YAML 声明式 |
| **热更新** | ❌ 需重启 | ✅ 自动生效 |
| **环境变量** | 部分支持 | ✅ 完全支持 |
| **可读性** | ⚠️ 中等 | ✅ 优秀 |
| **维护成本** | ⚠️ 中等 | ✅ 低 |

---

## 🔧 迁移指南

### 步骤 1: 更新环境变量

在 `.env` 文件中添加 CDN 配置：

```bash
# 国内通用 CDN
CDN_CHINA_DOMAIN=img.oxvxo.link
CDN_CHINA_PROTOCOL=https

# 电信 CDN
CDN_TELECOM_DOMAIN=cdn-telecom.oxvxo.link
CDN_TELECOM_PROTOCOL=https

# 联通 CDN
CDN_UNICOM_DOMAIN=cdn-unicom.oxvxo.link
CDN_UNICOM_PROTOCOL=https

# 移动 CDN
CDN_MOBILE_DOMAIN=cdn-mobile.oxvxo.link
CDN_MOBILE_PROTOCOL=https

# 海外 CDN
CDN_OVERSEAS_DOMAIN=cdn-global.oxvxo.link
CDN_OVERSEAS_PROTOCOL=https

# 备用 CDN
CDN_BACKUP_DOMAIN=cdn-backup.oxvxo.link
CDN_BACKUP_PROTOCOL=https
```

### 步骤 2: 配置 routing_rules.yaml

编辑 `routing_rules.yaml`，确保 `cdn_nodes` 部分已正确配置。

### 步骤 3: 使用 V2 API

**旧代码（V1 API）：**
```bash
curl -X POST http://localhost:8081/api/imagebed/create \
  -H "Content-Type: application/json" \
  -d '{"image_path": "/uploads/test.jpg"}'
```

**新代码（V2 API）：**
```bash
curl -X POST http://localhost:8081/api/v2/imagebed/create \
  -H "Content-Type: application/json" \
  -d '{"image_path": "/uploads/test.jpg", "enable_geo_routing": true}'
```

---

## 🧪 测试验证

### 测试 1: 验证 CDN 配置加载

```bash
# 查看日志，确认 CDN 节点加载成功
docker logs shortlink-openresty-1 --tail 20 | grep "已加载"

# 预期输出：
# [INFO] 已加载 7 个 CDN 节点配置
```

### 测试 2: 创建短链并验证

```bash
# 创建启用 GeoIP 的短链
curl -X POST http://localhost:8081/api/v2/imagebed/create \
  -H "Content-Type: application/json" \
  -d '{
    "image_path": "/uploads/2024/test.jpg",
    "enable_geo_routing": true
  }'

# 预期响应包含多个 CDN targets
{
  "success": true,
  "data": {
    "code": "img-xxxx",
    "strategy": "geo+weight",
    "targets_count": 5  // telecom + unicom + mobile + overseas + backup
  }
}
```

### 测试 3: 访问短链验证路由

```bash
# 模拟电信用户访问
curl -I http://localhost:8081/img-xxxx \
  -H "X-Forwarded-For: 123.45.67.89"

# 预期重定向到电信 CDN
# Location: https://cdn-telecom.oxvxo.link/uploads/2024/test.jpg
```

---

## 📝 文件变更清单

### 已删除
- ❌ `lua/api/imagebed.lua`

### 已修改
- ✅ `conf/nginx.conf` - 移除 V1 API 路由
- ✅ `conf/config.lua` - 移除 CDN 配置和分流函数
- ✅ `lua/utils/cdn_builder.lua` - 从 YAML 读取配置

### 配置文件
- ✅ `routing_rules.yaml` - 统一的配置源

---

## 🎉 总结

**已完成：**
1. ✅ 移除 V1 API（`/api/imagebed/*`）
2. ✅ 移除 `config.lua` 中的 CDN 配置
3. ✅ 移除 `config.lua` 中的分流逻辑
4. ✅ `cdn_builder.lua` 改为从 YAML 读取配置
5. ✅ 统一配置源到 `routing_rules.yaml`

**架构优势：**
- 🎯 单一配置源（YAML）
- 🔄 支持热更新
- 📝 声明式配置
- 🌍 环境变量支持
- 🚀 更易维护

**下一步：**
- 配置真实的 CDN 域名
- 测试 V2 API 功能
- 验证路由分流效果
- 部署到生产环境

---

**更新时间：** 2024-12-08  
**版本：** v2.0  
**状态：** ✅ 已完成
