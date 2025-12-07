# GeoIP分流功能实现总结

## 📝 实现内容

### 1. 前端优化 - 删除生成随机码功能

#### 修改文件：
- `html/dashboard/index.html`
- `html/dashboard/dashboard.js`

#### 修改内容：
1. **删除短链码输入框和生成按钮**
   - 步骤1只保留：服务类型选择 + 描述
   - 移除：短链代码输入框、🎲生成按钮、预览URL

2. **修改表单提交逻辑**
   - 删除 `short_code` 字段验证
   - 后端将自动生成短链码
   - 创建成功后显示生成的短链码

3. **删除相关函数**
   - `generateRandomCode()` - 生成随机码
   - `updatePreviewUrl()` - 更新预览URL
   - 相关事件监听器

### 2. GeoIP分流配置

#### 2.1 环境变量配置（.env）

```bash
# 私有网络(PRIVATE) - 本地开发
CDN_PRIVATE_DOMAIN=localhost
CDN_PRIVATE_PROTOCOL=http

# 公网(PUBLIC) - 生产环境
CDN_PUBLIC_DOMAIN=dxy.oxvxo.net
CDN_PUBLIC_PORT=18443
CDN_PUBLIC_PROTOCOL=https

# GeoIP数据库
GEOIP_COUNTRY_DB=/usr/local/openresty/nginx/geoip/Country-without-asn.mmdb
```

#### 2.2 配置文件修改（conf/config.lua）

**添加的CDN服务器**：
```lua
_M.cdn_servers = {
    -- 私有网络
    private = {
        domain = "localhost",
        protocol = "http",
        port = nil,
    },
    -- 公网
    public = {
        domain = "dxy.oxvxo.net",
        protocol = "https",
        port = 18443,
    },
    ...
}
```

**新增函数**：
```lua
-- 判断私有IP
function _M.is_private_ip(ip)
    -- 10.0.0.0/8
    -- 172.16.0.0/12
    -- 192.168.0.0/16
    -- 127.0.0.0/8
end

-- GeoIP分流选择CDN
function _M.select_cdn_by_geo(client_ip)
    if _M.is_private_ip(client_ip) then
        return "private"  -- 本地网络 → localhost
    else
        return "public"   -- 公网 → dxy.oxvxo.net:18443
    end
end

-- 生成完整CDN URL（支持端口）
function _M.get_cdn_url(cdn_name, path)
    local url = cdn.protocol .. "://" .. cdn.domain
    if cdn.port and cdn.port ~= 80 and cdn.port ~= 443 then
        url = url .. ":" .. cdn.port
    end
    url = url .. path
    return url
end
```

#### 2.3 路由逻辑修改（lua/core/router.lua）

**支持三种target配置方式**：

1. **完整URL** - 通用短链
   ```json
   {"url": "https://www.baidu.com", "weight": 1}
   ```

2. **指定CDN+路径** - 手动指定CDN
   ```json
   {"cdn": "north_telecom", "path": "/image.jpg", "weight": 1}
   ```

3. **仅路径** - 自动GeoIP分流（新增）
   ```json
   {"path": "/uploads/image.jpg", "weight": 1}
   ```

**核心逻辑**：
```lua
if target.url then
    -- 方式1: 直接跳转
    target_url = target.url
elseif target.cdn and target.path then
    -- 方式2: 使用指定CDN
    target_url = config.get_cdn_url(target.cdn, target.path)
elseif target.path then
    -- 方式3: GeoIP自动分流
    local client_ip = client_info.ip or ngx.var.remote_addr
    local cdn_name = config.select_cdn_by_geo(client_ip)  -- "private" 或 "public"
    logger.info("GeoIP分流: IP=" .. client_ip .. " CDN=" .. cdn_name)
    target_url = config.get_cdn_url(cdn_name, target.path)
end
```

## 🧪 测试场景

### 场景1：创建通用短链（前端）

**操作**：
1. 访问 http://localhost/dashboard/
2. 点击"创建短链"
3. 选择服务类型：通用短链
4. 输入目标URL：`https://www.baidu.com`
5. 提交

**预期结果**：
```json
{
  "success": true,
  "data": {
    "short_code": "abc12345",  // 后端自动生成
    "id": 30
  }
}
```

**前端显示**：
```
✅ 创建成功！短链码: abc12345
```

### 场景2：创建图床短链（自动GeoIP分流）

**操作**：
1. 选择服务类型：图床服务
2. 输入资源路径：`/uploads/2025/12/test.jpg`
3. 提交

**API请求**：
```json
{
  "service_type": "imagebed",
  "targets": [
    {"path": "/uploads/2025/12/test.jpg", "weight": 1}
  ],
  "strategy": "weight"
}
```

**后端处理**：
- 生成短链码（如 `img98765`）
- 保存到数据库

**访问测试**：

**本地访问**（127.0.0.1）：
```bash
curl -I http://localhost/img98765
# Location: http://localhost/uploads/2025/12/test.jpg
```

**公网访问**（非私有IP）：
```bash
curl -I http://your-server.com/img98765
# Location: https://dxy.oxvxo.net:18443/uploads/2025/12/test.jpg
```

### 场景3：验证GeoIP分流

**测试1 - 私有IP**：
```bash
# 从本地访问
curl http://localhost/img98765
# 跳转到：http://localhost/uploads/2025/12/test.jpg
```

**测试2 - 公网IP**：
```bash
# 模拟公网访问（修改X-Forwarded-For）
curl -H "X-Forwarded-For: 8.8.8.8" http://localhost/img98765
# 跳转到：https://dxy.oxvxo.net:18443/uploads/2025/12/test.jpg
```

## 📊 分流规则

### 私有IP范围（→ localhost）

| CIDR | 范围 | 说明 |
|------|------|------|
| 10.0.0.0/8 | 10.0.0.0 - 10.255.255.255 | A类私有网络 |
| 172.16.0.0/12 | 172.16.0.0 - 172.31.255.255 | B类私有网络 |
| 192.168.0.0/16 | 192.168.0.0 - 192.168.255.255 | C类私有网络 |
| 127.0.0.0/8 | 127.0.0.1 - 127.255.255.255 | 本地回环 |

### 公网IP（→ dxy.oxvxo.net:18443）

所有非私有IP地址都会分流到公网服务器。

## 🔍 日志查看

```bash
# 查看GeoIP分流日志
docker logs short-link-openresty | grep "GeoIP分流"

# 示例输出：
# GeoIP分流: IP=127.0.0.1 CDN=private
# GeoIP分流: IP=192.168.1.100 CDN=private
# GeoIP分流: IP=8.8.8.8 CDN=public
```

## ✨ 优势

1. **自动分流**：
   - 本地开发：自动使用localhost，无需修改配置
   - 生产环境：自动分流到公网服务器

2. **灵活性**：
   - 通用短链：直接URL，不经过CDN
   - 图床/文件：自动GeoIP分流
   - 特殊需求：可手动指定CDN

3. **前端简化**：
   - 删除复杂的短链码生成逻辑
   - 后端统一管理短链码格式
   - 用户体验更简单

## 📝 注意事项

1. **GeoIP数据库**：
   - 文件路径：`redirect-service/geoip/Country-without-asn.mmdb`
   - 确保文件存在且挂载正确

2. **端口配置**：
   - 私有网络使用默认端口（80/443）
   - 公网服务器使用自定义端口18443

3. **后端生成短链码**：
   - 前端不再发送`short_code`字段
   - 后端需要实现自动生成逻辑
   - 建议：12位随机字符串或snowflake ID

## 🚀 下一步

- [ ] 后端实现自动生成短链码的逻辑
- [ ] 完善GeoIP数据库（可选升级到City级别）
- [ ] 添加更多分流规则（ISP、地理位置等）
- [ ] 监控分流效果和统计
