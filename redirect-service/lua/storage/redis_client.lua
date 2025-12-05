-- storage/redis_client.lua
-- Redis 客户端模块

local redis = require "resty.redis"
local logger = require "utils.logger"

local _M = {}

local config = {
    host = "127.0.0.1",
    port = 6379,
    password = nil,
    database = 0,
    timeout = 5000,        -- 连接超时（毫秒）（优化：增加）
    pool_size = 200,       -- 连接池大小（优化：增大）
    max_idle_timeout = 30000, -- 最大空闲时间（毫秒）（优化：增加）
}

-- 本地缓存配置（L1 缓存）
local local_cache = ngx.shared.link_cache
local local_cache_ttl = 60  -- 本地缓存 TTL（秒）

-- 创建 Redis 连接
local function connect()
    local red = redis:new()
    red:set_timeout(config.timeout)

    local ok, err = red:connect(config.host, config.port)
    if not ok then
        return nil, "连接失败: " .. (err or "unknown")
    end

    -- 认证（只有当密码不为空时才进行认证）
    if config.password and config.password ~= "" then
        local res, err = red:auth(config.password)
        if not res then
            return nil, "认证失败: " .. (err or "unknown")
        end
    end

    -- 选择数据库
    if config.database ~= 0 then
        local res, err = red:select(config.database)
        if not res then
            return nil, "选择数据库失败: " .. (err or "unknown")
        end
    end

    return red, nil
end

-- 归还连接到连接池
local function keepalive(red)
    if not red then
        return
    end

    local ok, err = red:set_keepalive(config.max_idle_timeout, config.pool_size)
    if not ok then
        logger.warn("Redis keepalive失败: " .. (err or "unknown"))
    end
end

-- GET 操作（优化：添加本地缓存）
function _M.get(key)
    -- L1 缓存：先尝试从本地缓存获取
    if local_cache then
        local cached_value = local_cache:get(key)
        if cached_value then
            return cached_value, nil
        end
    end

    -- L2 缓存：从 Redis 获取
    local red, err = connect()
    if not red then
        logger.error("Redis连接失败: " .. err)
        return nil, err
    end

    local res, err = red:get(key)
    keepalive(red)

    if not res or res == ngx.null then
        return nil, "key不存在"
    end

    -- 写入本地缓存
    if local_cache and res then
        local_cache:set(key, res, local_cache_ttl)
    end

    return res, nil
end

-- SET 操作（优化：同步本地缓存）
function _M.set(key, value, ttl)
    local red, err = connect()
    if not red then
        logger.error("Redis连接失败: " .. err)
        return false, err
    end

    local res, err
    if ttl then
        res, err = red:setex(key, ttl, value)
    else
        res, err = red:set(key, value)
    end

    keepalive(red)

    if not res then
        logger.error("Redis SET失败: " .. (err or "unknown"))
        return false, err
    end

    -- 同步到本地缓存
    if local_cache and value then
        local cache_ttl = ttl or local_cache_ttl
        if cache_ttl > local_cache_ttl then
            cache_ttl = local_cache_ttl  -- 本地缓存时间不超过配置值
        end
        local_cache:set(key, value, cache_ttl)
    end

    return true, nil
end

-- DEL 操作（优化：清除本地缓存）
function _M.del(key)
    local red, err = connect()
    if not red then
        logger.error("Redis连接失败: " .. err)
        return false, err
    end

    local res, err = red:del(key)
    keepalive(red)

    if not res then
        logger.error("Redis DEL失败: " .. (err or "unknown"))
        return false, err
    end

    -- 清除本地缓存
    if local_cache then
        local_cache:delete(key)
    end

    return true, nil
end

-- INCR 操作
function _M.incr(key, ttl)
    local red, err = connect()
    if not red then
        logger.error("Redis连接失败: " .. err)
        return nil, err
    end

    local res, err = red:incr(key)
    if not res then
        keepalive(red)
        logger.error("Redis INCR失败: " .. (err or "unknown"))
        return nil, err
    end

    -- 如果是第一次计数，设置过期时间
    if ttl and res == 1 then
        red:expire(key, ttl)
    end

    keepalive(red)
    return res, nil
end

-- HGET 操作
function _M.hget(key, field)
    local red, err = connect()
    if not red then
        logger.error("Redis连接失败: " .. err)
        return nil, err
    end

    local res, err = red:hget(key, field)
    keepalive(red)

    if not res or res == ngx.null then
        return nil, "field不存在"
    end

    return res, nil
end

-- HGETALL 操作
function _M.hgetall(key)
    local red, err = connect()
    if not red then
        logger.error("Redis连接失败: " .. err)
        return nil, err
    end

    local res, err = red:hgetall(key)
    keepalive(red)

    if not res then
        logger.error("Redis HGETALL失败: " .. (err or "unknown"))
        return nil, err
    end

    -- 转换为 Lua 表
    local hash = {}
    for i = 1, #res, 2 do
        hash[res[i]] = res[i + 1]
    end

    return hash, nil
end

-- HSET 操作
function _M.hset(key, field, value)
    local red, err = connect()
    if not red then
        logger.error("Redis连接失败: " .. err)
        return false, err
    end

    local res, err = red:hset(key, field, value)
    keepalive(red)

    if not res then
        logger.error("Redis HSET失败: " .. (err or "unknown"))
        return false, err
    end

    return true, nil
end

-- 设置 key 过期时间（秒）
function _M.expire(key, seconds)
    local red, err = connect()
    if not red then
        logger.error("Redis连接失败: " .. err)
        return false, err
    end

    local res, err = red:expire(key, seconds)
    keepalive(red)

    if not res then
        logger.error("Redis EXPIRE失败: " .. (err or "unknown"))
        return false, err
    end

    return true, nil
end

-- 初始化配置
function _M.init(conf)
    if conf then
        for k, v in pairs(conf) do
            config[k] = v
        end
    end
end

return _M
