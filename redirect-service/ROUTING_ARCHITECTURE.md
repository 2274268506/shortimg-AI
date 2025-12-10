# 短链服务器群组分流架构总结

## 📋 概述

短链系统根据服务类型(service_type)采用不同的路由策略：
- **图床/文件/视频**：通过路由引擎根据GeoIP分流到不同的CDN服务器群组
- **通用类型**：直接302重定向到完整的目标URL，不经过CDN分流

## 🏗️ 架构设计

### 1. 服务类型分类

| 服务类型 | 前缀 | 路由方式 | 说明 |
|---------|------|---------|------|
| `imagebed` | `img-` | CDN分流 | 图床服务，路由到图床CDN群组 |
| `file` | `file-` | CDN分流 | 文件服务，路由到文件CDN群组 |
| `video` | `vid-` | CDN分流 | 视频服务，路由到视频CDN群组 |
| `general` | 无 | 直接重定向 | 通用短链，直接302到目标URL |

### 2. CDN服务器群组配置

系统共配置 **16个CDN节点**，分为3大服务群组：

#### 图床服务器群组 (5个节点)
```
imagebed_unicom    → img-unicom.example.com    (联通用户)
imagebed_mobile    → img-mobile.example.com    (移动用户)
imagebed_telecom   → img-telecom.example.com   (电信用户)
imagebed_overseas  → img-overseas.example.com  (海外用户)
imagebed_default   → img-cdn.example.com       (默认)
```

#### 文件服务器群组 (5个节点)
```
file_unicom    → file-unicom.example.com    (联通用户)
file_mobile    → file-mobile.example.com    (移动用户)
file_telecom   → file-telecom.example.com   (电信用户)
file_overseas  → file-overseas.example.com  (海外用户)
file_default   → file-cdn.example.com       (默认)
```

#### 视频服务器群组 (5个节点)
```
video_unicom    → video-unicom.example.com    (联通用户)
video_mobile    → video-mobile.example.com    (移动用户)
video_telecom   → video-telecom.example.com   (电信用户)
video_overseas  → video-overseas.example.com  (海外用户)
video_default   → video-cdn.example.com       (默认)
```

#### 特殊节点 (1个)
```
private → localhost:8080  (内网/测试环境)
```

**注意**：通用类型(general)不需要CDN服务器群组，因为它直接重定向到完整URL。

### 3. 路由规则

系统共配置 **16条路由规则**（不包括general类型）：

#### 内网路由 (1条规则)
- **Priority 10**: 内网IP → private CDN

#### 图床类型路由 (5条规则)
- **Priority 20**: 图床 + 电信 → imagebed_telecom
- **Priority 21**: 图床 + 联通 → imagebed_unicom
- **Priority 22**: 图床 + 移动 → imagebed_mobile
- **Priority 23**: 图床 + 海外 → imagebed_overseas
- **Priority 24**: 图床 + 默认 → imagebed_default

#### 文件类型路由 (5条规则)
- **Priority 30**: 文件 + 电信 → file_telecom
- **Priority 31**: 文件 + 联通 → file_unicom
- **Priority 32**: 文件 + 移动 → file_mobile
- **Priority 33**: 文件 + 海外 → file_overseas
- **Priority 34**: 文件 + 默认 → file_default

#### 视频类型路由 (5条规则)
- **Priority 40**: 视频 + 电信 → video_telecom
- **Priority 41**: 视频 + 联通 → video_unicom
- **Priority 42**: 视频 + 移动 → video_mobile
- **Priority 43**: 视频 + 海外 → video_overseas
- **Priority 44**: 视频 + 默认 → video_default

## 🔄 工作流程

### 图床/文件/视频类型的处理流程

```
用户访问短链
    ↓
获取短链数据 (Redis/MySQL)
    ↓
识别 service_type (imagebed/file/video)
    ↓
调用路由引擎
    ↓
获取客户端信息 (IP, ISP, Country)
    ↓
匹配路由规则 (按优先级)
    ↓
选择CDN节点
    ↓
构建完整URL
    ↓
302重定向到CDN
```

**示例**：
```
用户: 北京电信用户
访问: http://your-domain.com/img-abc123
数据: {"service_type":"imagebed","targets":[{"path":"/uploads/photo.jpg"}]}

处理流程:
1. 识别 service_type = imagebed
2. 获取 ISP = China Telecom
3. 匹配规则 "图床_电信" (priority 20)
4. 选择节点 imagebed_telecom
5. 构建URL: https://img-telecom.example.com/uploads/photo.jpg
6. 302重定向
```

### 通用类型的处理流程

```
用户访问短链
    ↓
获取短链数据 (Redis/MySQL)
    ↓
识别 service_type (general)
    ↓
跳过路由引擎 ⚠️
    ↓
直接从targets中获取完整URL
    ↓
302重定向到目标URL
```

**示例**：
```
用户: 任意用户
访问: http://your-domain.com/abc123
数据: {"service_type":"general","targets":[{"url":"https://www.google.com"}]}

处理流程:
1. 识别 service_type = general
2. 跳过路由引擎（不需要CDN分流）
3. 直接获取 URL = https://www.google.com
4. 302重定向到 https://www.google.com
```

## 📝 关键代码位置

### 1. 路由配置文件
**文件**: `lua/routing_config_simple.lua`

```lua
-- CDN节点配置（16个节点，不包括general）
_M.cdn_nodes = {
    -- 内网节点
    {id = "private", domain = "localhost:8080", ...},
    
    -- 图床群组 (5个)
    {id = "imagebed_unicom", domain = "img-unicom.example.com", ...},
    {id = "imagebed_mobile", domain = "img-mobile.example.com", ...},
    -- ... 更多节点
    
    -- 文件群组 (5个)
    {id = "file_unicom", domain = "file-unicom.example.com", ...},
    -- ... 更多节点
    
    -- 视频群组 (5个)
    {id = "video_unicom", domain = "video-unicom.example.com", ...},
    -- ... 更多节点
}

-- 路由规则配置（16条规则）
_M.routing_rules = {
    -- 内网规则
    {priority = 10, conditions = {...}, target = "private"},
    
    -- 图床规则 (5条)
    {priority = 20, conditions = {service_type="imagebed", isp="电信"}, target = "imagebed_telecom"},
    -- ... 更多规则
    
    -- 文件规则 (5条)
    {priority = 30, conditions = {service_type="file", isp="电信"}, target = "file_telecom"},
    -- ... 更多规则
    
    -- 视频规则 (5条)
    {priority = 40, conditions = {service_type="video", isp="电信"}, target = "video_telecom"},
    -- ... 更多规则
}

-- 注意：通用类型(general)不需要路由规则
```

### 2. 路由引擎
**文件**: `lua/routing_engine.lua`

```lua
-- 选择CDN节点（仅用于imagebed/file/video）
function _M.select_cdn(client_info, request_info)
    local service_type = request_info.service_type
    
    -- 遍历路由规则，按优先级匹配
    for _, rule in ipairs(config.routing_rules) do
        if check_condition(rule.conditions, client_info, request_info) then
            return rule.target  -- 返回CDN节点ID
        end
    end
    
    return config.default_routing.target
end

-- 构建完整URL
function _M.build_url(cdn_id, path)
    local node = find_cdn_node(cdn_id)
    return node.protocol .. "://" .. node.domain .. path
end
```

### 3. 重定向处理
**文件**: `lua/core/router.lua`

```lua
function select_target(link_data, client_info)
    local service_type = link_data.service_type or "general"
    local targets = link_data.targets
    
    -- 图床/文件/视频：使用路由引擎
    if service_type == "imagebed" or service_type == "file" or service_type == "video" then
        -- 调用路由引擎选择CDN
        local cdn_id = routing_engine.select_cdn(client_info, request_info)
        
        -- 提取路径
        local path = targets[1].path or targets[1].url
        
        -- 构建完整URL
        local final_url = routing_engine.build_url(cdn_id, path)
        
        return final_url
        
    -- 通用类型：直接返回目标URL
    elseif service_type == "general" or service_type == "generic" then
        -- 不使用路由引擎，直接返回完整URL
        local target = strategies.select(strategy_name, healthy_targets, client_info)
        return target.url  -- 直接返回完整URL
    end
end
```

## 🎯 关键差异总结

| 特性 | 图床/文件/视频 | 通用类型 |
|-----|--------------|---------|
| **前缀** | img-/file-/vid- | 无 |
| **路由引擎** | ✅ 使用 | ❌ 不使用 |
| **CDN分流** | ✅ 根据GeoIP分流 | ❌ 不分流 |
| **CDN节点** | 15个 (每类型5个) | 0个 |
| **路由规则** | 15条 (每类型5条) | 0条 |
| **targets格式** | `[{"path":"/uploads/file.jpg"}]` | `[{"url":"https://example.com"}]` |
| **最终URL** | CDN域名 + 路径 | 直接使用完整URL |
| **示例** | `https://img-cdn.example.com/path` | `https://www.google.com` |

## 📊 数据结构对比

### 图床/文件/视频类型
```json
{
  "service_type": "imagebed",
  "strategy": "geo",
  "targets": [
    {
      "path": "/uploads/test-image.jpg",
      "weight": 1
    }
  ],
  "security_config": {}
}
```

**处理逻辑**：
1. 路由引擎选择CDN: `imagebed_telecom`
2. 提取路径: `/uploads/test-image.jpg`
3. 构建URL: `https://img-telecom.example.com/uploads/test-image.jpg`
4. 302重定向

### 通用类型
```json
{
  "service_type": "general",
  "strategy": "weight",
  "targets": [
    {
      "url": "https://www.google.com",
      "weight": 1
    }
  ],
  "security_config": {}
}
```

**处理逻辑**：
1. 跳过路由引擎
2. 直接获取URL: `https://www.google.com`
3. 302重定向

## 🚀 配置说明

### 环境变量配置

#### 图床CDN配置
```bash
CDN_IMAGEBED_UNICOM_DOMAIN=img-unicom.yourdomain.com
CDN_IMAGEBED_MOBILE_DOMAIN=img-mobile.yourdomain.com
CDN_IMAGEBED_TELECOM_DOMAIN=img-telecom.yourdomain.com
CDN_IMAGEBED_OVERSEAS_DOMAIN=img-overseas.yourdomain.com
CDN_IMAGEBED_DEFAULT_DOMAIN=img-cdn.yourdomain.com
```

#### 文件CDN配置
```bash
CDN_FILE_UNICOM_DOMAIN=file-unicom.yourdomain.com
CDN_FILE_MOBILE_DOMAIN=file-mobile.yourdomain.com
CDN_FILE_TELECOM_DOMAIN=file-telecom.yourdomain.com
CDN_FILE_OVERSEAS_DOMAIN=file-overseas.yourdomain.com
CDN_FILE_DEFAULT_DOMAIN=file-cdn.yourdomain.com
```

#### 视频CDN配置
```bash
CDN_VIDEO_UNICOM_DOMAIN=video-unicom.yourdomain.com
CDN_VIDEO_MOBILE_DOMAIN=video-mobile.yourdomain.com
CDN_VIDEO_TELECOM_DOMAIN=video-telecom.yourdomain.com
CDN_VIDEO_OVERSEAS_DOMAIN=video-overseas.yourdomain.com
CDN_VIDEO_DEFAULT_DOMAIN=video-cdn.yourdomain.com
```

**注意**：通用类型不需要CDN配置。

### GeoIP配置

```nginx
# nginx.conf
geoip2 /usr/local/openresty/nginx/conf/GeoLite2-City.mmdb {
    $geoip2_data_country_code source=$remote_addr country iso_code;
    $geoip2_data_isp source=$remote_addr traits isp;
}
```

## ✅ 优势

1. **性能优化**：通用短链不经过路由引擎，减少处理开销
2. **架构清晰**：不同类型采用不同处理逻辑，职责明确
3. **灵活性**：通用短链可以直接重定向到任意URL
4. **可扩展性**：CDN节点和路由规则可以独立扩展

## 📈 统计数据

- **总CDN节点**: 16个（不含general）
  - 内网节点: 1个
  - 图床节点: 5个
  - 文件节点: 5个
  - 视频节点: 5个

- **总路由规则**: 16条（不含general）
  - 内网规则: 1条
  - 图床规则: 5条
  - 文件规则: 5条
  - 视频规则: 5条

- **服务类型**: 4种
  - 需要CDN分流: 3种 (imagebed, file, video)
  - 直接重定向: 1种 (general)

## 🔍 测试验证

运行测试脚本验证功能：

```powershell
# 完整功能测试
.\test-routing-rules.ps1

# 通用类型直接重定向测试
.\test-general-direct-redirect.ps1

# 运营商分流测试
.\test-isp-routing.ps1
```

## 📚 相关文档

- [SERVICE_TYPE_ROUTING.md](SERVICE_TYPE_ROUTING.md) - 详细配置指南
- [TEST_REPORT.md](TEST_REPORT.md) - 测试报告
- [routing_config_simple.lua](lua/routing_config_simple.lua) - 路由配置
- [routing_engine.lua](lua/routing_engine.lua) - 路由引擎
- [router.lua](lua/core/router.lua) - 重定向处理

---

**最后更新**: 2025年12月10日
