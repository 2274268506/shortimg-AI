-- api/batch.lua
-- 批量操作 API

local mysql_client = require "storage.mysql_client"
local redis_client = require "storage.redis_client"
local cjson = require "cjson.safe"

local _M = {}

-- 批量创建短链
function _M.batch_create(links)
    if not links or type(links) ~= "table" or #links == 0 then
        return nil, "Invalid links data"
    end

    if #links > 100 then
        return nil, "Batch size too large (max 100)"
    end

    local results = {
        success = {},
        failed = {}
    }

    -- 逐个创建（简化版，不使用事务）
    for i, link in ipairs(links) do
        local data = {
            short_code = link.short_code,
            targets = link.targets or {},
            strategy = link.strategy or "round_robin",
            security_config = link.security_config or {},
            expires_at = link.expires_at or 0
        }

        local ok, err = mysql_client.create_link(data)

        if ok then
            -- 写入 Redis 缓存
            local cache_key = "short_link:" .. data.short_code
            local targets_json = cjson.encode(data.targets)
            redis_client.set(cache_key, targets_json, 3600)

            table.insert(results.success, {
                short_code = data.short_code,
                index = i
            })
        else
            table.insert(results.failed, {
                short_code = data.short_code,
                index = i,
                error = err
            })
        end
    end

    return results
end

-- 批量更新短链
function _M.batch_update(updates)
    if not updates or type(updates) ~= "table" or #updates == 0 then
        return nil, "Invalid updates data"
    end

    if #updates > 100 then
        return nil, "Batch size too large (max 100)"
    end

    local results = {
        success = {},
        failed = {}
    }

    for i, update in ipairs(updates) do
        local short_code = update.short_code

        if not short_code then
            table.insert(results.failed, {
                index = i,
                error = "Missing short_code"
            })
            goto continue
        end

        local set_parts = {}
        local params = {}

        -- 构建更新字段
        if update.targets then
            table.insert(set_parts, "targets = ?")
            table.insert(params, cjson.encode(update.targets))
        end

        if update.strategy then
            table.insert(set_parts, "strategy = ?")
            table.insert(params, update.strategy)
        end

        if update.security_config then
            table.insert(set_parts, "security_config = ?")
            table.insert(params, cjson.encode(update.security_config))
        end

        if update.status then
            table.insert(set_parts, "status = ?")
            table.insert(params, update.status)
        end

        if update.expires_at then
            table.insert(set_parts, "expires_at = FROM_UNIXTIME(?)")
            table.insert(params, update.expires_at)
        end

        if #set_parts == 0 then
            table.insert(results.failed, {
                short_code = short_code,
                index = i,
                error = "No fields to update"
            })
            goto continue
        end

        -- 添加 updated_at
        table.insert(set_parts, "updated_at = NOW()")
        table.insert(params, short_code)

        local sql = "UPDATE short_links SET " .. table.concat(set_parts, ", ") .. " WHERE short_code = ?"

        local ok, err = mysql_client.query(sql, params)

        if ok then
            -- 清除 Redis 缓存
            redis_client.del("short_link:" .. short_code)

            table.insert(results.success, {
                short_code = short_code,
                index = i
            })
        else
            table.insert(results.failed, {
                short_code = short_code,
                index = i,
                error = err
            })
        end

        ::continue::
    end

    return results
end

-- 批量删除短链
function _M.batch_delete(short_codes)
    if not short_codes or type(short_codes) ~= "table" or #short_codes == 0 then
        return nil, "Invalid short_codes"
    end

    if #short_codes > 100 then
        return nil, "Batch size too large (max 100)"
    end

    local results = {
        success = {},
        failed = {}
    }

    for i, short_code in ipairs(short_codes) do
        local sql = "DELETE FROM short_links WHERE short_code = ?"
        local ok, err = mysql_client.query(sql, {short_code})

        if ok then
            -- 清除 Redis 缓存
            redis_client.del("short_link:" .. short_code)

            table.insert(results.success, {
                short_code = short_code,
                index = i
            })
        else
            table.insert(results.failed, {
                short_code = short_code,
                index = i,
                error = err
            })
        end
    end

    return results
end

-- 批量启用/禁用短链
function _M.batch_status_change(short_codes, status)
    if not short_codes or type(short_codes) ~= "table" or #short_codes == 0 then
        return nil, "Invalid short_codes"
    end

    if status ~= "active" and status ~= "inactive" and status ~= "expired" then
        return nil, "Invalid status"
    end

    if #short_codes > 100 then
        return nil, "Batch size too large (max 100)"
    end

    local results = {
        success = {},
        failed = {}
    }

    for i, short_code in ipairs(short_codes) do
        local sql = "UPDATE short_links SET status = ?, updated_at = NOW() WHERE short_code = ?"
        local ok, err = mysql_client.query(sql, {status, short_code})

        if ok then
            -- 清除 Redis 缓存
            redis_client.del("short_link:" .. short_code)

            table.insert(results.success, {
                short_code = short_code,
                index = i,
                status = status
            })
        else
            table.insert(results.failed, {
                short_code = short_code,
                index = i,
                error = err
            })
        end
    end

    return results
end

-- 批量导入（从 CSV）
function _M.import_from_csv(csv_content)
    local lines = {}
    for line in csv_content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    if #lines < 2 then
        return nil, "CSV file is empty or invalid"
    end

    -- 跳过标题行
    local links = {}
    for i = 2, #lines do
        local line = lines[i]
        local fields = {}

        -- 简单的 CSV 解析
        for field in line:gmatch('([^,]+)') do
            table.insert(fields, field:match("^%s*(.-)%s*$"))  -- 去除空格
        end

        if #fields >= 3 then
            local link = {
                short_code = fields[1],
                targets = cjson.decode(fields[2] or "[]"),
                strategy = fields[3] or "round_robin",
                security_config = cjson.decode(fields[4] or "{}"),
                expires_at = tonumber(fields[5]) or 0
            }
            table.insert(links, link)
        end
    end

    return _M.batch_create(links)
end

-- 批量查询短链信息
function _M.batch_query(short_codes)
    if not short_codes or type(short_codes) ~= "table" or #short_codes == 0 then
        return nil, "Invalid short_codes"
    end

    if #short_codes > 100 then
        return nil, "Batch size too large (max 100)"
    end

    local results = {}

    -- 构建 IN 查询
    local placeholders = {}
    for i = 1, #short_codes do
        table.insert(placeholders, "?")
    end

    local sql = string.format([[
        SELECT
            short_code,
            targets,
            strategy,
            security_config,
            status,
            visit_count,
            created_at,
            updated_at,
            expires_at
        FROM short_links
        WHERE short_code IN (%s)
    ]], table.concat(placeholders, ","))

    local rows, err = mysql_client.query(sql, short_codes)
    if err then
        return nil, err
    end

    for _, row in ipairs(rows) do
        row.targets = cjson.decode(row.targets)
        row.security_config = cjson.decode(row.security_config)
        table.insert(results, row)
    end

    return results
end

return _M
