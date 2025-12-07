-- router_adapter.lua
-- 路由适配器 - 统一路由引擎接口

local _M = {}

-- 懒加载路由引擎
local routing_engine = nil

-- 获取路由引擎实例
local function get_routing_engine()
    if not routing_engine then
        local ok, engine = pcall(require, "routing_engine")
        if ok then
            routing_engine = engine
            ngx.log(ngx.INFO, "[RouterAdapter] 路由引擎已加载")
        else
            ngx.log(ngx.ERR, "[RouterAdapter] 路由引擎加载失败: ", engine)
            -- 返回降级实现
            return nil
        end
    end
    return routing_engine
end

-- 降级处理：路由引擎不可用时的简单逻辑
local function fallback_select_cdn(client_info)
    -- 简单判断：内网用private，外网用public
    local client_ip = client_info.ip

    -- 检查内网IP
    if client_ip:match("^10%.") or
       client_ip:match("^172%.1[6-9]%.") or
       client_ip:match("^172%.2[0-9]%.") or
       client_ip:match("^172%.3[0-1]%.") or
       client_ip:match("^192%.168%.") or
       client_ip:match("^127%.") then
        ngx.log(ngx.INFO, "[RouterAdapter] 降级模式: 内网IP使用private")
        return "private"
    end

    -- 默认使用public
    ngx.log(ngx.INFO, "[RouterAdapter] 降级模式: 使用public")
    return "public"
end

-- 主路由选择函数
function _M.select_cdn(client_info, request_info)
    -- 准备请求信息
    request_info = request_info or {
        path = ngx.var.uri,
        method = ngx.var.request_method,
        args = ngx.req.get_uri_args()
    }

    -- 获取路由引擎
    local engine = get_routing_engine()

    if engine then
        -- 使用路由引擎
        local cdn_id = engine.select_cdn(client_info, request_info)
        ngx.log(ngx.INFO, "[RouterAdapter] 路由引擎选择: ", cdn_id)
        return cdn_id
    else
        -- 降级处理
        ngx.log(ngx.WARN, "[RouterAdapter] 路由引擎不可用，使用降级逻辑")
        return fallback_select_cdn(client_info)
    end
    end

    return cdn_id
end

-- 构建完整URL
function _M.build_url(cdn_id, path)
    local engine = get_routing_engine()

    if engine then
        return engine.build_url(cdn_id, path)
    else
        -- 降级：简单拼接
        ngx.log(ngx.WARN, "[RouterAdapter] 使用降级URL构建")
        return "https://dxy.oxvxo.net:18443" .. path
    end
end

-- 获取降级链
function _M.get_fallback_chain(cdn_id)
    local engine = get_routing_engine()

    if engine then
        return engine.get_fallback_chain()
    else
        -- 默认降级链
        return {"public", "private"}
    end
end

-- 重载配置
function _M.reload()
    local engine = get_routing_engine()

    if engine then
        ngx.log(ngx.INFO, "[RouterAdapter] 重载路由配置")
        return engine.reload()
    end

    return true
end

return _M
