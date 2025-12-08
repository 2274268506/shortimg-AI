# 启用 API Key 认证指南

## 问题说明

批量上传时选择生成短链，但没有生成短链，后端日志显示：
```
批量生成短链失败: 批量创建失败: Authentication required
```

## 原因分析

V2 API 配置了强制认证，但：
1. `redirect-service/.env` 中 `API_KEY_ENABLED=false`
2. 后端没有配置 `SHORT_LINK_API_KEY`
3. nginx.conf 中 V2 API 强制调用 `authenticate()`

## 快速修复（已完成）

修改 `nginx.conf`，让 V2 API 认证变为可选：

```lua
location /api/v2/imagebed/ {
    access_by_lua_block {
        -- 可选 API 认证（如果环境变量启用）
        local config = require("conf.config")
        if config.api_key_enabled then
            require("middleware.auth").authenticate()
        end
        -- 速率限制
        require("middleware.auth").rate_limit(10000, 60)
    }

    content_by_lua_block {
        require("api.imagebed_v2").handle()
    }
}
```

**当前状态**：
- ✅ V2 API 不需要认证即可调用
- ✅ 批量上传可以正常生成短链
- ⚠️ 生产环境建议启用认证

## 生产环境配置（可选）

### 1. 生成 API Key

```powershell
cd redirect-service
.\create_test_api_key.ps1
```

这会创建一个 API Key 并存储到 Redis。

### 2. 启用 API Key

修改 `redirect-service/.env`：

```env
API_KEY_ENABLED=true
API_KEY=your-generated-api-key-here
```

### 3. 配置后端

在后端添加 `.env` 文件或设置环境变量：

```env
SHORT_LINK_API_KEY=your-generated-api-key-here
SHORT_LINK_BASE_URL=http://short-link-openresty
```

### 4. 重启服务

```powershell
# 重启 redirect-service
cd redirect-service
docker-compose restart

# 重启 backend
cd ..\backend
# 如果使用 Docker
docker-compose restart

# 如果直接运行
# 停止并重新运行 go run main.go
```

## 测试

启用认证后，测试 V2 API：

```powershell
# 不带 API Key（应该失败）
curl -X POST http://localhost:8081/api/v2/imagebed/create `
    -H "Content-Type: application/json" `
    -d '{"image_path":"/test.jpg"}'

# 带 API Key（应该成功）
curl -X POST http://localhost:8081/api/v2/imagebed/create `
    -H "Content-Type: application/json" `
    -H "X-API-Key: your-api-key-here" `
    -d '{"image_path":"/test.jpg"}'
```

## 安全建议

1. **生产环境必须启用 API Key 认证**
2. **使用强随机密钥**（至少 32 字符）
3. **定期轮换 API Key**
4. **在 HTTPS 下使用**（避免密钥泄露）
5. **监控认证失败日志**（检测攻击）

## 当前配置状态

### 开发环境（当前）
- API_KEY_ENABLED: `false`
- 认证策略: **可选**（兼容无认证调用）
- 适用场景: 本地开发、测试

### 生产环境（推荐）
- API_KEY_ENABLED: `true`
- 认证策略: **强制**（所有请求必须认证）
- 适用场景: 生产部署、公网暴露

## 故障排查

### 问题：仍然报 Authentication required

**检查项**：
1. OpenResty 配置是否重新加载：
   ```powershell
   docker exec short-link-openresty /usr/local/openresty/bin/openresty -s reload
   ```

2. 检查 Lua 代码缓存：
   ```powershell
   docker restart short-link-openresty
   ```

3. 检查日志：
   ```powershell
   docker logs short-link-openresty --tail 50
   ```

### 问题：后端无法连接到 redirect-service

**检查项**：
1. 网络连通性：
   ```powershell
   docker exec shortimg-backend-test ping short-link-openresty
   ```

2. 端口是否开放：
   ```powershell
   docker exec shortimg-backend-test curl http://short-link-openresty/health
   ```

3. 检查 backend 配置中的 `SHORT_LINK_BASE_URL`

## 相关文件

- `redirect-service/conf/nginx.conf` - Nginx 配置（已修改）
- `redirect-service/lua/middleware/auth.lua` - 认证中间件
- `redirect-service/.env` - 环境变量配置
- `redirect-service/create_test_api_key.ps1` - API Key 生成脚本
- `backend/config/config.go` - 后端配置
- `backend/utils/shortlink_client.go` - V2 API 客户端

## 修改历史

- **2025-12-08**: 修改 V2 API 认证为可选，修复批量上传短链生成失败问题
