-- api/stats.lua
-- 统计 API 模块

local cjson = require "cjson.safe"
local metrics = require "utils.metrics"

local _M = {}

local ngx_say = ngx.say

-- 响应 JSON
local function respond_json(data)
    ngx.header["Content-Type"] = "application/json"
    ngx_say(cjson.encode(data))
end

-- 获取所有指标
function _M.get_all()
    local all_metrics = metrics.get_all()

    -- 组织指标数据
    local stats = {
        requests = {
            total = metrics.get("requests:total"),
            success = metrics.get("requests:success"),
            error = metrics.get("requests:error"),
            not_found = metrics.get("requests:not_found"),
            forbidden = metrics.get("requests:forbidden"),
        },
        latency = metrics.get_latency_stats("latency:redirect"),
        cache = {
            hits = metrics.get("cache:hits"),
            misses = metrics.get("cache:misses"),
            hit_rate = 0,
        },
        strategy = {},
        device = {
            desktop = metrics.get("device:desktop"),
            mobile = metrics.get("device:mobile"),
            tablet = metrics.get("device:tablet"),
        },
        region = {},
    }

    -- 计算缓存命中率
    local total_cache = stats.cache.hits + stats.cache.misses
    if total_cache > 0 then
        stats.cache.hit_rate = stats.cache.hits / total_cache * 100
    end

    -- 提取策略统计
    for key, value in pairs(all_metrics) do
        if key:match("^strategy:") then
            local strategy_name = key:gsub("^strategy:", "")
            stats.strategy[strategy_name] = value
        elseif key:match("^region:") then
            local region_name = key:gsub("^region:", "")
            stats.region[region_name] = value
        end
    end

    respond_json({
        success = true,
        data = stats
    })
end

-- 重置指标
function _M.reset()
    metrics.reset()

    respond_json({
        success = true,
        message = "指标已重置"
    })
end

return _M
