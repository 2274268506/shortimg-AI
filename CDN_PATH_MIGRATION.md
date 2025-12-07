# 图床短链服务GeoIP分流配置完成报告

## ✅ 已完成的修改

### 1. 后端配置 (backend/)

#### 1.1 环境变量 (.env)
```bash
# 短链服务配置
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://localhost
SHORT_LINK_EXPIRE=0

# CDN 配置（新增）
CDN_DOMAIN=dxy.oxvxo.net
CDN_PORT=18443
CDN_PROTOCOL=https
```

#### 1.2 配置结构 (config/config.go)
添加了CDN配置字段：
```go
// CDN 配置
CDNDomain   string // CDN域名
CDNPort     int    // CDN端口
CDNProtocol string // CDN协议 (http/https)
```

从环境变量加载：
```go
CDNDomain:   getEnv("CDN_DOMAIN", "dxy.oxvxo.net"),
CDNPort:     getEnvAsInt("CDN_PORT", 18443),
CDNProtocol: getEnv("CDN_PROTOCOL", "https"),
```

#### 1.3 短链客户端 (utils/shortlink_client.go)
**修改请求结构** - 使用CDN路径而不是完整URL：
```go
// 修改前
type ShortLinkRequest struct {
    ImageURL   string  `json:"image_url"`  // 完整HTTP URL
}

// 修改后
type ShortLinkRequest struct {
    ImagePath  string  `json:"image_path"` // CDN路径，如 /uploads/xxx.jpg
}
```

同样修改了批量上传结构：
```go
type ImageInfo struct {
    ImagePath  string `json:"image_path"` // CDN路径
}
```

#### 1.4 图片控制器 (controllers/image_controller.go)

**单张上传**：
```go
// 修改前
fullImageURL := fmt.Sprintf("http://%s%s", baseURL, imageRecord.URL)
shortLinkReq := &utils.ShortLinkRequest{
    ImageURL: fullImageURL,
}

// 修改后 - 只传路径
imagePath := imageRecord.URL // 例如: /uploads/xxx.jpg
shortLinkReq := &utils.ShortLinkRequest{
    ImagePath: imagePath, // 让短链服务根据GeoIP自动选择CDN
}
```

**批量上传**：
```go
// 修改前
fullImageURL := fmt.Sprintf("http://%s%s", baseURL, imageRecord.URL)
shortLinkImages = append(shortLinkImages, utils.ImageInfo{
    ImageURL: fullImageURL,
})

// 修改后
imagePath := imageRecord.URL
shortLinkImages = append(shortLinkImages, utils.ImageInfo{
    ImagePath: imagePath,
})
```

**图片列表/详情** - 使用配置而不是硬编码：
```go
// 修改前
shortLinkHost := "http://localhost" // 硬编码

// 修改后
cfg := config.GetConfig()
shortLinkHost := cfg.ShortLinkBaseURL
if shortLinkHost == "" {
    shortLinkHost = "http://localhost"
}
```

---

### 2. 短链服务 (redirect-service/)

#### 2.1 路由器修复 (lua/core/router.lua)

**修复全局变量警告**：
```lua
-- 修改前
function detect_device_type(user_agent)  -- 全局函数

-- 修改后
local function detect_device_type(user_agent)  -- 局部函数
```

**函数定义顺序调整** - `detect_device_type` 移到 `get_client_info` 之前

**在模块顶部添加config依赖**：
```lua
local config = require "conf.config"
local redis_client = require "storage.redis_client"
local mysql_client = require "storage.mysql_client"
```

**移除重复的local require**：
```lua
-- 修改前
elseif target.cdn and target.path then
    local config = require "conf.config"  -- 重复
    target_url = config.get_cdn_url(target.cdn, target.path)

-- 修改后
elseif target.cdn and target.path then
    target_url = config.get_cdn_url(target.cdn, target.path)
```

#### 2.2 图床API修改 (lua/api/imagebed.lua)

**支持路径和URL两种模式**：
```lua
-- 创建单个短链
function _M.create()
    local data, err = read_body()
    if not data then return respond_error(err) end

    -- 兼容两种格式：image_url（完整URL）和 image_path（CDN路径）
    local image_url = data.image_url
    local image_path = data.image_path

    if not image_url and not image_path then
        return respond_error("缺少image_url或image_path字段")
    end

    -- ...

    -- 根据输入类型构建targets
    local targets
    if image_path then
        -- 使用路径模式，触发GeoIP分流
        targets = cjson.encode({{path = image_path, weight = 100}})
        logger.info("创建图床短链(路径模式，GeoIP分流): " .. code .. " -> " .. image_path)
    else
        -- 使用完整URL模式
        targets = cjson.encode({{url = image_url, weight = 100}})
        logger.info("创建图床短链(URL模式): " .. code .. " -> " .. image_url)
    end
```

**批量创建同样支持两种模式**：
```lua
for i, img in ipairs(data.images) do
    local image_url = img.image_url
    local image_path = img.image_path

    if (image_url and image_url:match("^https?://")) or image_path then
        -- ...
        local targets
        if image_path then
            targets = cjson.encode({{path = image_path, weight = 100}})
        else
            targets = cjson.encode({{url = image_url, weight = 100}})
        end
        -- ...
    end
end
```

---

## ⚠️ 需要解决的问题

### Docker挂载问题

**问题描述**：
`docker-compose.yml` 中所有文件挂载都是只读模式 (`:ro`)，导致修改无法生效：

```yaml
volumes:
  - ./conf/config.lua:/usr/local/openresty/nginx/conf/config.lua:ro  # 只读！
  - ./lua:/usr/local/openresty/nginx/lua:ro  # 只读！
```

**解决方案**：
修改 `redirect-service/docker-compose.yml`：

```yaml
volumes:
  # 配置文件改为可写（用于开发）
  - ./conf/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf
  - ./conf/upstream.conf:/usr/local/openresty/nginx/conf/upstream.conf
  - ./conf/config.lua:/usr/local/openresty/nginx/conf/config.lua
  - ./conf/https.conf:/usr/local/openresty/nginx/conf/https.conf
  - ./lua:/usr/local/openresty/nginx/lua
  - ./lib:/usr/local/openresty/site/lualib/resty
  # ... 其他保持不变
```

**然后重启服务**：
```bash
cd c:\Users\DXY\Documents\TC-GO\redirect-service
docker-compose down
docker-compose up -d
```

---

## 🧪 测试步骤

### 1. 测试短链API（路径模式）

```powershell
# 使用CDN路径创建短链
$body = @{image_path="/uploads/test.jpg"} | ConvertTo-Json
curl.exe -X POST http://localhost/api/imagebed/create -H "Content-Type: application/json" -d $body
```

**预期响应**：
```json
{
  "success": true,
  "data": {
    "code": "img-xxxxxxxxxxxx",
    "short_url": "http://localhost/img-xxxxxxxxxxxx",
    "long_url": "/uploads/test.jpg",
    "created_at": 1765034090
  }
}
```

### 2. 测试GeoIP分流

```powershell
# 从本地访问（私有IP）
curl.exe -I http://localhost/img-xxxxxxxxxxxx
# 预期：302 → http://localhost/uploads/test.jpg

# 查看日志确认分流
docker logs short-link-openresty --tail 20 | Select-String "GeoIP"
# 预期：GeoIP分流: IP=127.0.0.1 CDN=private
```

### 3. 测试后端集成

```bash
# 启动后端服务
cd backend
go run main.go

# 上传图片并启用短链
# （需要通过前端或API测试）
```

---

## 📊 架构流程图

```
图床上传图片
    ↓
后端生成图片记录 (path: /uploads/xxx.jpg)
    ↓
如果启用短链 → 调用短链服务API
    ↓
POST /api/imagebed/create
{
    "image_path": "/uploads/xxx.jpg"  ← 只传路径，不传域名
}
    ↓
短链服务存储：
{
    "targets": [{"path": "/uploads/xxx.jpg"}]  ← 路径模式
}
    ↓
用户访问短链 http://localhost/img-xxx
    ↓
路由器检测target.path存在
    ↓
调用 config.select_cdn_by_geo(client_ip)
    ↓
判断IP类型：
  - 127.0.0.1 (私有) → cdn="private"
  - 8.8.8.8 (公网) → cdn="public"
    ↓
调用 config.get_cdn_url(cdn_name, path)
    ↓
生成完整URL：
  - private: http://localhost/uploads/xxx.jpg
  - public: https://dxy.oxvxo.net:18443/uploads/xxx.jpg
    ↓
302重定向到CDN URL
```

---

## 📝 配置汇总

### 开发环境配置

**后端** (`backend/.env`):
```bash
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://localhost
CDN_DOMAIN=localhost
CDN_PORT=8080
CDN_PROTOCOL=http
```

**短链服务** (`redirect-service/.env`):
```bash
CDN_PRIVATE_DOMAIN=localhost
CDN_PRIVATE_PROTOCOL=http

CDN_PUBLIC_DOMAIN=dxy.oxvxo.net
CDN_PUBLIC_PORT=18443
CDN_PUBLIC_PROTOCOL=https
```

### 生产环境配置

**后端**:
```bash
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=https://s.yourdomain.com
CDN_DOMAIN=cdn.yourdomain.com
CDN_PORT=443
CDN_PROTOCOL=https
```

**短链服务**:
```bash
CDN_PRIVATE_DOMAIN=localhost
CDN_PRIVATE_PROTOCOL=http

CDN_PUBLIC_DOMAIN=cdn.yourdomain.com
CDN_PUBLIC_PORT=443
CDN_PUBLIC_PROTOCOL=https
```

---

## ✨ 功能特性

✅ **使用CDN路径而不是完整URL** - 灵活支持多CDN环境
✅ **GeoIP自动分流** - 私有IP访问本地，公网IP访问CDN
✅ **配置化CDN服务器** - 可在.env中配置域名和端口
✅ **后端去硬编码** - 所有URL拼接使用配置
✅ **兼容两种模式** - 同时支持完整URL和CDN路径

---

## 🚀 下一步

1. **修改docker-compose.yml移除`:ro`标记**
2. **重启短链服务容器**
3. **测试GeoIP分流功能**
4. **重启后端服务加载新配置**
5. **前端测试完整上传流程**

---

**修改完成时间**: 2025-12-06 23:20
**修改人**: GitHub Copilot
