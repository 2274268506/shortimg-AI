-- middleware/auth.lua
-- API 认证中间件

local redis_client = require "storage.redis_client"
local config = require "conf.config"
local cjson = require "cjson.safe"

local _M = {}

local ngx_var = ngx.var
local ngx_header = ngx.header
local ngx_exit = ngx.exit
local ngx_say = ngx.say

-- 返回错误响应
local function error_response(status, message)
    ngx.status = status
    ngx.header["Content-Type"] = "application/json"
    ngx_say(cjson.encode({
        success = false,
        error = message,
        timestamp = ngx.time()
    }))
    ngx_exit(status)
end

-- 验证 API Key
local function verify_api_key(api_key)
    if not api_key or api_key == "" then
        return false, "API key is required"
    end

    -- 从 Redis 检查 API key
    local key_info, err = redis_client.get("api_key:" .. api_key)

    if err then
        ngx.log(ngx.ERR, "验证 API key 失败: ", err)
        return false, "Authentication failed"
    end

    if not key_info then
        return false, "Invalid API key"
    end

    -- 解析 API key 信息
    local info = cjson.decode(key_info)
    if not info then
        return false, "Invalid API key format"
    end

    -- 检查是否过期
    if info.expires_at and info.expires_at > 0 and info.expires_at < ngx.time() then
        return false, "API key expired"
    end

    -- 检查是否被禁用
    if info.status ~= "active" then
        return false, "API key is disabled"
    end

    return true, info
end

-- Bearer Token 认证
local function verify_bearer_token(token)
    if not token or token == "" then
        return false, "Token is required"
    end

    -- 这里可以实现 JWT 验证
    -- 简化版：使用 Redis 存储的 token
    local token_info, err = redis_client.get("auth_token:" .. token)

    if err then
        ngx.log(ngx.ERR, "验证 token 失败: ", err)
        return false, "Authentication failed"
    end

    if not token_info then
        return false, "Invalid token"
    end

    local info = cjson.decode(token_info)
    if not info then
        return false, "Invalid token format"
    end

    -- 检查是否过期
    if info.expires_at and info.expires_at < ngx.time() then
        return false, "Token expired"
    end

    return true, info
end

-- API 认证中间件
function _M.authenticate()
    -- 获取认证头
    local auth_header = ngx_var.http_authorization
    local api_key_header = ngx_var.http_x_api_key

    local authenticated = false
    local auth_info = nil

    -- 优先使用 API Key
    if api_key_header then
        local ok, info = verify_api_key(api_key_header)
        if ok then
            authenticated = true
            auth_info = info
        else
            error_response(401, info)  -- info 包含错误消息
        end
    -- 其次使用 Bearer Token
    elseif auth_header then
        local token = auth_header:match("^Bearer%s+(.+)$")
        if token then
            local ok, info = verify_bearer_token(token)
            if ok then
                authenticated = true
                auth_info = info
            else
                error_response(401, info)
            end
        else
            error_response(401, "Invalid authorization header format")
        end
    else
        error_response(401, "Authentication required")
    end

    -- 将认证信息存储到 ngx.ctx，供后续处理使用
    if authenticated and auth_info then
        ngx.ctx.auth_info = auth_info
        ngx.ctx.authenticated = true
    end
end

-- 检查权限（可选）
function _M.check_permission(required_permission)
    local auth_info = ngx.ctx.auth_info

    if not auth_info then
        error_response(403, "No authentication information")
    end

    -- 检查权限列表
    if auth_info.permissions then
        for _, perm in ipairs(auth_info.permissions) do
            if perm == required_permission or perm == "*" then
                return true
            end
        end
    end

    error_response(403, "Permission denied")
end

-- 速率限制（基于认证用户）
function _M.rate_limit(max_requests, window_seconds)
    local auth_info = ngx.ctx.auth_info
    if not auth_info then
        return
    end

    local identifier = auth_info.user_id or auth_info.api_key or "unknown"
    local key = "rate_limit:auth:" .. identifier

    local count, err = redis_client.incr(key)
    if err then
        ngx.log(ngx.ERR, "速率限制检查失败: ", err)
        return
    end

    if count == 1 then
        redis_client.expire(key, window_seconds)
    end

    -- 设置响应头
    ngx_header["X-RateLimit-Limit"] = max_requests
    ngx_header["X-RateLimit-Remaining"] = math.max(0, max_requests - count)

    if count > max_requests then
        error_response(429, "Rate limit exceeded")
    end
end

return _M
