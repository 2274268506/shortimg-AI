-- geoip_admin_api.lua
-- GeoIP 管理 API

local routing_engine = require "routing_engine"
local cjson = require "cjson.safe"

local _M = {}

-- 获取所有可用数据库
function _M.get_databases()
    local databases = routing_engine.get_available_geoip_databases()

    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({
        success = true,
        data = {
            databases = databases,
            total = #databases
        }
    }))
end

-- 获取当前选中的数据库
function _M.get_selected_databases()
    local selected = routing_engine.get_selected_geoip_databases()

    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({
        success = true,
        data = {
            selected = selected,
            total = #selected
        }
    }))
end

-- 验证数据库文件
function _M.validate_databases()
    local validation = routing_engine.validate_geoip_databases()

    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({
        success = true,
        data = {
            validation = validation
        }
    }))
end

-- 获取推荐配置
function _M.get_recommendations()
    local recommendations = routing_engine.get_geoip_recommendations()

    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({
        success = true,
        data = recommendations
    }))
end

-- 测试IP查询
function _M.test_query()
    ngx.req.read_body()
    local body = ngx.req.get_body_data()

    if not body then
        ngx.status = 400
        ngx.header.content_type = "application/json"
        ngx.say(cjson.encode({
            success = false,
            error = "请提供请求体"
        }))
        return
    end

    local data = cjson.decode(body)
    if not data or not data.ip then
        ngx.status = 400
        ngx.header.content_type = "application/json"
        ngx.say(cjson.encode({
            success = false,
            error = "请提供 IP 地址"
        }))
        return
    end

    local result = routing_engine.query_geoip(data.ip)

    if result then
        ngx.header.content_type = "application/json"
        ngx.say(cjson.encode({
            success = true,
            data = result
        }))
    else
        ngx.status = 500
        ngx.header.content_type = "application/json"
        ngx.say(cjson.encode({
            success = false,
            error = "查询失败"
        }))
    end
end

-- 重载配置
function _M.reload_config()
    local ok, err = pcall(routing_engine.reload)

    if ok then
        local selected = routing_engine.get_selected_geoip_databases()
        ngx.header.content_type = "application/json"
        ngx.say(cjson.encode({
            success = true,
            message = "配置已重载",
            data = {
                selected_databases = selected
            }
        }))
    else
        ngx.status = 500
        ngx.header.content_type = "application/json"
        ngx.say(cjson.encode({
            success = false,
            error = "重载失败: " .. tostring(err)
        }))
    end
end

-- 路由分发
function _M.handle_request()
    local uri = ngx.var.uri
    local method = ngx.var.request_method

    -- GET /admin/geoip/databases - 获取所有数据库
    if uri == "/admin/geoip/databases" and method == "GET" then
        return _M.get_databases()

    -- GET /admin/geoip/selected - 获取选中的数据库
    elseif uri == "/admin/geoip/selected" and method == "GET" then
        return _M.get_selected_databases()

    -- GET /admin/geoip/validate - 验证数据库
    elseif uri == "/admin/geoip/validate" and method == "GET" then
        return _M.validate_databases()

    -- GET /admin/geoip/recommendations - 获取推荐
    elseif uri == "/admin/geoip/recommendations" and method == "GET" then
        return _M.get_recommendations()

    -- POST /admin/geoip/query - 测试查询
    elseif uri == "/admin/geoip/query" and method == "POST" then
        return _M.test_query()

    -- POST /admin/geoip/reload - 重载配置
    elseif uri == "/admin/geoip/reload" and method == "POST" then
        return _M.reload_config()

    else
        ngx.status = 404
        ngx.header.content_type = "application/json"
        ngx.say(cjson.encode({
            success = false,
            error = "API 不存在"
        }))
    end
end

return _M
