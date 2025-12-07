-- config.lua
-- 短链重定向服务配置文件

local _M = {}

-- 重定向服务器配置
_M.server = {
    -- 重定向服务域名（可配置）
    domain = os.getenv("REDIRECT_DOMAIN") or "short.example.com",
    -- 重定向服务协议
    protocol = os.getenv("REDIRECT_PROTOCOL") or "https",
}

-- 自动生成完整URL前缀
_M.server.base_url = _M.server.protocol .. "://" .. _M.server.domain

-- 目标服务器配置（CDN服务器域名）
_M.cdn_servers = {
    -- 北方电信 CDN
    north_telecom = {
        domain = os.getenv("CDN_NORTH_TELECOM_DOMAIN") or "cdn-north.example.com",
        protocol = os.getenv("CDN_NORTH_TELECOM_PROTOCOL") or "https",
    },
    -- 南方联通 CDN
    south_unicom = {
        domain = os.getenv("CDN_SOUTH_UNICOM_DOMAIN") or "cdn-south.example.com",
        protocol = os.getenv("CDN_SOUTH_UNICOM_PROTOCOL") or "https",
    },
    -- 海外 CDN
    overseas = {
        domain = os.getenv("CDN_OVERSEAS_DOMAIN") or "cdn-overseas.example.com",
        protocol = os.getenv("CDN_OVERSEAS_PROTOCOL") or "https",
    },
    -- TC-GO 图床主服务器
    tc_go_primary = {
        domain = os.getenv("TC_GO_PRIMARY_DOMAIN") or "imagebed.example.com",
        protocol = os.getenv("TC_GO_PRIMARY_PROTOCOL") or "https",
    },
    -- TC-GO 图床备用服务器
    tc_go_backup = {
        domain = os.getenv("TC_GO_BACKUP_DOMAIN") or "imagebed-backup.example.com",
        protocol = os.getenv("TC_GO_BACKUP_PROTOCOL") or "https",
    },
    -- 降级服务器
    fallback = {
        domain = os.getenv("CDN_FALLBACK_DOMAIN") or "cdn-fallback.example.com",
        protocol = os.getenv("CDN_FALLBACK_PROTOCOL") or "https",
    },
    -- 默认服务器（指向fallback）
    default = {
        domain = os.getenv("CDN_FALLBACK_DOMAIN") or "cdn-fallback.example.com",
        protocol = os.getenv("CDN_FALLBACK_PROTOCOL") or "https",
    },
    -- 私有CDN（开发环境）
    private = {
        domain = os.getenv("CDN_PRIVATE_DOMAIN") or "localhost",
        port = os.getenv("CDN_PRIVATE_PORT"),  -- 可选端口
        protocol = os.getenv("CDN_PRIVATE_PROTOCOL") or "http",
    },
    -- 公共CDN（生产环境）
    public = {
        domain = os.getenv("CDN_PUBLIC_DOMAIN") or "dxy.oxvxo.net",
        port = os.getenv("CDN_PUBLIC_PORT") or "18443",
        protocol = os.getenv("CDN_PUBLIC_PROTOCOL") or "https",
    },
}

-- CDN分流模式配置
_M.cdn_routing_mode = os.getenv("CDN_ROUTING_MODE") or "auto"
-- 可选值:
--   "auto"   - 自动GeoIP分流（默认，根据客户端IP判断）
--   "public" - 强制使用public CDN（适用于公网服务，NAT环境）
--   "private" - 强制使用private CDN（适用于内网服务）

-- 生成完整 CDN URL 的辅助函数
function _M.get_cdn_url(cdn_name, path)
    local cdn = _M.cdn_servers[cdn_name]
    if not cdn then
        cdn = _M.cdn_servers.fallback
    end

    -- 确保路径以 / 开头
    if not path:match("^/") then
        path = "/" .. path
    end

    -- 构建URL（带端口号如果存在）
    local url = cdn.protocol .. "://" .. cdn.domain
    if cdn.port and cdn.port ~= "" then
        url = url .. ":" .. cdn.port
    end
    url = url .. path

    return url
end

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

-- ==================== GeoIP分流函数 ====================

-- 判断是否为私有IP地址
function _M.is_private_ip(ip)
    if not ip then return false end

    -- 匹配 10.0.0.0/8
    if ip:match("^10%.") then
        return true
    end

    -- 匹配 172.16.0.0/12
    local second = ip:match("^172%.(%d+)%.")
    if second then
        local num = tonumber(second)
        if num >= 16 and num <= 31 then
            return true
        end
    end

    -- 匹配 192.168.0.0/16
    if ip:match("^192%.168%.") then
        return true
    end

    -- 匹配 127.0.0.0/8 (localhost)
    if ip:match("^127%.") then
        return true
    end

    return false
end

-- 根据客户端IP选择CDN服务器
function _M.select_cdn_by_geo(client_ip)
    local logger = require "utils.logger"

    -- 检查是否强制模式
    if _M.cdn_routing_mode == "public" then
        logger.info("CDN分流: 强制模式=public -> CDN=public")
        return "public"
    elseif _M.cdn_routing_mode == "private" then
        logger.info("CDN分流: 强制模式=private -> CDN=private")
        return "private"
    end

    -- auto模式：根据IP判断
    -- 私有IP使用private CDN（开发环境）
    if _M.is_private_ip(client_ip) then
        logger.info("GeoIP分流: IP=" .. (client_ip or "nil") .. " 判定为私有IP -> CDN=private")
        return "private"
    end

    -- 公网IP使用public CDN（生产环境）
    logger.info("GeoIP分流: IP=" .. (client_ip or "nil") .. " 判定为公网IP -> CDN=public")
    return "public"
end

return _M
