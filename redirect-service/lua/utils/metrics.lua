-- utils/metrics.lua
-- 监控指标模块

local _M = {}

local ngx_shared = ngx.shared

-- 增加计数器
function _M.incr(metric_name, value)
    value = value or 1
    local stats = ngx_shared.stats
    if not stats then
        return
    end

    local newval, err = stats:incr(metric_name, value)
    if not newval and err == "not found" then
        stats:set(metric_name, value)
    end
end

-- 获取计数器
function _M.get(metric_name)
    local stats = ngx_shared.stats
    if not stats then
        return 0
    end

    return stats:get(metric_name) or 0
end

-- 设置值
function _M.set(metric_name, value)
    local stats = ngx_shared.stats
    if not stats then
        return
    end

    stats:set(metric_name, value)
end

-- 记录响应时间
function _M.record_latency(metric_name, latency)
    -- 简单实现：记录最小、最大、平均值
    local stats = ngx_shared.stats
    if not stats then
        return
    end

    -- 最小值
    local min_key = metric_name .. ":min"
    local min = stats:get(min_key)
    if not min or latency < min then
        stats:set(min_key, latency)
    end

    -- 最大值
    local max_key = metric_name .. ":max"
    local max = stats:get(max_key)
    if not max or latency > max then
        stats:set(max_key, latency)
    end

    -- 总和和计数用于计算平均值
    local sum_key = metric_name .. ":sum"
    local count_key = metric_name .. ":count"

    local newsum, err = stats:incr(sum_key, latency)
    if not newsum and err == "not found" then
        stats:set(sum_key, latency)
    end

    local newcount, err = stats:incr(count_key, 1)
    if not newcount and err == "not found" then
        stats:set(count_key, 1)
    end
end

-- 获取延迟统计
function _M.get_latency_stats(metric_name)
    local stats = ngx_shared.stats
    if not stats then
        return nil
    end

    local min = stats:get(metric_name .. ":min") or 0
    local max = stats:get(metric_name .. ":max") or 0
    local sum = stats:get(metric_name .. ":sum") or 0
    local count = stats:get(metric_name .. ":count") or 0

    local avg = 0
    if count > 0 then
        avg = sum / count
    end

    return {
        min = min,
        max = max,
        avg = avg,
        count = count,
    }
end

-- 获取所有指标
function _M.get_all()
    local stats = ngx_shared.stats
    if not stats then
        return {}
    end

    local keys = stats:get_keys(0)
    local metrics = {}

    for _, key in ipairs(keys) do
        metrics[key] = stats:get(key)
    end

    return metrics
end

-- 重置指标
function _M.reset(metric_name)
    local stats = ngx_shared.stats
    if not stats then
        return
    end

    if metric_name then
        stats:delete(metric_name)
    else
        stats:flush_all()
    end
end

return _M
