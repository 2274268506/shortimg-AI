-- utils/error_handler.lua
-- 统一错误处理和错误码定义

local cjson = require "cjson.safe"
local logger = require "utils.logger"

local _M = {}

-- 错误码定义
_M.ERROR_CODES = {
    -- 通用错误 (1000-1099)
    INVALID_REQUEST = {code = 1000, message = "无效的请求"},
    MISSING_PARAMETER = {code = 1001, message = "缺少必需参数"},
    INVALID_PARAMETER = {code = 1002, message = "参数格式错误"},
    REQUEST_TOO_LARGE = {code = 1003, message = "请求体过大"},
    JSON_PARSE_ERROR = {code = 1004, message = "JSON解析失败"},

    -- 短链相关错误 (2000-2099)
    LINK_NOT_FOUND = {code = 2000, message = "短链不存在"},
    LINK_EXPIRED = {code = 2001, message = "短链已过期"},
    LINK_PAUSED = {code = 2002, message = "短链已暂停"},
    LINK_DELETED = {code = 2003, message = "短链已删除"},
    CODE_ALREADY_EXISTS = {code = 2004, message = "短链码已存在"},
    CODE_GENERATION_FAILED = {code = 2005, message = "短链码生成失败"},
    INVALID_URL = {code = 2006, message = "无效的目标URL"},
    INVALID_CODE = {code = 2007, message = "无效的短链码格式"},

    -- 批量操作错误 (2100-2199)
    BATCH_TOO_LARGE = {code = 2100, message = "批量操作数量超限"},
    BATCH_PARTIAL_FAILURE = {code = 2101, message = "批量操作部分失败"},

    -- 数据库错误 (3000-3099)
    DATABASE_ERROR = {code = 3000, message = "数据库操作失败"},
    DATABASE_CONNECTION_ERROR = {code = 3001, message = "数据库连接失败"},
    QUERY_ERROR = {code = 3002, message = "查询执行失败"},

    -- Redis错误 (3100-3199)
    REDIS_ERROR = {code = 3100, message = "Redis操作失败"},
    CACHE_ERROR = {code = 3101, message = "缓存操作失败"},

    -- 安全相关错误 (4000-4099)
    FORBIDDEN = {code = 4000, message = "访问被禁止"},
    IP_BLOCKED = {code = 4001, message = "IP地址已被封禁"},
    REFERER_DENIED = {code = 4002, message = "Referer验证失败"},
    TOKEN_INVALID = {code = 4003, message = "Token验证失败"},
    RATE_LIMIT_EXCEEDED = {code = 4004, message = "请求频率超限"},

    -- 系统错误 (5000-5099)
    INTERNAL_ERROR = {code = 5000, message = "内部服务器错误"},
    SERVICE_UNAVAILABLE = {code = 5001, message = "服务暂时不可用"},
}

-- 响应错误
function _M.respond_error(error_type, custom_message, http_status)
    local error_info = _M.ERROR_CODES[error_type] or _M.ERROR_CODES.INTERNAL_ERROR

    local response = {
        success = false,
        error = {
            code = error_info.code,
            message = custom_message or error_info.message,
            type = error_type
        },
        timestamp = ngx.time()
    }

    -- 记录错误日志
    logger.error(string.format("Error [%s]: %s", error_type, custom_message or error_info.message))

    -- 设置HTTP状态码
    local status = http_status or _M.get_http_status(error_info.code)
    ngx.status = status
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode(response))
    ngx.exit(status)
end

-- 根据错误码获取HTTP状态码
function _M.get_http_status(error_code)
    if error_code >= 1000 and error_code < 2000 then
        return 400  -- Bad Request
    elseif error_code >= 2000 and error_code < 3000 then
        return 404  -- Not Found (短链相关)
    elseif error_code >= 3000 and error_code < 4000 then
        return 500  -- Internal Server Error (数据库/缓存)
    elseif error_code >= 4000 and error_code < 5000 then
        return 403  -- Forbidden (安全相关)
    elseif error_code >= 5000 then
        return 500  -- Internal Server Error (系统错误)
    else
        return 500
    end
end

-- 响应成功
function _M.respond_success(data, http_status)
    local response = {
        success = true,
        data = data,
        timestamp = ngx.time()
    }

    ngx.status = http_status or 200
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode(response))
    ngx.exit(http_status or 200)
end

-- 捕获异常并返回错误
function _M.safe_execute(func)
    local ok, result = pcall(func)
    if not ok then
        logger.error("Caught exception: " .. tostring(result))
        _M.respond_error("INTERNAL_ERROR", "操作执行失败: " .. tostring(result), 500)
    end
    return result
end

-- 验证参数
function _M.validate_params(params, rules)
    for field, rule in pairs(rules) do
        local value = params[field]

        -- 必需参数检查
        if rule.required and (value == nil or value == "") then
            _M.respond_error("MISSING_PARAMETER", string.format("缺少必需参数: %s", field))
        end

        -- 类型检查
        if value ~= nil and rule.type then
            local actual_type = type(value)
            if actual_type ~= rule.type then
                _M.respond_error("INVALID_PARAMETER",
                    string.format("参数 %s 类型错误，期望 %s，实际 %s", field, rule.type, actual_type))
            end
        end

        -- 长度检查
        if value and rule.min_length and #value < rule.min_length then
            _M.respond_error("INVALID_PARAMETER",
                string.format("参数 %s 长度不能少于 %d", field, rule.min_length))
        end

        if value and rule.max_length and #value > rule.max_length then
            _M.respond_error("INVALID_PARAMETER",
                string.format("参数 %s 长度不能超过 %d", field, rule.max_length))
        end

        -- 正则表达式验证
        if value and rule.pattern and not value:match(rule.pattern) then
            _M.respond_error("INVALID_PARAMETER",
                string.format("参数 %s 格式不正确", field))
        end

        -- 枚举值检查
        if value and rule.enum then
            local valid = false
            for _, allowed in ipairs(rule.enum) do
                if value == allowed then
                    valid = true
                    break
                end
            end
            if not valid then
                _M.respond_error("INVALID_PARAMETER",
                    string.format("参数 %s 必须是以下值之一: %s", field, table.concat(rule.enum, ", ")))
            end
        end

        -- 数值范围检查
        if value and rule.min and tonumber(value) < rule.min then
            _M.respond_error("INVALID_PARAMETER",
                string.format("参数 %s 不能小于 %d", field, rule.min))
        end

        if value and rule.max and tonumber(value) > rule.max then
            _M.respond_error("INVALID_PARAMETER",
                string.format("参数 %s 不能大于 %d", field, rule.max))
        end
    end

    return true
end

return _M
