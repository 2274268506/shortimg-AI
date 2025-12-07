-- api/stats_enhanced.lua
-- 增强的统计查询API

local mysql_client = require "storage.mysql_client"
local error_handler = require "utils.error_handler"
local cjson = require "cjson.safe"

local _M = {}

-- 获取总体统计
function _M.get_overview()
    return error_handler.safe_execute(function()
        local stats = {}

        -- 短链总数（按服务类型和状态）
        local service_stats = mysql_client.query([[
            SELECT service_type, status, COUNT(*) as count
            FROM short_links
            GROUP BY service_type, status
        ]])

        stats.by_service = {}
        stats.total = 0
        stats.active = 0
        stats.paused = 0
        stats.deleted = 0

        if service_stats then
            for _, row in ipairs(service_stats) do
                local service = row.service_type or "general"
                if not stats.by_service[service] then
                    stats.by_service[service] = {total = 0, active = 0, paused = 0, deleted = 0}
                end

                local count = tonumber(row.count) or 0
                stats.by_service[service].total = stats.by_service[service].total + count
                stats.by_service[service][row.status] = count

                stats.total = stats.total + count
                stats[row.status] = (stats[row.status] or 0) + count
            end
        end

        -- 今日访问量
        local today_visits = mysql_client.query([[
            SELECT COUNT(*) as count
            FROM access_logs
            WHERE DATE(created_at) = CURDATE()
        ]])
        stats.today_visits = (today_visits and today_visits[1] and tonumber(today_visits[1].count)) or 0

        -- 总访问量
        local total_visits = mysql_client.query("SELECT SUM(visit_count) as total FROM short_links")
        stats.total_visits = (total_visits and total_visits[1] and tonumber(total_visits[1].total)) or 0

        -- 即将过期（7天内）
        local expiring_soon = mysql_client.query([[
            SELECT COUNT(*) as count
            FROM short_links
            WHERE expires_at IS NOT NULL
            AND expires_at BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 7 DAY)
            AND status = 'active'
        ]])
        stats.expiring_soon = (expiring_soon and expiring_soon[1] and tonumber(expiring_soon[1].count)) or 0

        -- 已过期未清理
        local expired = mysql_client.query([[
            SELECT COUNT(*) as count
            FROM short_links
            WHERE expires_at IS NOT NULL
            AND expires_at < NOW()
            AND status != 'deleted'
        ]])
        stats.expired = (expired and expired[1] and tonumber(expired[1].count)) or 0

        return error_handler.respond_success(stats)
    end)
end

-- 获取服务类型统计
function _M.get_by_service(service_type)
    if not service_type or service_type == "" then
        error_handler.respond_error("MISSING_PARAMETER", "缺少service_type参数")
    end

    return error_handler.safe_execute(function()
        local stats = {}

        -- 基本统计
        local basic = mysql_client.query([[
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN status='active' THEN 1 ELSE 0 END) as active,
                SUM(CASE WHEN status='paused' THEN 1 ELSE 0 END) as paused,
                SUM(CASE WHEN status='deleted' THEN 1 ELSE 0 END) as deleted,
                SUM(visit_count) as total_visits,
                AVG(visit_count) as avg_visits
            FROM short_links
            WHERE service_type = ?
        ]], {service_type})

        if basic and basic[1] then
            stats.total = tonumber(basic[1].total) or 0
            stats.active = tonumber(basic[1].active) or 0
            stats.paused = tonumber(basic[1].paused) or 0
            stats.deleted = tonumber(basic[1].deleted) or 0
            stats.total_visits = tonumber(basic[1].total_visits) or 0
            stats.avg_visits = math.floor((tonumber(basic[1].avg_visits) or 0) * 100) / 100
        end

        -- Top 10 访问量最高的短链
        local top_links = mysql_client.query([[
            SELECT short_code, visit_count, created_at
            FROM short_links
            WHERE service_type = ? AND status = 'active'
            ORDER BY visit_count DESC
            LIMIT 10
        ]], {service_type})

        stats.top_links = top_links or {}

        -- 最近7天的创建趋势
        local trend = mysql_client.query([[
            SELECT DATE(created_at) as date, COUNT(*) as count
            FROM short_links
            WHERE service_type = ?
            AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
            GROUP BY DATE(created_at)
            ORDER BY date DESC
        ]], {service_type})

        stats.trend_7days = trend or {}

        -- 今日新增
        local today_new = mysql_client.query([[
            SELECT COUNT(*) as count
            FROM short_links
            WHERE service_type = ?
            AND DATE(created_at) = CURDATE()
        ]], {service_type})
        stats.today_new = (today_new and today_new[1] and tonumber(today_new[1].count)) or 0

        return error_handler.respond_success(stats)
    end)
end

-- 获取访问日志统计
function _M.get_access_stats()
    return error_handler.safe_execute(function()
        local args = ngx.req.get_uri_args()
        local short_code = args.short_code
        local days = tonumber(args.days) or 7

        if days > 90 then days = 90 end  -- 最多90天
        if days < 1 then days = 1 end

        local stats = {}

        if short_code then
            -- 特定短链的访问统计
            local daily = mysql_client.query([[
                SELECT
                    DATE(created_at) as date,
                    COUNT(*) as visits,
                    COUNT(DISTINCT client_ip) as unique_visitors
                FROM access_logs
                WHERE short_code = ?
                AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
                GROUP BY DATE(created_at)
                ORDER BY date DESC
            ]], {short_code, days})

            stats.daily = daily or {}

            -- 设备类型分布
            local devices = mysql_client.query([[
                SELECT device_type, COUNT(*) as count
                FROM access_logs
                WHERE short_code = ?
                AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
                GROUP BY device_type
            ]], {short_code, days})

            stats.devices = devices or {}

            -- 地域分布（Top 10）
            local regions = mysql_client.query([[
                SELECT country, province, city, COUNT(*) as count
                FROM access_logs
                WHERE short_code = ?
                AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
                AND country IS NOT NULL
                GROUP BY country, province, city
                ORDER BY count DESC
                LIMIT 10
            ]], {short_code, days})

            stats.regions = regions or {}

            -- 总计
            local total = mysql_client.query([[
                SELECT
                    COUNT(*) as total_visits,
                    COUNT(DISTINCT client_ip) as unique_visitors
                FROM access_logs
                WHERE short_code = ?
                AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
            ]], {short_code, days})

            if total and total[1] then
                stats.total_visits = tonumber(total[1].total_visits) or 0
                stats.unique_visitors = tonumber(total[1].unique_visitors) or 0
            end
        else
            -- 全局访问统计
            local daily = mysql_client.query([[
                SELECT
                    DATE(created_at) as date,
                    COUNT(*) as visits,
                    COUNT(DISTINCT client_ip) as unique_visitors
                FROM access_logs
                WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
                GROUP BY DATE(created_at)
                ORDER BY date DESC
            ]], {days})

            stats.daily = daily or {}

            -- 设备类型分布（全局）
            local devices = mysql_client.query([[
                SELECT device_type, COUNT(*) as count
                FROM access_logs
                WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
                GROUP BY device_type
            ]], {days})

            stats.devices = devices or {}
        end

        stats.days = days
        stats.short_code = short_code or "all"

        return error_handler.respond_success(stats)
    end)
end

return _M
