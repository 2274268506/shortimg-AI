-- api/stats_advanced.lua
-- 高级统计分析 API

local mysql_client = require "storage.mysql_client"
local redis_client = require "storage.redis_client"
local cjson = require "cjson.safe"

local _M = {}

-- 时间范围统计
function _M.get_time_range_stats(short_code, start_time, end_time)
    local sql = [[
        SELECT
            DATE(created_at) as date,
            COUNT(*) as total_visits,
            COUNT(DISTINCT ip_address) as unique_visitors,
            COUNT(DISTINCT CONCAT(country, '-', province)) as unique_regions,
            AVG(response_time) as avg_response_time
        FROM access_logs
        WHERE short_code = ?
        AND created_at BETWEEN FROM_UNIXTIME(?) AND FROM_UNIXTIME(?)
        GROUP BY DATE(created_at)
        ORDER BY date
    ]]

    local result, err = mysql_client.query(sql, {short_code, start_time, end_time})
    if err then
        return nil, err
    end

    return result
end

-- 地理分布统计
function _M.get_geo_distribution(short_code, limit)
    limit = limit or 20

    local sql = [[
        SELECT
            country,
            province,
            city,
            COUNT(*) as visit_count,
            COUNT(DISTINCT ip_address) as unique_visitors
        FROM access_logs
        WHERE short_code = ?
        GROUP BY country, province, city
        ORDER BY visit_count DESC
        LIMIT ?
    ]]

    local result, err = mysql_client.query(sql, {short_code, limit})
    if err then
        return nil, err
    end

    return result
end

-- ISP 分布统计
function _M.get_isp_distribution(short_code)
    local sql = [[
        SELECT
            isp,
            COUNT(*) as visit_count,
            COUNT(DISTINCT ip_address) as unique_visitors,
            AVG(response_time) as avg_response_time
        FROM access_logs
        WHERE short_code = ?
        GROUP BY isp
        ORDER BY visit_count DESC
    ]]

    local result, err = mysql_client.query(sql, {short_code})
    if err then
        return nil, err
    end

    return result
end

-- 设备类型统计
function _M.get_device_stats(short_code)
    local sql = [[
        SELECT
            device_type,
            COUNT(*) as visit_count,
            COUNT(DISTINCT ip_address) as unique_visitors,
            AVG(response_time) as avg_response_time
        FROM access_logs
        WHERE short_code = ?
        GROUP BY device_type
        ORDER BY visit_count DESC
    ]]

    local result, err = mysql_client.query(sql, {short_code})
    if err then
        return nil, err
    end

    return result
end

-- 浏览器统计
function _M.get_browser_stats(short_code)
    local sql = [[
        SELECT
            user_agent,
            COUNT(*) as visit_count
        FROM access_logs
        WHERE short_code = ?
        GROUP BY user_agent
        ORDER BY visit_count DESC
        LIMIT 50
    ]]

    local result, err = mysql_client.query(sql, {short_code})
    if err then
        return nil, err
    end

    -- 简单解析 User-Agent
    for i, row in ipairs(result) do
        local ua = row.user_agent or ""

        -- 检测浏览器
        if ua:match("Chrome") and not ua:match("Edge") then
            row.browser = "Chrome"
        elseif ua:match("Firefox") then
            row.browser = "Firefox"
        elseif ua:match("Safari") and not ua:match("Chrome") then
            row.browser = "Safari"
        elseif ua:match("Edge") then
            row.browser = "Edge"
        else
            row.browser = "Other"
        end

        -- 检测操作系统
        if ua:match("Windows") then
            row.os = "Windows"
        elseif ua:match("Mac OS") then
            row.os = "macOS"
        elseif ua:match("Linux") then
            row.os = "Linux"
        elseif ua:match("Android") then
            row.os = "Android"
        elseif ua:match("iPhone") or ua:match("iPad") then
            row.os = "iOS"
        else
            row.os = "Other"
        end
    end

    return result
end

-- Referer 来源统计
function _M.get_referer_stats(short_code, limit)
    limit = limit or 20

    local sql = [[
        SELECT
            referer,
            COUNT(*) as visit_count,
            COUNT(DISTINCT ip_address) as unique_visitors
        FROM access_logs
        WHERE short_code = ?
        AND referer IS NOT NULL
        AND referer != ''
        GROUP BY referer
        ORDER BY visit_count DESC
        LIMIT ?
    ]]

    local result, err = mysql_client.query(sql, {short_code, limit})
    if err then
        return nil, err
    end

    return result
end

-- 时段分布统计（按小时）
function _M.get_hourly_distribution(short_code)
    local sql = [[
        SELECT
            HOUR(created_at) as hour,
            COUNT(*) as visit_count,
            COUNT(DISTINCT ip_address) as unique_visitors
        FROM access_logs
        WHERE short_code = ?
        GROUP BY HOUR(created_at)
        ORDER BY hour
    ]]

    local result, err = mysql_client.query(sql, {short_code})
    if err then
        return nil, err
    end

    return result
end

-- 星期分布统计
function _M.get_weekday_distribution(short_code)
    local sql = [[
        SELECT
            DAYNAME(created_at) as weekday,
            DAYOFWEEK(created_at) as day_num,
            COUNT(*) as visit_count,
            COUNT(DISTINCT ip_address) as unique_visitors
        FROM access_logs
        WHERE short_code = ?
        GROUP BY weekday, day_num
        ORDER BY day_num
    ]]

    local result, err = mysql_client.query(sql, {short_code})
    if err then
        return nil, err
    end

    return result
end

-- 综合统计仪表板
function _M.get_dashboard_stats(short_code, days)
    days = days or 7
    local start_time = ngx.time() - (days * 24 * 3600)

    local dashboard = {}

    -- 总体统计
    local sql_total = [[
        SELECT
            COUNT(*) as total_visits,
            COUNT(DISTINCT ip_address) as unique_visitors,
            AVG(response_time) as avg_response_time,
            MIN(created_at) as first_visit,
            MAX(created_at) as last_visit
        FROM access_logs
        WHERE short_code = ?
        AND created_at >= FROM_UNIXTIME(?)
    ]]

    local total_stats, err = mysql_client.query(sql_total, {short_code, start_time})
    if err then
        return nil, err
    end
    dashboard.total = total_stats[1] or {}

    -- 今日统计
    local today_start = ngx.time() - (ngx.time() % 86400)
    local sql_today = [[
        SELECT
            COUNT(*) as visits_today,
            COUNT(DISTINCT ip_address) as visitors_today
        FROM access_logs
        WHERE short_code = ?
        AND created_at >= FROM_UNIXTIME(?)
    ]]

    local today_stats, err = mysql_client.query(sql_today, {short_code, today_start})
    if err then
        return nil, err
    end
    dashboard.today = today_stats[1] or {}

    -- Top 5 地区
    dashboard.top_regions = _M.get_geo_distribution(short_code, 5)

    -- Top 5 ISP
    local isp_stats = _M.get_isp_distribution(short_code)
    dashboard.top_isps = {}
    for i = 1, math.min(5, #isp_stats) do
        table.insert(dashboard.top_isps, isp_stats[i])
    end

    -- 设备类型分布
    dashboard.device_distribution = _M.get_device_stats(short_code)

    -- 每日趋势
    dashboard.daily_trend = _M.get_time_range_stats(short_code, start_time, ngx.time())

    return dashboard
end

-- 实时统计（基于 Redis）
function _M.get_realtime_stats(short_code)
    local stats = {
        short_code = short_code,
        last_5min = 0,
        last_15min = 0,
        last_hour = 0,
        active_visitors = 0
    }

    local now = ngx.time()

    -- 从 Redis 获取最近访问记录
    local key_prefix = "access:realtime:" .. short_code .. ":"

    -- 统计不同时间段的访问量
    local time_ranges = {
        {name = "last_5min", seconds = 300},
        {name = "last_15min", seconds = 900},
        {name = "last_hour", seconds = 3600}
    }

    for _, range in ipairs(time_ranges) do
        local count = 0
        local start_time = now - range.seconds

        -- 这里简化处理，实际应该使用 Redis Sorted Set
        local key = key_prefix .. range.name
        local value, err = redis_client.get(key)

        if value and value ~= ngx.null then
            count = tonumber(value) or 0
        end

        stats[range.name] = count
    end

    -- 活跃访客数（基于 IP 去重）
    local active_key = "active:visitors:" .. short_code
    local active_count, err = redis_client.scard(active_key)
    stats.active_visitors = active_count or 0

    return stats
end

-- 导出统计数据（CSV 格式）
function _M.export_stats(short_code, start_time, end_time, format)
    format = format or "csv"

    local sql = [[
        SELECT
            created_at,
            ip_address,
            country,
            province,
            city,
            isp,
            device_type,
            user_agent,
            referer,
            target_url,
            response_time,
            status_code
        FROM access_logs
        WHERE short_code = ?
        AND created_at BETWEEN FROM_UNIXTIME(?) AND FROM_UNIXTIME(?)
        ORDER BY created_at DESC
    ]]

    local result, err = mysql_client.query(sql, {short_code, start_time, end_time})
    if err then
        return nil, err
    end

    if format == "csv" then
        local csv_lines = {}

        -- CSV 头部
        table.insert(csv_lines, "访问时间,IP地址,国家,省份,城市,ISP,设备类型,User-Agent,来源,目标URL,响应时间,状态码")

        -- 数据行
        for _, row in ipairs(result) do
            local line = string.format('%s,"%s","%s","%s","%s","%s","%s","%s","%s","%s",%s,%s',
                row.created_at or "",
                row.ip_address or "",
                row.country or "",
                row.province or "",
                row.city or "",
                row.isp or "",
                row.device_type or "",
                (row.user_agent or ""):gsub('"', '""'),  -- 转义引号
                (row.referer or ""):gsub('"', '""'),
                (row.target_url or ""):gsub('"', '""'),
                row.response_time or "0",
                row.status_code or "200"
            )
            table.insert(csv_lines, line)
        end

        return table.concat(csv_lines, "\n")
    elseif format == "json" then
        return cjson.encode(result)
    else
        return nil, "Unsupported format: " .. format
    end
end

return _M

