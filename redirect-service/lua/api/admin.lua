-- api/admin.lua
-- 管理 API 模块

local cjson = require "cjson.safe"
local mysql_client = require "storage.mysql_client"
local redis_client = require "storage.redis_client"
local logger = require "utils.logger"

local _M = {}

local ngx_req = ngx.req
local ngx_say = ngx.say
local ngx_exit = ngx.exit

-- 响应 JSON
local function respond_json(data, status)
    status = status or 200
    ngx.status = status
    ngx.header["Content-Type"] = "application/json"
    ngx_say(cjson.encode(data))
    return ngx_exit(status)
end

-- 错误响应
local function respond_error(message, status)
    return respond_json({
        success = false,
        error = message
    }, status or 400)
end

-- 成功响应
local function respond_success(data)
    return respond_json({
        success = true,
        data = data
    }, 200)
end

-- 读取请求体
local function read_body()
    ngx_req.read_body()
    local body = ngx_req.get_body_data()

    if not body then
        return nil, "请求体为空"
    end

    local data, err = cjson.decode(body)
    if not data then
        return nil, "JSON 解析失败: " .. (err or "unknown")
    end

    return data, nil
end

-- 创建短链
function _M.create()
    local data, err = read_body()
    if not data then
        return respond_error(err)
    end

    -- 验证必填字段
    if not data.short_code or not data.targets or #data.targets == 0 then
        return respond_error("缺少必填字段: short_code, targets")
    end

    -- 检查短码是否已存在
    local existing, err = mysql_client.get_link(data.short_code)
    if existing then
        return respond_error("短码已存在", 409)
    end

    -- 创建短链
    local id, err = mysql_client.create_link(data)
    if not id then
        logger.error("创建短链失败: " .. err)
        return respond_error("创建失败: " .. err, 500)
    end

    -- 清除缓存
    redis_client.del("link:" .. data.short_code)

    logger.info("创建短链成功: " .. data.short_code)
    return respond_success({
        id = id,
        short_code = data.short_code
    })
end

-- 获取短链
function _M.get()
    -- 从 URI 中提取 short_code
    local uri = ngx.var.uri
    local short_code = uri:match("^/api/v1/links/([^/]+)$")

    if not short_code then
        return respond_error("缺少 short_code 参数")
    end

    local link, err = mysql_client.get_link(short_code)
    if not link then
        return respond_error("短链不存在", 404)
    end

    return respond_success(link)
end

-- 更新短链
function _M.update()
    -- 从 URI 中提取 short_code
    local uri = ngx.var.uri
    local short_code = uri:match("^/api/v1/links/([^/]+)$")

    if not short_code then
        return respond_error("缺少 short_code 参数")
    end

    local data, err = read_body()
    if not data then
        return respond_error(err)
    end

    -- 更新短链
    local ok, err = mysql_client.update_link(short_code, data)
    if not ok then
        logger.error("更新短链失败: " .. err)
        return respond_error("更新失败: " .. err, 500)
    end

    -- 清除缓存
    redis_client.del("link:" .. short_code)

    logger.info("更新短链成功: " .. short_code)
    return respond_success({
        short_code = short_code
    })
end

-- 删除短链
function _M.delete()
    -- 从 URI 中提取 short_code
    local uri = ngx.var.uri
    local short_code = uri:match("^/api/v1/links/([^/]+)$")

    if not short_code then
        return respond_error("缺少 short_code 参数")
    end

    local ok, err = mysql_client.delete_link(short_code)
    if not ok then
        logger.error("删除短链失败: " .. err)
        return respond_error("删除失败: " .. err, 500)
    end

    -- 清除缓存
    redis_client.del("link:" .. short_code)

    logger.info("删除短链成功: " .. short_code)
    return respond_success({
        short_code = short_code
    })
end

-- 热重载配置
function _M.reload()
    -- 清除所有缓存
    local ngx_shared = ngx.shared
    if ngx_shared.short_links then
        ngx_shared.short_links:flush_all()
    end

    logger.info("配置热重载成功")
    return respond_success({
        message = "配置已重载"
    })
end

-- 路由处理
function _M.handle()
    local uri = ngx.var.uri
    local method = ngx.var.request_method

    -- 短链 CRUD API
    if uri == "/api/v1/links" and method == "POST" then
        return _M.create()
    elseif uri:match("^/api/v1/links/([^/]+)$") and method == "GET" then
        return _M.get()
    elseif uri:match("^/api/v1/links/([^/]+)$") and method == "PUT" then
        return _M.update()
    elseif uri:match("^/api/v1/links/([^/]+)$") and method == "DELETE" then
        return _M.delete()
    elseif uri == "/api/v1/reload" and method == "POST" then
        return _M.reload()
    else
        return respond_error("API 不存在", 404)
    end
end

return _M
