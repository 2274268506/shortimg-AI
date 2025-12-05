-- api/health.lua
-- 健康检查 API

local redis_client = require "storage.redis_client"
local mysql_client = require "storage.mysql_client"
local cjson = require "cjson.safe"

local _M = {}

local ngx_say = ngx.say

-- 检查 Redis 连接
local function check_redis()
    local ok, err = redis_client.get("health_check_ping")
    if err and err ~= "key不存在" then
        return false, err
    end
    return true, "ok"
end

-- 检查 MySQL 连接
local function check_mysql()
    local link, err = mysql_client.get_link("health_check")
    -- 即使查询结果为空，只要能连接就算健康
    if err and not err:match("不存在") then
        return false, err
    end
    return true, "ok"
end

-- 检查磁盘空间（简化版）
local function check_disk_space()
    -- 在容器环境中，可以通过挂载卷检查
    -- 这里简化处理，返回 ok
    return true, "ok"
end

-- 检查内存使用（Nginx shared dict）
local function check_memory()
    local short_links = ngx.shared.short_links
    if not short_links then
        return false, "shared dict not found"
    end

    local free_space = short_links:free_space()
    if free_space < 1024 * 1024 then  -- 少于1MB
        return false, "low memory: " .. free_space .. " bytes"
    end

    return true, "ok"
end

-- 完整健康检查
function _M.check()
    -- 获取或初始化服务启动时间
    local health_dict = ngx.shared.health_check
    local start_time = health_dict:get("start_time")
    if not start_time then
        start_time = ngx.time()
        health_dict:set("start_time", start_time)
    end

    local health = {
        status = "healthy",
        timestamp = ngx.time(),
        uptime = ngx.time() - start_time,
        checks = {}
    }

    -- 检查 Redis
    local redis_ok, redis_msg = check_redis()
    health.checks.redis = {
        status = redis_ok and "healthy" or "unhealthy",
        message = redis_msg
    }

    -- 检查 MySQL
    local mysql_ok, mysql_msg = check_mysql()

    health.checks.mysql = {
        status = mysql_ok and "healthy" or "unhealthy",
        message = mysql_msg
    }

    -- 检查磁盘
    local disk_ok, disk_msg = check_disk_space()
    health.checks.disk = {
        status = disk_ok and "healthy" or "unhealthy",
        message = disk_msg
    }

    -- 检查内存
    local memory_ok, memory_msg = check_memory()
    health.checks.memory = {
        status = memory_ok and "healthy" or "unhealthy",
        message = memory_msg
    }

    -- 判断整体健康状态
    if not redis_ok or not mysql_ok or not disk_ok or not memory_ok then
        health.status = "unhealthy"
        ngx.status = 503  -- Service Unavailable
    else
        ngx.status = 200
    end

    -- 返回 JSON
    ngx.header["Content-Type"] = "application/json"
    ngx_say(cjson.encode(health))
end

-- 简单的活跃性检查（liveness probe）
function _M.liveness()
    ngx.status = 200
    ngx.header["Content-Type"] = "text/plain"
    ngx_say("OK")
end

-- 就绪性检查（readiness probe）
function _M.readiness()
    -- 检查关键依赖
    local redis_ok = check_redis()
    local mysql_ok = check_mysql()

    if redis_ok and mysql_ok then
        ngx.status = 200
        ngx.header["Content-Type"] = "text/plain"
        ngx_say("Ready")
    else
        ngx.status = 503
        ngx.header["Content-Type"] = "text/plain"
        ngx_say("Not Ready")
    end
end

return _M
