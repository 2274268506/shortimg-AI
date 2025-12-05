-- api/metrics.lua
-- Prometheus 指标暴露 API

local prometheus = require "utils.prometheus"

local _M = {}

-- GET /metrics - Prometheus 指标端点
function _M.metrics()
    ngx.header.content_type = "text/plain"
    ngx.say(prometheus.collect())
end

-- GET /metrics/health - 监控系统健康状态
function _M.health()
    local cjson = require "cjson.safe"

    local health_status = {
        status = "healthy",
        timestamp = ngx.time(),
        metrics = {
            collected = true,
            endpoints = {
                "/metrics",
                "/metrics/health"
            }
        }
    }

    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode(health_status))
end

return _M
