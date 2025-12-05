-- core/health_checker.lua
-- 健康检查模块

local http = require "resty.http"
local logger = require "utils.logger"

local _M = {}

local ngx_shared = ngx.shared
local ngx_timer_at = ngx.timer.at
local ngx_worker_id = ngx.worker.id

-- 健康检查配置
local config = {
    interval = 5,        -- 检查间隔（秒）
    timeout = 2000,      -- 超时时间（毫秒）
    fall = 3,            -- 失败次数阈值
    rise = 2,            -- 成功次数阈值
    http_path = "/health", -- 健康检查路径
}

-- 获取服务器健康状态
function _M.is_healthy(server_url)
    local health_check = ngx_shared.health_check
    local status = health_check:get(server_url)
    return status ~= "down"
end

-- 设置服务器状态
local function set_server_status(server_url, status)
    local health_check = ngx_shared.health_check
    health_check:set(server_url, status)

    logger.info("Health check: " .. server_url .. " is " .. status)
end

-- 增加失败/成功计数
local function increment_counter(server_url, counter_type)
    local health_check = ngx_shared.health_check
    local key = server_url .. ":" .. counter_type
    local count = health_check:get(key) or 0
    count = count + 1
    health_check:set(key, count)
    return count
end

-- 重置计数器
local function reset_counter(server_url, counter_type)
    local health_check = ngx_shared.health_check
    local key = server_url .. ":" .. counter_type
    health_check:delete(key)
end

-- 执行单个服务器的健康检查
local function check_server(server_url)
    local httpc = http.new()
    httpc:set_timeout(config.timeout)

    local url = server_url .. config.http_path
    local res, err = httpc:request_uri(url, {
        method = "GET",
        keepalive_timeout = 60000,
        keepalive_pool = 10,
    })

    if not res then
        -- 请求失败
        reset_counter(server_url, "success")
        local fail_count = increment_counter(server_url, "fail")

        if fail_count >= config.fall then
            set_server_status(server_url, "down")
        end

        logger.error("Health check failed: " .. server_url .. " - " .. (err or "unknown error"))
        return false
    end

    -- 检查状态码
    if res.status >= 200 and res.status < 300 then
        -- 检查成功
        reset_counter(server_url, "fail")
        local success_count = increment_counter(server_url, "success")

        if success_count >= config.rise then
            set_server_status(server_url, "up")
        end

        return true
    else
        -- 状态码异常
        reset_counter(server_url, "success")
        local fail_count = increment_counter(server_url, "fail")

        if fail_count >= config.fall then
            set_server_status(server_url, "down")
        end

        logger.warn("Health check bad status: " .. server_url .. " - " .. res.status)
        return false
    end
end

-- 健康检查定时任务
local function check_all_servers(premature)
    if premature then
        return
    end

    -- 只在 worker 0 中执行
    if ngx_worker_id() ~= 0 then
        return
    end

    local CONFIG = _G.CONFIG
    if not CONFIG or not CONFIG.servers then
        ngx_timer_at(config.interval, check_all_servers)
        return
    end

    -- 检查所有服务器
    for _, server in ipairs(CONFIG.servers) do
        local ok, err = pcall(check_server, server.url)
        if not ok then
            logger.error("Health check error: " .. server.url .. " - " .. tostring(err))
        end
    end

    -- 继续下一次检查
    ngx_timer_at(config.interval, check_all_servers)
end

-- 启动健康检查
function _M.start()
    -- 只在 worker 0 中启动
    if ngx_worker_id() == 0 then
        logger.info("Starting health checker...")
        ngx_timer_at(0, check_all_servers)
    end
end

-- 被动健康检查（在请求失败时调用）
function _M.mark_failed(server_url)
    reset_counter(server_url, "success")
    local fail_count = increment_counter(server_url, "fail")

    if fail_count >= config.fall then
        set_server_status(server_url, "down")
    end
end

-- 被动健康检查（在请求成功时调用）
function _M.mark_success(server_url)
    reset_counter(server_url, "fail")
    local success_count = increment_counter(server_url, "success")

    if success_count >= config.rise then
        set_server_status(server_url, "up")
    end
end

return _M
