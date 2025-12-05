-- utils/prometheus.lua
-- Prometheus 指标收集模块

local _M = {}

-- 初始化 Prometheus 库
local prometheus = require("resty.prometheus").init("prometheus_metrics", "short_link_")

-- 定义指标
-- 1. 计数器（Counter）- 只增不减
_M.http_requests_total = prometheus:counter(
    "http_requests_total",
    "Total HTTP requests",
    {"method", "endpoint", "status"}
)

_M.redirect_requests_total = prometheus:counter(
    "redirect_requests_total",
    "Total redirect requests",
    {"short_code", "status"}
)

-- 2. 直方图（Histogram）- 统计分布
_M.http_request_duration_seconds = prometheus:histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    {"method", "endpoint"},
    {0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}
)

_M.redirect_duration_seconds = prometheus:histogram(
    "redirect_duration_seconds",
    "Redirect request latency",
    {"short_code"},
    {0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1}
)

-- 3. 仪表盘（Gauge）- 可增可减
_M.active_connections = prometheus:gauge(
    "active_connections",
    "Number of active connections"
)

_M.cache_hit_rate = prometheus:gauge(
    "cache_hit_rate",
    "Cache hit rate",
    {"cache_type"}
)

_M.database_connections = prometheus:gauge(
    "database_connections",
    "Number of database connections",
    {"database", "state"}
)

-- 4. 业务指标
_M.short_links_total = prometheus:gauge(
    "short_links_total",
    "Total number of short links"
)

_M.api_errors_total = prometheus:counter(
    "api_errors_total",
    "Total API errors",
    {"endpoint", "error_type"}
)

_M.rate_limit_exceeded_total = prometheus:counter(
    "rate_limit_exceeded_total",
    "Total rate limit exceeded events",
    {"endpoint"}
)

-- Redis 指标
_M.redis_operations_total = prometheus:counter(
    "redis_operations_total",
    "Total Redis operations",
    {"operation", "status"}
)

_M.redis_operation_duration_seconds = prometheus:histogram(
    "redis_operation_duration_seconds",
    "Redis operation duration",
    {"operation"},
    {0.0001, 0.0005, 0.001, 0.005, 0.01, 0.025, 0.05, 0.1}
)

-- MySQL 指标
_M.mysql_queries_total = prometheus:counter(
    "mysql_queries_total",
    "Total MySQL queries",
    {"query_type", "status"}
)

_M.mysql_query_duration_seconds = prometheus:histogram(
    "mysql_query_duration_seconds",
    "MySQL query duration",
    {"query_type"},
    {0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2}
)

-- 辅助函数：记录 HTTP 请求
function _M.record_http_request(method, endpoint, status, duration)
    _M.http_requests_total:inc(1, {method, endpoint, tostring(status)})
    if duration then
        _M.http_request_duration_seconds:observe(duration, {method, endpoint})
    end
end

-- 辅助函数：记录重定向
function _M.record_redirect(short_code, status, duration)
    _M.redirect_requests_total:inc(1, {short_code, tostring(status)})
    if duration then
        _M.redirect_duration_seconds:observe(duration, {short_code})
    end
end

-- 辅助函数：记录缓存命中
function _M.record_cache_hit(cache_type, hit)
    local key = "cache_stats:" .. cache_type
    local stats_dict = ngx.shared.metrics

    if hit then
        stats_dict:incr(key .. ":hits", 1, 0)
    else
        stats_dict:incr(key .. ":misses", 1, 0)
    end

    -- 计算命中率
    local hits = stats_dict:get(key .. ":hits") or 0
    local misses = stats_dict:get(key .. ":misses") or 0
    local total = hits + misses

    if total > 0 then
        local hit_rate = hits / total
        _M.cache_hit_rate:set(hit_rate, {cache_type})
    end
end

-- 辅助函数：记录 Redis 操作
function _M.record_redis_operation(operation, status, duration)
    _M.redis_operations_total:inc(1, {operation, status})
    if duration then
        _M.redis_operation_duration_seconds:observe(duration, {operation})
    end
end

-- 辅助函数：记录 MySQL 查询
function _M.record_mysql_query(query_type, status, duration)
    _M.mysql_queries_total:inc(1, {query_type, status})
    if duration then
        _M.mysql_query_duration_seconds:observe(duration, {query_type})
    end
end

-- 辅助函数：记录错误
function _M.record_error(endpoint, error_type)
    _M.api_errors_total:inc(1, {endpoint, error_type})
end

-- 辅助函数：记录速率限制
function _M.record_rate_limit(endpoint)
    _M.rate_limit_exceeded_total:inc(1, {endpoint})
end

-- 获取指标数据（用于 /metrics 端点）
function _M.collect()
    return prometheus:collect()
end

return _M
