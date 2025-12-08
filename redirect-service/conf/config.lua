-- config.lua
-- 短链重定向服务配置文件
-- 说明：
--   1. CDN 节点和分流规则已移至 routing_rules.yaml
--   2. 短链域名由外部 Nginx 配置，应用层不需要配置
--   3. 此文件仅包含基础设施配置（Redis, MySQL, GeoIP 等）

local _M = {}

-- Redis 配置
_M.redis = {
    host = os.getenv("REDIS_HOST") or "127.0.0.1",
    port = tonumber(os.getenv("REDIS_PORT")) or 6379,
    password = os.getenv("REDIS_PASSWORD") or nil,
    database = tonumber(os.getenv("REDIS_DATABASE")) or 0,
    timeout = 1000,
    pool_size = 100,
    max_idle_timeout = 10000,
}

-- MySQL 配置
_M.mysql = {
    host = os.getenv("MYSQL_HOST") or "127.0.0.1",
    port = tonumber(os.getenv("MYSQL_PORT")) or 3306,
    database = os.getenv("MYSQL_DATABASE") or "short_links",
    user = os.getenv("MYSQL_USER") or "root",
    password = os.getenv("MYSQL_PASSWORD") or "",
    charset = "utf8mb4",
    timeout = 3000,
    pool_size = 100,
    max_idle_timeout = 10000,
}

-- GeoIP 数据库路径
_M.geoip = {
    geo_db_path = os.getenv("GEOIP_CITY_DB") or "/usr/local/openresty/nginx/geoip/GeoLite2-City.mmdb",
    asn_db_path = os.getenv("GEOIP_ASN_DB") or "/usr/local/openresty/nginx/geoip/GeoLite2-ASN.mmdb",
}

-- 日志配置
_M.log_level = os.getenv("LOG_LEVEL") or "info"

-- 缓存配置
_M.cache = {
    local_ttl = tonumber(os.getenv("CACHE_LOCAL_TTL")) or 300,   -- 5分钟
    redis_ttl = tonumber(os.getenv("CACHE_REDIS_TTL")) or 3600,  -- 1小时
}

-- 安全配置
_M.security = {
    default_token_secret = os.getenv("DEFAULT_TOKEN_SECRET") or "change-me-in-production",
    token_expire = tonumber(os.getenv("TOKEN_EXPIRE")) or 3600,
    rate_limit = {
        enabled = true,
        max_requests = tonumber(os.getenv("RATE_LIMIT_MAX")) or 100,
        window = tonumber(os.getenv("RATE_LIMIT_WINDOW")) or 60,
    },
}

-- 健康检查配置
_M.health_check = {
    interval = tonumber(os.getenv("HEALTH_CHECK_INTERVAL")) or 5,
    timeout = tonumber(os.getenv("HEALTH_CHECK_TIMEOUT")) or 2000,
    fall = tonumber(os.getenv("HEALTH_CHECK_FALL")) or 3,
    rise = tonumber(os.getenv("HEALTH_CHECK_RISE")) or 2,
    http_path = os.getenv("HEALTH_CHECK_PATH") or "/health",
}

-- 管理 API 配置
_M.admin = {
    enabled = os.getenv("ADMIN_AUTH_ENABLED") == "true",
    username = os.getenv("ADMIN_USERNAME") or "admin",
    password = os.getenv("ADMIN_PASSWORD") or "admin123",
}

return _M
