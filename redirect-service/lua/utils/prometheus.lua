local prometheus = require("resty.prometheus")
local logger = require("utils.logger")
local _M = {}
local prom
local metrics = {}
function _M.init()
    prom = prometheus.init("prometheus_metrics")
    metrics.http_requests_total = prom:counter("short_link_http_requests_total", "Total HTTP requests", {"method", "status", "service_type"})
    metrics.redirect_requests_total = prom:counter("short_link_redirect_requests_total", "Total redirect requests", {"service_type", "status"})
    metrics.mysql_operations_total = prom:counter("short_link_mysql_operations_total", "Total MySQL operations", {"operation", "status"})
    metrics.redis_operations_total = prom:counter("short_link_redis_operations_total", "Total Redis operations", {"operation", "status"})
    metrics.cache_hit_rate = prom:gauge("short_link_cache_hit_rate", "Cache hit rate", {"service_type"})
    metrics.short_links_total = prom:gauge("short_link_short_links_total", "Total number of short links", {"service_type", "status"})
    metrics.active_connections = prom:gauge("short_link_active_connections", "Number of active connections")
    metrics.database_connections = prom:gauge("short_link_database_connections", "Number of database connections", {"pool"})
    metrics.http_request_duration = prom:histogram("short_link_http_request_duration_seconds", "HTTP request latency", {"method", "status", "service_type"}, {0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5})
    metrics.redirect_duration = prom:histogram("short_link_redirect_duration_seconds", "Redirect request latency", {"service_type"}, {0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1})
    metrics.api_errors_total = prom:counter("short_link_api_errors_total", "Total API errors", {"api", "error_code"})
    metrics.rate_limit_exceeded_total = prom:counter("short_link_rate_limit_exceeded_total", "Total rate limit exceeded events", {"service_type"})
    logger.info("Prometheus metrics initialized")
end
function _M.http_request(method, status, service_type)
    if metrics.http_requests_total then metrics.http_requests_total:inc(1, {method, tostring(status), service_type or "unknown"}) end
end
function _M.redirect_request(service_type, status)
    if metrics.redirect_requests_total then metrics.redirect_requests_total:inc(1, {service_type or "unknown", status or "success"}) end
end
function _M.mysql_operation(operation, status)
    if metrics.mysql_operations_total then metrics.mysql_operations_total:inc(1, {operation, status or "success"}) end
end
function _M.redis_operation(operation, status)
    if metrics.redis_operations_total then metrics.redis_operations_total:inc(1, {operation, status or "success"}) end
end
function _M.set_cache_hit_rate(service_type, rate)
    if metrics.cache_hit_rate then metrics.cache_hit_rate:set(rate, {service_type or "unknown"}) end
end
function _M.set_short_links_total(service_type, status, count)
    if metrics.short_links_total then metrics.short_links_total:set(count, {service_type or "unknown", status or "active"}) end
end
function _M.set_active_connections(count)
    if metrics.active_connections then metrics.active_connections:set(count) end
end
function _M.set_database_connections(pool, count)
    if metrics.database_connections then metrics.database_connections:set(count, {pool or "default"}) end
end
function _M.observe_http_duration(method, status, service_type, duration)
    if metrics.http_request_duration then metrics.http_request_duration:observe(duration, {method, tostring(status), service_type or "unknown"}) end
end
function _M.observe_redirect_duration(service_type, duration)
    if metrics.redirect_duration then metrics.redirect_duration:observe(duration, {service_type or "unknown"}) end
end
function _M.api_error(api, error_code)
    if metrics.api_errors_total then metrics.api_errors_total:inc(1, {api, error_code or "unknown"}) end
end
function _M.rate_limit_exceeded(service_type)
    if metrics.rate_limit_exceeded_total then metrics.rate_limit_exceeded_total:inc(1, {service_type or "unknown"}) end
end
function _M.collect()
    if not prom then return "# Prometheus not initialized\n" end
    return prom:collect()
end
return _M