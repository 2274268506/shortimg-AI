-- core/router.lua
-- 短链路由核心逻辑

local config = require "conf.config"
local redis_client = require "storage.redis_client"
local mysql_client = require "storage.mysql_client"
local strategies = require "strategies.strategy_manager"
-- local health_checker = require "core.health_checker"  -- 已禁用（缺少依赖模块）
local logger = require "utils.logger"
local metrics = require "utils.metrics"

local ngx_var = ngx.var
local ngx_say = ngx.say
local ngx_exit = ngx.exit
local ngx_redirect = ngx.redirect
local ngx_shared = ngx.shared
local ngx_time = ngx.time

local _M = {}

-- 检测设备类型
local function detect_device_type(user_agent)
    if not user_agent then
        return "unknown"
    end

    user_agent = user_agent:lower()

    if user_agent:match("mobile") or user_agent:match("android") or
       user_agent:match("iphone") or user_agent:match("ipod") then
        return "mobile"
    elseif user_agent:match("tablet") or user_agent:match("ipad") then
        return "tablet"
    else
        return "desktop"
    end
end

-- 获取客户端真实IP（支持NAT/代理环境）
local function get_real_client_ip()
    -- 1. 优先从 X-Forwarded-For 获取（多层代理时取第一个）
    local xff = ngx_var.http_x_forwarded_for
    if xff then
        -- X-Forwarded-For 格式: client, proxy1, proxy2
        -- 取第一个IP（真实客户端IP）
        local first_ip = xff:match("([^,]+)")
        if first_ip then
            return first_ip:match("^%s*(.-)%s*$") -- 去除空格
        end
    end

    -- 2. 尝试从 X-Real-IP 获取
    local real_ip = ngx_var.http_x_real_ip
    if real_ip then
        return real_ip
    end

    -- 3. 降级到 remote_addr（直连情况）
    return ngx_var.remote_addr
end

-- 获取客户端信息
local function get_client_info()
    local client_ip = get_real_client_ip()

    local info = {
        ip = client_ip,
        user_agent = ngx_var.http_user_agent,
        referer = ngx_var.http_referer,
        request_uri = ngx_var.request_uri,
        -- GeoIP 信息（需要 ngx_http_geoip2_module）
        country = ngx_var.geoip2_data_country_code or "UNKNOWN",
        province = ngx_var.geoip2_data_province_name or "UNKNOWN",
        city = ngx_var.geoip2_data_city_name or "UNKNOWN",
        isp = ngx_var.geoip2_data_isp or "UNKNOWN",
        asn = ngx_var.geoip2_data_asn or "UNKNOWN",
        -- 设备类型检测
        device_type = detect_device_type(ngx_var.http_user_agent)
    }
    return info
end

-- 从缓存获取短链信息
local function get_link_from_cache(short_code)
    local cache = ngx_shared.short_links
    local cache_key = "link:" .. short_code

    local data = cache:get(cache_key)
    if data then
        metrics.incr("cache_hit")
        return require("cjson").decode(data)
    end

    metrics.incr("cache_miss")
    return nil
end

-- 设置缓存
local function set_link_cache(short_code, link_data)
    local cache = ngx_shared.short_links
    local cache_key = "link:" .. short_code
    local expire_time = 300 -- 5分钟

    local ok, err = cache:set(cache_key, require("cjson").encode(link_data), expire_time)
    if not ok then
        logger.error("Failed to set cache: " .. (err or "unknown"))
    end
end

-- 从数据库获取短链信息
local function get_link_from_db(short_code)
    -- 先尝试从 Redis 获取
    local redis_key = "short_link:" .. short_code
    local data, err = redis_client.get(redis_key)

    if data and data ~= ngx.null then
        local link_data = require("cjson").decode(data)
        return link_data
    end

    -- Redis 未命中，从 MySQL 获取
    local link_data, err = mysql_client.get_link(short_code)

    if link_data then
        -- 写入 Redis 缓存
        redis_client.set(redis_key, require("cjson").encode(link_data), 3600)
        return link_data
    end

    return nil
end

-- 安全检查
local function security_check(link_data, client_info)
    local security = link_data.security_config or {}

    -- Referer 白名单检查
    if security.referer_whitelist and #security.referer_whitelist > 0 then
        local referer = client_info.referer or ""
        local allowed = false

        for _, pattern in ipairs(security.referer_whitelist) do
            if referer:match(pattern) then
                allowed = true
                break
            end
        end

        if not allowed then
            logger.warn("Referer not in whitelist: " .. referer)
            return false, "Access denied: invalid referer"
        end
    end

    -- Token 验证
    if security.token_required then
        local token = ngx_var.arg_token
        if not token then
            return false, "Access denied: token required"
        end

        -- 验证 token（示例：简单的时间戳 + 签名）
        local valid = verify_token(token, link_data.short_code)
        if not valid then
            return false, "Access denied: invalid token"
        end
    end

    -- IP 黑名单检查
    if security.ip_blacklist and #security.ip_blacklist > 0 then
        for _, ip in ipairs(security.ip_blacklist) do
            if client_info.ip == ip then
                logger.warn("IP in blacklist: " .. ip)
                return false, "Access denied: blocked IP"
            end
        end
    end

    return true
end

-- Token 验证（示例实现）
local function verify_token(token, short_code)
    -- 实际项目中应使用更安全的签名算法（HMAC-SHA256）
    local secret = CONFIG.token_secret or "default_secret"
    local parts = {}
    for part in token:gmatch("[^:]+") do
        table.insert(parts, part)
    end

    if #parts ~= 2 then
        return false
    end

    local timestamp, signature = parts[1], parts[2]
    local expected_sig = ngx.md5(short_code .. timestamp .. secret)

    -- 检查签名
    if signature ~= expected_sig then
        return false
    end

    -- 检查是否过期（默认1小时）
    local now = ngx_time()
    if now - tonumber(timestamp) > 3600 then
        return false
    end

    return true
end

-- 选择目标服务器
local function select_target(link_data, client_info)
    local targets = link_data.targets
    if not targets or #targets == 0 then
        return nil
    end

    -- 过滤健康的服务器
    local healthy_targets = {}
    for _, target in ipairs(targets) do
        -- 生成完整URL（支持三种方式）
        local target_url
        if target.url then
            -- 方式1: 直接使用完整URL（通用短链）
            target_url = target.url
        elseif target.cdn and target.path then
            -- 方式2: 使用指定CDN标识 + 路径
            target_url = config.get_cdn_url(target.cdn, target.path)
        elseif target.path then
            -- 方式3: 只有路径，根据GeoIP自动选择CDN（图床等服务）
            local client_ip = client_info.ip or ngx.var.remote_addr
            local cdn_name = config.select_cdn_by_geo(client_ip)
            logger.info("GeoIP分流: IP=" .. client_ip .. " CDN=" .. cdn_name)
            target_url = config.get_cdn_url(cdn_name, target.path)
        else
            logger.warn("Invalid target config: missing url or path")
            goto continue
        end

        -- 健康检查（已禁用）
        -- if health_checker.is_healthy(target_url) then
            -- 创建带完整URL的target副本
            local healthy_target = {}
            for k, v in pairs(target) do
                healthy_target[k] = v
            end
            healthy_target.url = target_url
            table.insert(healthy_targets, healthy_target)
        -- end

        ::continue::
    end

    if #healthy_targets == 0 then
        logger.warn("No healthy targets available")
        -- 返回降级 URL
        if link_data.fallback_url then
            return link_data.fallback_url
        end
        -- 如果没有降级URL，尝试使用第一个目标（忽略健康检查）
        if #targets > 0 then
            local first_target = targets[1]
            if first_target.url then
                return first_target.url
            elseif first_target.cdn and first_target.path then
                local config = require "conf.config"
                return config.get_cdn_url(first_target.cdn, first_target.path)
            end
        end
        return nil
    end

    -- 根据策略选择目标
    local strategy_name = link_data.strategy or "round_robin"
    local target = strategies.select(strategy_name, healthy_targets, client_info)

    return target and target.url or healthy_targets[1].url
end

-- 访问控制阶段
function _M.access()
    local short_code = ngx_var.short_code

    if not short_code or short_code == "" then
        ngx_exit(400)
        return
    end

    -- 限流检查（性能优化：提高限制）
    local rate_limit = ngx_shared.rate_limit
    local key = "rate:" .. ngx_var.remote_addr
    local count = rate_limit:get(key) or 0

    if count > 10000 then -- 每分钟最多10000次请求（性能测试模式）
        logger.warn("Rate limit exceeded: " .. ngx_var.remote_addr)
        ngx_exit(429)
        return
    end

    rate_limit:incr(key, 1, 0, 60) -- 60秒过期
end

-- 重定向处理
function _M.redirect()
    local short_code = ngx_var.short_code
    local client_info = get_client_info()

    -- 获取短链信息
    local link_data = get_link_from_cache(short_code)
    if not link_data then
        link_data = get_link_from_db(short_code)
    end

    if not link_data then
        logger.info("Short code not found: " .. short_code)
        ngx_exit(404)
        return
    end

    -- 安全检查
    local ok, err = security_check(link_data, client_info)
    if not ok then
        ngx_say(err)
        ngx_exit(403)
        return
    end

    -- 选择目标服务器
    local target_url = select_target(link_data, client_info)

    if not target_url then
        logger.error("Failed to select target for: " .. short_code)
        -- 使用降级 URL
        target_url = link_data.fallback_url or CONFIG.default_fallback_url
    end

    -- 记录访问日志（异步）
    ngx.timer.at(0, function()
        logger.log_access({
            short_code = short_code,
            client_info = client_info,
            target_url = target_url,
            timestamp = ngx_time()
        })

        -- 更新统计
        metrics.incr("redirect_count")
        metrics.incr("redirect:" .. short_code)
    end)

    -- 执行 302 重定向
    return ngx_redirect(target_url, 302)
end

return _M
