-- core/init.lua
-- OpenResty 初始化脚本

local _M = {}

function _M.init()
    -- 加载配置文件
    local config = require "conf.config"
    _G.CONFIG = config

    -- 初始化日志
    local logger = require "utils.logger"
    logger.info("Loading configuration...")
    logger.info("Redirect service: " .. config.server.base_url)

    -- 初始化 Redis 连接池
    local redis_client = require "storage.redis_client"
    redis_client.init(config.redis)
    logger.info("Redis initialized: " .. config.redis.host .. ":" .. config.redis.port)

    -- 初始化 MySQL 连接池
    local mysql_client = require "storage.mysql_client"
    mysql_client.init(config.mysql)
    logger.info("MySQL initialized: " .. config.mysql.host .. ":" .. config.mysql.port)

    -- 加载 GeoIP 数据库（测试环境暂时禁用）
    -- local geoip = require "utils.geoip"
    -- geoip.init(config.geoip)
    -- logger.info("GeoIP databases loaded")

    -- 初始化健康检查（测试环境暂时禁用，需要 resty.http 模块）
    -- local health_checker = require "core.health_checker"
    -- health_checker.start()
    -- logger.info("Health checker started")

    ngx.log(ngx.INFO, "OpenResty initialized successfully (simplified mode for testing)")
end

-- 在 init_by_lua 阶段调用
_M.init()

return _M
