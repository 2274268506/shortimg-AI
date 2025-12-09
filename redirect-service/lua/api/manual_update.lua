-- 手动触发访问计数更新的脚本
-- 这个脚本可以通过curl调用来立即更新visit_count

local mysql_client = require("storage.mysql_client")
local logger = require("logger.logger")

local _M = {}

function _M.trigger_update()
    logger.info("手动触发访问计数更新...")

    local sql = [[
        UPDATE short_links sl
        SET visit_count = (
            SELECT COUNT(*)
            FROM access_logs al
            WHERE al.short_code = sl.short_code
        )
    ]]

    local result, err = mysql_client.query(sql)
    if err then
        logger.error("更新访问计数失败: " .. err)
        ngx.say("ERROR: ", err)
        return
    end

    -- 查询更新后的统计
    local stats_sql = [[
        SELECT 
            COUNT(*) as total_links,
            SUM(visit_count) as total_visits,
            MAX(visit_count) as max_visits
        FROM short_links 
        WHERE status != 'deleted'
    ]]
    
    local stats, err2 = mysql_client.query(stats_sql)
    if err2 then
        logger.error("查询统计失败: " .. err2)
    end

    local cjson = require("cjson")
    ngx.say(cjson.encode({
        success = true,
        message = "访问计数更新完成",
        stats = stats[1]
    }))
end

return _M
