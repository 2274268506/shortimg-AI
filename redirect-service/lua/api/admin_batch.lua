-- api/admin.lua
-- 短链管理API（批量操作）

local mysql_client = require "storage.mysql_client"
local redis_client = require "storage.redis_client"
local cjson = require "cjson.safe"

local _M = {}

local function respond_success(data)
    ngx.status = 200
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({success = true, data = data}))
    ngx.exit(200)
end

local function respond_error(msg, code)
    ngx.status = code or 400
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({success = false, error = msg}))
    ngx.exit(code or 400)
end

local function read_body()
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    if not body then return nil, "请求体为空" end

    local data = cjson.decode(body)
    if not data then return nil, "JSON解析失败" end

    return data
end

-- 批量删除过期短链
function _M.cleanup_expired()
    local result = mysql_client.query([[
        DELETE FROM short_links
        WHERE expires_at IS NOT NULL
        AND expires_at < NOW()
        AND status != 'deleted'
    ]])

    local affected = (result and result.affected_rows) or 0

    ngx.log(ngx.INFO, "清理过期短链: ", affected, " 条")

    return respond_success({
        deleted_count = affected,
        message = string.format("成功删除 %d 条过期短链", affected)
    })
end

-- 批量更新短链状态
function _M.batch_update_status()
    local data, err = read_body()
    if not data then return respond_error(err) end

    local codes = data.codes or {}
    local status = data.status

    if #codes == 0 then
        return respond_error("缺少codes参数")
    end

    if not status or (status ~= 'active' and status ~= 'paused' and status ~= 'deleted') then
        return respond_error("无效的状态值，必须是: active, paused, deleted")
    end

    local success_count = 0
    local failed_count = 0

    for _, code in ipairs(codes) do
        local result = mysql_client.query(
            "UPDATE short_links SET status=?, updated_at=NOW() WHERE short_code=?",
            {status, code}
        )

        if result and result.affected_rows > 0 then
            success_count = success_count + 1
            -- 清除缓存
            redis_client.del("link:" .. code)
        else
            failed_count = failed_count + 1
        end
    end

    ngx.log(ngx.INFO, string.format("批量更新状态: 成功=%d, 失败=%d", success_count, failed_count))

    return respond_success({
        total = #codes,
        success = success_count,
        failed = failed_count,
        message = string.format("成功更新 %d 条短链状态", success_count)
    })
end

-- 批量删除短链
function _M.batch_delete()
    local data, err = read_body()
    if not data then return respond_error(err) end

    local codes = data.codes or {}
    local permanent = data.permanent or false  -- 是否永久删除

    if #codes == 0 then
        return respond_error("缺少codes参数")
    end

    if #codes > 100 then
        return respond_error("单次最多删除100条")
    end

    local success_count = 0
    local failed_count = 0

    for _, code in ipairs(codes) do
        local result
        if permanent then
            -- 永久删除
            result = mysql_client.query("DELETE FROM short_links WHERE short_code=?", {code})
        else
            -- 软删除（标记为deleted）
            result = mysql_client.query(
                "UPDATE short_links SET status='deleted', updated_at=NOW() WHERE short_code=?",
                {code}
            )
        end

        if result and (result.affected_rows or 0) > 0 then
            success_count = success_count + 1
            -- 清除缓存
            redis_client.del("link:" .. code)
        else
            failed_count = failed_count + 1
        end
    end

    ngx.log(ngx.INFO, string.format("批量删除短链: 成功=%d, 失败=%d, 永久=%s",
        success_count, failed_count, permanent))

    return respond_success({
        total = #codes,
        success = success_count,
        failed = failed_count,
        permanent = permanent,
        message = string.format("成功删除 %d 条短链", success_count)
    })
end

-- 批量更新过期时间
function _M.batch_update_expire()
    local data, err = read_body()
    if not data then return respond_error(err) end

    local codes = data.codes or {}
    local expire_time = data.expire_time  -- 秒数

    if #codes == 0 then
        return respond_error("缺少codes参数")
    end

    local expire_at = nil
    if expire_time and expire_time > 0 then
        expire_at = os.date("%Y-%m-%d %H:%M:%S", ngx.time() + expire_time)
    end

    local success_count = 0
    local failed_count = 0

    for _, code in ipairs(codes) do
        local result = mysql_client.query(
            "UPDATE short_links SET expires_at=?, updated_at=NOW() WHERE short_code=?",
            {expire_at, code}
        )

        if result and result.affected_rows > 0 then
            success_count = success_count + 1
            -- 清除缓存
            redis_client.del("link:" .. code)
        else
            failed_count = failed_count + 1
        end
    end

    return respond_success({
        total = #codes,
        success = success_count,
        failed = failed_count,
        message = string.format("成功更新 %d 条短链过期时间", success_count)
    })
end

-- 清理访问日志
function _M.cleanup_access_logs()
    local args = ngx.req.get_uri_args()
    local days = tonumber(args.days) or 90  -- 默认保留90天

    if days < 7 then
        return respond_error("至少保留7天的日志")
    end

    local result = mysql_client.query(
        "DELETE FROM access_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)",
        {days}
    )

    local affected = (result and result.affected_rows) or 0

    ngx.log(ngx.INFO, string.format("清理访问日志: 删除 %d 条记录（保留 %d 天）", affected, days))

    return respond_success({
        deleted_count = affected,
        days_kept = days,
        message = string.format("成功清理 %d 条访问日志", affected)
    })
end

-- 查询短链列表（支持分页和筛选）
function _M.list_links()
    local args = ngx.req.get_uri_args()
    local page = tonumber(args.page) or 1
    local page_size = tonumber(args.page_size) or 20
    local service_type = args.service_type
    local status = args.status
    local search = args.search  -- 搜索短链码

    if page < 1 then page = 1 end
    if page_size < 1 or page_size > 100 then page_size = 20 end

    local offset = (page - 1) * page_size

    -- 构建WHERE条件
    local where_conditions = {}
    local params = {}

    if service_type and service_type ~= "" then
        table.insert(where_conditions, "service_type = ?")
        table.insert(params, service_type)
    end

    if status and status ~= "" then
        table.insert(where_conditions, "status = ?")
        table.insert(params, status)
    end

    if search and search ~= "" then
        table.insert(where_conditions, "short_code LIKE ?")
        table.insert(params, "%" .. search .. "%")
    end

    local where_clause = ""
    if #where_conditions > 0 then
        where_clause = " WHERE " .. table.concat(where_conditions, " AND ")
    end

    -- 查询总数
    local count_sql = "SELECT COUNT(*) as total FROM short_links" .. where_clause
    local count_result = mysql_client.query(count_sql, params)
    local total = (count_result and count_result[1] and tonumber(count_result[1].total)) or 0

    -- 查询列表
    local list_params = {}
    for _, p in ipairs(params) do
        table.insert(list_params, p)
    end
    table.insert(list_params, page_size)
    table.insert(list_params, offset)

    local list_sql = [[
        SELECT short_code, service_type, status, visit_count,
               created_at, updated_at, expires_at
        FROM short_links
    ]] .. where_clause .. " ORDER BY created_at DESC LIMIT ? OFFSET ?"

    local links = mysql_client.query(list_sql, list_params) or {}

    return respond_success({
        total = total,
        page = page,
        page_size = page_size,
        total_pages = math.ceil(total / page_size),
        links = links
    })
end

-- 路由处理
function _M.handle()
    local uri = ngx.var.uri
    local method = ngx.var.request_method

    -- 清理过期短链
    if uri == "/api/admin/cleanup/expired" and method == "POST" then
        return _M.cleanup_expired()

    -- 清理访问日志
    elseif uri == "/api/admin/cleanup/logs" and method == "POST" then
        return _M.cleanup_access_logs()

    -- 批量更新状态
    elseif uri == "/api/admin/batch/status" and method == "PUT" then
        return _M.batch_update_status()

    -- 批量删除
    elseif uri == "/api/admin/batch/delete" and method == "POST" then
        return _M.batch_delete()

    -- 批量更新过期时间
    elseif uri == "/api/admin/batch/expire" and method == "PUT" then
        return _M.batch_update_expire()

    -- 查询短链列表
    elseif uri == "/api/admin/links" and method == "GET" then
        return _M.list_links()

    else
        return respond_error("未知的管理接口", 404)
    end
end

return _M
