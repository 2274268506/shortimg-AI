-- core/scheduler.lua
-- 定时任务调度器

local mysql_client = require "storage.mysql_client"
local redis_client = require "storage.redis_client"

local _M = {}

-- 清理过期短链
local function clean_expired_links()
    ngx.log(ngx.INFO, "开始清理过期短链...")

    local sql = [[
        UPDATE short_links
        SET status = 'expired', updated_at = NOW()
        WHERE status = 'active'
        AND expires_at > 0
        AND expires_at < UNIX_TIMESTAMP()
    ]]

    local result, err = mysql_client.query(sql)
    if err then
        ngx.log(ngx.ERR, "清理过期短链失败: ", err)
        return
    end

    local affected_rows = result.affected_rows or 0
    ngx.log(ngx.INFO, "清理过期短链完成，影响行数: ", affected_rows)

    -- 清除对应的 Redis 缓存
    if affected_rows > 0 then
        local get_sql = "SELECT short_code FROM short_links WHERE status = 'expired'"
        local expired_links, err = mysql_client.query(get_sql)

        if expired_links then
            for _, link in ipairs(expired_links) do
                redis_client.del("short_link:" .. link.short_code)
            end
        end
    end
end

-- 清理旧的访问日志
local function clean_old_logs()
    ngx.log(ngx.INFO, "开始清理旧访问日志...")

    -- 删除 90 天前的日志
    local retention_days = 90
    local cutoff_time = ngx.time() - (retention_days * 24 * 3600)

    local sql = [[
        DELETE FROM access_logs
        WHERE created_at < FROM_UNIXTIME(?)
        LIMIT 10000
    ]]

    local result, err = mysql_client.query(sql, {cutoff_time})
    if err then
        ngx.log(ngx.ERR, "清理旧日志失败: ", err)
        return
    end

    local affected_rows = result.affected_rows or 0
    ngx.log(ngx.INFO, "清理旧日志完成，删除行数: ", affected_rows)
end

-- 归档访问日志到汇总表
local function archive_access_logs()
    ngx.log(ngx.INFO, "开始归档访问日志...")

    -- 将昨天的数据归档到按天汇总的表
    local yesterday = os.date("%Y-%m-%d", ngx.time() - 86400)

    local sql = [[
        INSERT INTO access_logs_daily
        (short_code, log_date, total_visits, unique_visitors, total_response_time)
        SELECT
            short_code,
            DATE(created_at) as log_date,
            COUNT(*) as total_visits,
            COUNT(DISTINCT ip_address) as unique_visitors,
            SUM(response_time) as total_response_time
        FROM access_logs
        WHERE DATE(created_at) = ?
        GROUP BY short_code, DATE(created_at)
        ON DUPLICATE KEY UPDATE
            total_visits = VALUES(total_visits),
            unique_visitors = VALUES(unique_visitors),
            total_response_time = VALUES(total_response_time)
    ]]

    local result, err = mysql_client.query(sql, {yesterday})
    if err then
        ngx.log(ngx.ERR, "归档日志失败: ", err)
        return
    end

    ngx.log(ngx.INFO, "归档日志完成")
end

-- 更新短链访问计数
local function update_visit_counts()
    ngx.log(ngx.INFO, "开始更新访问计数...")

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
        ngx.log(ngx.ERR, "更新访问计数失败: ", err)
        return
    end

    ngx.log(ngx.INFO, "更新访问计数完成")
end

-- 清理 Redis 缓存中的过期数据
local function clean_redis_cache()
    ngx.log(ngx.INFO, "开始清理 Redis 缓存...")

    -- 清理实时统计中的过期数据
    local keys, err = redis_client.keys("access:realtime:*")
    if err then
        ngx.log(ngx.ERR, "获取 Redis keys 失败: ", err)
        return
    end

    if not keys or #keys == 0 then
        ngx.log(ngx.INFO, "没有需要清理的 Redis 键")
        return
    end

    local cleaned = 0
    local now = ngx.time()

    for _, key in ipairs(keys) do
        -- 检查键的 TTL
        local ttl, err = redis_client.ttl(key)

        if ttl and ttl < 0 then
            -- 没有设置过期时间，手动检查
            redis_client.expire(key, 3600)  -- 设置1小时过期
            cleaned = cleaned + 1
        end
    end

    ngx.log(ngx.INFO, "清理 Redis 缓存完成，处理键数: ", cleaned)
end

-- 生成统计报告
local function generate_daily_report()
    ngx.log(ngx.INFO, "开始生成每日报告...")

    local yesterday = os.date("%Y-%m-%d", ngx.time() - 86400)

    local sql = [[
        SELECT
            COUNT(DISTINCT short_code) as total_links,
            COUNT(*) as total_visits,
            COUNT(DISTINCT ip_address) as unique_visitors,
            AVG(response_time) as avg_response_time,
            COUNT(DISTINCT country) as countries_count
        FROM access_logs
        WHERE DATE(created_at) = ?
    ]]

    local result, err = mysql_client.query(sql, {yesterday})
    if err then
        ngx.log(ngx.ERR, "生成报告失败: ", err)
        return
    end

    local report = result[1] or {}

    -- 保存报告到 Redis
    local report_key = "daily_report:" .. yesterday
    redis_client.setex(report_key, 86400 * 30, require("cjson").encode(report))

    ngx.log(ngx.INFO, "每日报告生成完成: ", yesterday)
end

-- 健康检查数据清理
local function clean_health_check_data()
    ngx.log(ngx.INFO, "开始清理健康检查数据...")

    local health_dict = ngx.shared.health_check
    if not health_dict then
        return
    end

    -- 清理超过1小时的健康检查记录
    local keys = health_dict:get_keys(0)
    local now = ngx.time()
    local cleaned = 0

    for _, key in ipairs(keys) do
        if key:match("^health:") then
            local value = health_dict:get(key)
            if value then
                local timestamp = tonumber(value:match("timestamp\":(%d+)"))
                if timestamp and (now - timestamp) > 3600 then
                    health_dict:delete(key)
                    cleaned = cleaned + 1
                end
            end
        end
    end

    ngx.log(ngx.INFO, "清理健康检查数据完成，清理数: ", cleaned)
end

-- 任务注册表
local tasks = {
    {
        name = "clean_expired_links",
        interval = 3600,  -- 每小时执行一次
        handler = clean_expired_links,
        last_run = 0
    },
    {
        name = "clean_old_logs",
        interval = 86400,  -- 每天执行一次
        handler = clean_old_logs,
        last_run = 0
    },
    {
        name = "archive_access_logs",
        interval = 86400,  -- 每天执行一次（凌晨2点）
        handler = archive_access_logs,
        last_run = 0,
        schedule_time = "02:00"  -- 固定时间执行
    },
    {
        name = "update_visit_counts",
        interval = 3600,  -- 每小时执行一次
        handler = update_visit_counts,
        last_run = 0
    },
    {
        name = "clean_redis_cache",
        interval = 7200,  -- 每2小时执行一次
        handler = clean_redis_cache,
        last_run = 0
    },
    {
        name = "generate_daily_report",
        interval = 86400,  -- 每天执行一次
        handler = generate_daily_report,
        last_run = 0,
        schedule_time = "01:00"  -- 凌晨1点执行
    },
    {
        name = "clean_health_check_data",
        interval = 3600,  -- 每小时执行一次
        handler = clean_health_check_data,
        last_run = 0
    }
}

-- 任务调度器主循环
function _M.run()
    local now = ngx.time()

    for _, task in ipairs(tasks) do
        local should_run = false

        if task.schedule_time then
            -- 固定时间执行
            local hour, minute = task.schedule_time:match("(%d+):(%d+)")
            local scheduled_time = os.time({
                year = os.date("%Y"),
                month = os.date("%m"),
                day = os.date("%d"),
                hour = tonumber(hour),
                min = tonumber(minute),
                sec = 0
            })

            -- 检查是否在计划时间的前后5分钟内，且今天还没执行过
            if math.abs(now - scheduled_time) < 300 and
               (now - task.last_run) > 43200 then  -- 至少间隔12小时
                should_run = true
            end
        else
            -- 间隔执行
            if (now - task.last_run) >= task.interval then
                should_run = true
            end
        end

        if should_run then
            ngx.log(ngx.INFO, "执行定时任务: ", task.name)

            local ok, err = pcall(task.handler)
            if not ok then
                ngx.log(ngx.ERR, "定时任务执行失败 [", task.name, "]: ", err)
            end

            task.last_run = now
        end
    end
end

-- 手动触发任务
function _M.trigger_task(task_name)
    for _, task in ipairs(tasks) do
        if task.name == task_name then
            ngx.log(ngx.INFO, "手动触发任务: ", task_name)

            local ok, err = pcall(task.handler)
            if not ok then
                return nil, err
            end

            task.last_run = ngx.time()
            return true
        end
    end

    return nil, "Task not found: " .. task_name
end

-- 获取任务状态
function _M.get_task_status()
    local status = {}
    local now = ngx.time()

    for _, task in ipairs(tasks) do
        table.insert(status, {
            name = task.name,
            interval = task.interval,
            last_run = task.last_run,
            next_run = task.last_run + task.interval,
            time_until_next = math.max(0, task.last_run + task.interval - now),
            schedule_time = task.schedule_time
        })
    end

    return status
end

return _M

