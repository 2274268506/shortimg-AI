-- api/admin_extended.lua
-- 扩展管理 API（包含批量操作、统计、任务管理）

local batch = require "api.batch"
local stats_advanced = require "api.stats_advanced"
local scheduler = require "core.scheduler"
local cjson = require "cjson.safe"

local _M = {}

-- 响应 JSON
local function respond_json(data, status)
    status = status or 200
    ngx.status = status
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode(data))
    return ngx.exit(status)
end

-- 错误响应
local function respond_error(message, status)
    return respond_json({
        success = false,
        error = message,
        timestamp = ngx.time()
    }, status or 400)
end

-- 成功响应
local function respond_success(data, meta)
    local response = {
        success = true,
        data = data,
        timestamp = ngx.time()
    }

    if meta then
        response.meta = meta
    end

    return respond_json(response, 200)
end

-- 读取请求体
local function read_body()
    ngx.req.read_body()
    local body = ngx.req.get_body_data()

    if not body then
        return nil, "请求体为空"
    end

    local data, err = cjson.decode(body)
    if not data then
        return nil, "JSON 解析失败: " .. (err or "unknown")
    end

    return data
end

-- 路由处理
function _M.handle()
    local uri = ngx.var.uri
    local method = ngx.var.request_method

    -- 批量操作 API
    if uri:match("^/api/v1/batch/create$") and method == "POST" then
        return _M.batch_create()
    elseif uri:match("^/api/v1/batch/update$") and method == "POST" then
        return _M.batch_update()
    elseif uri:match("^/api/v1/batch/delete$") and method == "POST" then
        return _M.batch_delete()
    elseif uri:match("^/api/v1/batch/status$") and method == "POST" then
        return _M.batch_status()
    elseif uri:match("^/api/v1/batch/query$") and method == "POST" then
        return _M.batch_query()

    -- 高级统计 API
    elseif uri:match("^/api/v1/stats/([^/]+)/dashboard$") then
        local short_code = uri:match("^/api/v1/stats/([^/]+)/dashboard$")
        return _M.get_dashboard(short_code)
    elseif uri:match("^/api/v1/stats/([^/]+)/geo$") then
        local short_code = uri:match("^/api/v1/stats/([^/]+)/geo$")
        return _M.get_geo_stats(short_code)
    elseif uri:match("^/api/v1/stats/([^/]+)/device$") then
        local short_code = uri:match("^/api/v1/stats/([^/]+)/device$")
        return _M.get_device_stats(short_code)
    elseif uri:match("^/api/v1/stats/([^/]+)/export$") then
        local short_code = uri:match("^/api/v1/stats/([^/]+)/export$")
        return _M.export_stats(short_code)
    elseif uri:match("^/api/v1/stats/overview$") then
        return _M.get_overview()

    -- 定时任务 API
    elseif uri:match("^/api/v1/tasks/status$") and method == "GET" then
        return _M.get_task_status()
    elseif uri:match("^/api/v1/tasks/trigger$") and method == "POST" then
        return _M.trigger_task()

    else
        return respond_error("API 不存在", 404)
    end
end

-- 批量创建
function _M.batch_create()
    local data, err = read_body()
    if err then
        return respond_error(err, 400)
    end

    local result, err = batch.batch_create(data.links)
    if err then
        return respond_error(err, 500)
    end

    return respond_success(result, {
        total = #data.links,
        success_count = #result.success,
        failed_count = #result.failed
    })
end

-- 批量更新
function _M.batch_update()
    local data, err = read_body()
    if err then
        return respond_error(err, 400)
    end

    local result, err = batch.batch_update(data.updates)
    if err then
        return respond_error(err, 500)
    end

    return respond_success(result, {
        total = #data.updates,
        success_count = #result.success,
        failed_count = #result.failed
    })
end

-- 批量删除
function _M.batch_delete()
    local data, err = read_body()
    if err then
        return respond_error(err, 400)
    end

    local result, err = batch.batch_delete(data.short_codes)
    if err then
        return respond_error(err, 500)
    end

    return respond_success(result, {
        total = #data.short_codes,
        success_count = #result.success,
        failed_count = #result.failed
    })
end

-- 批量状态变更
function _M.batch_status()
    local data, err = read_body()
    if err then
        return respond_error(err, 400)
    end

    local result, err = batch.batch_status_change(data.short_codes, data.status)
    if err then
        return respond_error(err, 500)
    end

    return respond_success(result, {
        total = #data.short_codes,
        success_count = #result.success,
        failed_count = #result.failed
    })
end

-- 批量查询
function _M.batch_query()
    local data, err = read_body()
    if err then
        return respond_error(err, 400)
    end

    local result, err = batch.batch_query(data.short_codes)
    if err then
        return respond_error(err, 500)
    end

    return respond_success(result)
end

-- 获取仪表板统计
function _M.get_dashboard(short_code)
    local args = ngx.req.get_uri_args()
    local days = tonumber(args.days) or 7

    local result, err = stats_advanced.get_dashboard_stats(short_code, days)
    if err then
        return respond_error(err, 500)
    end

    return respond_success(result)
end

-- 获取地理位置统计
function _M.get_geo_stats(short_code)
    local args = ngx.req.get_uri_args()
    local limit = tonumber(args.limit) or 20

    local result, err = stats_advanced.get_geo_distribution(short_code, limit)
    if err then
        return respond_error(err, 500)
    end

    return respond_success(result)
end

-- 获取设备统计
function _M.get_device_stats(short_code)
    local result, err = stats_advanced.get_device_stats(short_code)
    if err then
        return respond_error(err, 500)
    end

    return respond_success(result)
end

-- 导出统计数据
function _M.export_stats(short_code)
    local args = ngx.req.get_uri_args()
    local start_time = tonumber(args.start) or (ngx.time() - 2592000)  -- 默认30天
    local end_time = tonumber(args["end"]) or ngx.time()  -- 使用方括号访问，避免 end 关键字冲突
    local format = args.format or "csv"

    local result, err = stats_advanced.export_stats(short_code, start_time, end_time, format)
    if err then
        return respond_error(err, 500)
    end

    -- 设置下载响应头
    ngx.header["Content-Type"] = format == "csv" and "text/csv" or "application/json"
    ngx.header["Content-Disposition"] = string.format(
        'attachment; filename="stats_%s_%s.%s"',
        short_code,
        os.date("%Y%m%d"),
        format
    )

    ngx.say(result)
    return ngx.exit(200)
end

-- 获取总览统计
function _M.get_overview()
    local mysql_client = require "storage.mysql_client"

    -- 总链接数
    local total_sql = "SELECT COUNT(*) as count FROM short_links WHERE status = 'active'"
    local total_result, err = mysql_client.query(total_sql)
    if err then
        return respond_error(err, 500)
    end

    local total_links = (total_result[1] and total_result[1].count) or 0

    -- 总访问量
    local visits_sql = "SELECT COUNT(*) as count FROM access_logs"
    local visits_result, err = mysql_client.query(visits_sql)
    if err then
        return respond_error(err, 500)
    end

    local total_visits = (visits_result[1] and visits_result[1].count) or 0

    -- 独立访客
    local visitors_sql = "SELECT COUNT(DISTINCT client_ip) as count FROM access_logs"
    local visitors_result, err = mysql_client.query(visitors_sql)
    if err then
        return respond_error(err, 500)
    end

    local unique_visitors = (visitors_result[1] and visitors_result[1].count) or 0

    -- 今日访问
    local today_start = ngx.time() - (ngx.time() % 86400)
    local today_sql = "SELECT COUNT(*) as count FROM access_logs WHERE created_at >= FROM_UNIXTIME(?)"
    local today_result, err = mysql_client.query(today_sql, {today_start})
    if err then
        return respond_error(err, 500)
    end

    local today_visits = (today_result[1] and today_result[1].count) or 0

    return respond_success({
        total_links = total_links,
        total_visits = total_visits,
        unique_visitors = unique_visitors,
        today_visits = today_visits
    })
end

-- 获取任务状态
function _M.get_task_status()
    local status = scheduler.get_task_status()
    return respond_success({tasks = status})
end

-- 触发任务
function _M.trigger_task()
    local data, err = read_body()
    if err then
        return respond_error(err, 400)
    end

    local ok, err = scheduler.trigger_task(data.task_name)
    if err then
        return respond_error(err, 500)
    end

    return respond_success({
        task_name = data.task_name,
        triggered_at = ngx.time()
    })
end

return _M
