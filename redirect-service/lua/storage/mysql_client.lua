-- storage/mysql_client.lua
-- MySQL 客户端模块

local mysql = require "resty.mysql"
local logger = require "utils.logger"
local cjson = require "cjson.safe"

local _M = {}

local config = {
    host = "127.0.0.1",
    port = 3306,
    database = "short_links",
    user = "root",
    password = "",
    charset = "utf8mb4",
    timeout = 5000,          -- 连接超时（优化：增加）
    pool_size = 100,         -- 连接池大小（保持）
    max_idle_timeout = 30000, -- 最大空闲时间（优化：增加）
}

-- 创建 MySQL 连接
local function connect()
    local db = mysql:new()
    db:set_timeout(config.timeout)

    local ok, err, errno, sqlstate = db:connect({
        host = config.host,
        port = config.port,
        database = config.database,
        user = config.user,
        password = config.password,
        charset = config.charset,
        max_packet_size = 1024 * 1024,
    })

    if not ok then
        return nil, "连接失败: " .. (err or "unknown")
    end

    return db, nil
end

-- 归还连接到连接池
local function keepalive(db)
    if not db then
        return
    end

    local ok, err = db:set_keepalive(config.max_idle_timeout, config.pool_size)
    if not ok then
        logger.warn("归还连接失败: " .. (err or "unknown"))
    end
end

-- SQL 注入防护 - 转义特殊字符（包含引号）
local function escape(str)
    if type(str) ~= "string" then
        return str
    end
    -- ngx.quote_sql_str 会自动添加引号并转义
    return ngx.quote_sql_str(str)
end

-- 查询短链信息
function _M.get_link(short_code)
    local db, err = connect()
    if not db then
        logger.error("MySQL连接失败: " .. err)
        return nil, err
    end

    local sql = string.format([[
        SELECT
            id, short_code, targets, strategy,
            security_config, service_type, status,
            created_at, updated_at, expires_at
        FROM short_links
        WHERE short_code = %s
          AND status = 'active'
          AND (expires_at IS NULL OR expires_at > NOW())
        LIMIT 1
    ]], escape(short_code))

    local res, err, errno, sqlstate = db:query(sql)
    keepalive(db)

    if not res then
        logger.error("查询失败: " .. (err or "unknown"))
        return nil, err
    end

    if #res == 0 then
        return nil, "短链不存在"
    end

    local row = res[1]

    -- 解析 JSON 字段
    if row.targets then
        row.targets = cjson.decode(row.targets)
    end
    if row.security_config then
        row.security_config = cjson.decode(row.security_config)
    end

    return row, nil
end

-- 创建短链
function _M.create_link(data)
    local db, err = connect()
    if not db then
        logger.error("MySQL连接失败: " .. err)
        return nil, err
    end

    local targets_json = cjson.encode(data.targets or {})
    local security_json = cjson.encode(data.security_config or {})

    local sql = string.format([[
        INSERT INTO short_links
        (short_code, targets, strategy, security_config, service_type, status, expires_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    ]],
        escape(data.short_code),
        escape(targets_json),
        escape(data.strategy or "weight"),
        escape(security_json),
        escape(data.service_type or "general"),
        escape(data.status or "active"),
        data.expires_at and escape(data.expires_at) or "NULL"
    )

    local res, err, errno, sqlstate = db:query(sql)
    keepalive(db)

    if not res then
        logger.error("创建失败: " .. (err or "unknown"))
        return nil, err
    end

    return res.insert_id, nil
end

-- 更新短链
function _M.update_link(short_code, data)
    local db, err = connect()
    if not db then
        logger.error("MySQL连接失败: " .. err)
        return false, err
    end

    local updates = {}

    if data.targets then
        table.insert(updates, "targets = " .. escape(cjson.encode(data.targets)))
    end
    if data.strategy then
        table.insert(updates, "strategy = " .. escape(data.strategy))
    end
    if data.security_config then
        table.insert(updates, "security_config = " .. escape(cjson.encode(data.security_config)))
    end
    if data.service_type then
        table.insert(updates, "service_type = " .. escape(data.service_type))
    end
    if data.status then
        table.insert(updates, "status = " .. escape(data.status))
    end
    if data.expires_at then
        table.insert(updates, "expires_at = " .. escape(data.expires_at))
    end

    if #updates == 0 then
        return true, nil
    end

    local sql = string.format([[
        UPDATE short_links
        SET %s, updated_at = NOW()
        WHERE short_code = %s
    ]], table.concat(updates, ", "), escape(short_code))

    local res, err, errno, sqlstate = db:query(sql)
    keepalive(db)

    if not res then
        logger.error("更新失败: " .. (err or "unknown"))
        return false, err
    end

    return true, nil
end

-- 删除短链
function _M.delete_link(short_code)
    local db, err = connect()
    if not db then
        logger.error("MySQL连接失败: " .. err)
        return false, err
    end

    local sql = string.format([[
        UPDATE short_links
        SET status = 'deleted', updated_at = NOW()
        WHERE short_code = %s
    ]], escape(short_code))

    local res, err, errno, sqlstate = db:query(sql)
    keepalive(db)

    if not res then
        logger.error("删除失败: " .. (err or "unknown"))
        return false, err
    end

    return true, nil
end

-- 记录访问日志
function _M.log_access(data)
    local db, err = connect()
    if not db then
        -- 访问日志失败不影响主流程，只记录错误
        logger.error("MySQL连接失败，访问日志未记录: " .. err)
        return false, err
    end

    local sql = string.format([[
        INSERT INTO access_logs
        (short_code, target_url, client_ip, country, province,
         city, isp, asn, device_type, user_agent, referer,
         response_time, created_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
    ]],
        escape(data.short_code),
        escape(data.target_url),
        escape(data.client_ip),
        escape(data.country),
        escape(data.province),
        escape(data.city),
        escape(data.isp),
        escape(data.asn),
        escape(data.device_type),
        escape(data.user_agent),
        escape(data.referer),
        tonumber(data.response_time) or 0
    )

    local res, err, errno, sqlstate = db:query(sql)
    keepalive(db)

    if not res then
        logger.error("访问日志记录失败: " .. (err or "unknown"))
        return false, err
    end

    return true, nil
end

-- 通用查询方法（用于统计等场景）
function _M.query(sql, params)
    local db, err = connect()
    if not db then
        return nil, err
    end

    -- 如果有参数，使用 format_query 进行参数化（简单替换）
    if params and type(params) == "table" then
        -- 简单的参数替换（escape 函数已包含引号）
        local formatted_sql = sql
        for i, param in ipairs(params) do
            local escaped_param
            if type(param) == "string" then
                -- escape 函数已经添加了引号
                escaped_param = escape(param)
            elseif param == nil then
                escaped_param = "NULL"
            else
                escaped_param = tostring(param)
            end
            formatted_sql = formatted_sql:gsub("?", escaped_param, 1)
        end

        local res, err, errno, sqlstate = db:query(formatted_sql)
        keepalive(db)

        if not res then
            return nil, "query失败: " .. (err or "unknown")
        end
        return res, nil
    end    -- 直接执行SQL
    local res, err, errno, sqlstate = db:query(sql)
    keepalive(db)

    if not res then
        return nil, "query失败: " .. (err or "unknown")
    end
    return res, nil
end

-- 初始化配置
function _M.init(conf)
    if conf then
        for k, v in pairs(conf) do
            config[k] = v
        end
    end
end

return _M
