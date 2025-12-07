# NAT环境配置指南

## 问题描述
短链服务部署在NAT后面（端口转发），导致获取的客户端IP是NAT设备的内网IP（如192.168.x.x），而不是真实的公网IP，造成GeoIP分流失败。

## 解决方案
短链服务现已支持从HTTP头获取真实客户端IP：
1. `X-Forwarded-For` (优先)
2. `X-Real-IP` (次选)
3. `remote_addr` (降级，直连情况)

## 配置步骤

### 1. Nginx作为前端代理

如果使用Nginx做反向代理，在upstream配置中添加：

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://短链服务地址:80;

        # 传递真实客户端IP
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
    }
}
```

### 2. 路由器NAT端口转发

如果只有简单的NAT端口转发（不支持HTTP头），需要升级方案：

#### 方案A：使用支持HTTP头的反向代理
在NAT设备后面部署Nginx/Caddy等反向代理：

```
互联网 → NAT路由器:80 → Nginx反向代理:8080 → 短链服务:80
                              ↑ 在这里添加X-Forwarded-For头
```

#### 方案B：配置路由器（如果支持）
部分高级路由器支持添加HTTP头，查看路由器文档中的"HTTP代理"或"应用层网关(ALG)"设置。

### 3. Cloudflare/CDN

如果使用Cloudflare或其他CDN：

**Cloudflare自动添加以下头**：
- `CF-Connecting-IP`: 真实客户端IP
- `X-Forwarded-For`: 代理链IP列表

可以修改 `redirect-service/lua/core/router.lua` 的 `get_real_client_ip()` 函数，添加CF支持：

```lua
-- 获取客户端真实IP（支持Cloudflare）
local function get_real_client_ip()
    -- Cloudflare专用头（最准确）
    local cf_ip = ngx_var.http_cf_connecting_ip
    if cf_ip then
        return cf_ip
    end

    -- X-Forwarded-For（通用）
    local xff = ngx_var.http_x_forwarded_for
    if xff then
        local first_ip = xff:match("([^,]+)")
        if first_ip then
            return first_ip:match("^%s*(.-)%s*$")
        end
    end

    -- X-Real-IP
    local real_ip = ngx_var.http_x_real_ip
    if real_ip then
        return real_ip
    end

    -- 降级
    return ngx_var.remote_addr
end
```

## 验证测试

### 1. 模拟外网访问（带X-Forwarded-For头）

```powershell
# 模拟公网IP (8.8.8.8)
curl.exe -H "X-Forwarded-For: 8.8.8.8" http://localhost/img-xxxx

# 预期重定向到：
# Location: https://dxy.oxvxo.net:18443/uploads/xxx.jpg
```

### 2. 查看日志确认IP识别

```bash
docker exec short-link-openresty tail -f /usr/local/openresty/nginx/logs/access.log
```

查找日志中的：
```json
{
  "remote_addr": "172.18.0.1",           # NAT内网IP
  "x_forwarded_for": "8.8.8.8",         # 真实公网IP
  "x_real_ip": null
}
```

### 3. 检查GeoIP分流日志

```bash
docker logs short-link-openresty 2>&1 | grep "GeoIP分流"
```

预期输出：
```
GeoIP分流: IP=8.8.8.8 判定为公网IP -> CDN=public
```

## 当前状态

✅ 已修改 `lua/core/router.lua` 支持从HTTP头获取真实IP
✅ 已添加日志记录便于调试
✅ 已更新nginx.conf日志格式，记录X-Forwarded-For和X-Real-IP

## 生产环境建议

1. **使用专业反向代理**
   - Nginx
   - Caddy
   - Traefik

2. **启用HTTPS**
   - 在反向代理层面配置SSL证书
   - 后端短链服务可以继续使用HTTP

3. **安全加固**
   - 限制允许设置X-Forwarded-For的来源IP
   - 防止IP伪造攻击

示例Nginx配置（安全版）：

```nginx
# 信任的代理IP列表
set_real_ip_from 127.0.0.1;
set_real_ip_from 172.16.0.0/12;
set_real_ip_from 192.168.0.0/16;
real_ip_header X-Forwarded-For;
real_ip_recursive on;

server {
    listen 443 ssl http2;
    server_name s.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Host $host;
    }
}
```

## 测试命令汇总

```powershell
# 1. 测试本地访问（应路由到private CDN）
curl.exe -I http://localhost/img-6e4CngzfpyMM

# 2. 模拟公网访问（应路由到public CDN）
curl.exe -H "X-Forwarded-For: 8.8.8.8" -I http://localhost/img-6e4CngzfpyMM

# 3. 查看访问日志
docker exec short-link-openresty tail -20 /usr/local/openresty/nginx/logs/access.log

# 4. 查看GeoIP分流日志
docker logs short-link-openresty --tail 50 | Select-String "GeoIP"
```
