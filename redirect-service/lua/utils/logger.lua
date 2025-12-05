-- utils/logger.lua
-- 日志工具模块

local cjson = require "cjson.safe"
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_WARN = ngx.WARN
local ngx_INFO = ngx.INFO
local ngx_DEBUG = ngx.DEBUG

local _M = {}

-- 日志级别
_M.ERROR = "ERROR"
_M.WARN = "WARN"
_M.INFO = "INFO"
_M.DEBUG = "DEBUG"

-- 格式化日志消息
local function format_log(level, message, context)
    local log_data = {
        timestamp = ngx.now(),
        level = level,
        message = message,
        worker_id = ngx.worker.id(),
    }

    if context then
        log_data.context = context
    end

    return cjson.encode(log_data)
end

-- 错误日志
function _M.error(message, context)
    local log_message = format_log(_M.ERROR, message, context)
    ngx_log(ngx_ERR, log_message)
end

-- 警告日志
function _M.warn(message, context)
    local log_message = format_log(_M.WARN, message, context)
    ngx_log(ngx_WARN, log_message)
end

-- 信息日志
function _M.info(message, context)
    local log_message = format_log(_M.INFO, message, context)
    ngx_log(ngx_INFO, log_message)
end

-- 调试日志
function _M.debug(message, context)
    local log_message = format_log(_M.DEBUG, message, context)
    ngx_log(ngx_DEBUG, log_message)
end

return _M
