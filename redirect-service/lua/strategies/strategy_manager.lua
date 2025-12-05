-- strategies/strategy_manager.lua
-- 分流策略管理器

local geo_strategy = require "strategies.geo_strategy"
local ip_strategy = require "strategies.ip_strategy"
local asn_strategy = require "strategies.asn_strategy"
local hash_strategy = require "strategies.hash_strategy"
local weight_strategy = require "strategies.weight_strategy"

local _M = {}

local strategies = {
    geo = geo_strategy,
    ip = ip_strategy,
    asn = asn_strategy,
    hash = hash_strategy,
    weight = weight_strategy,
    round_robin = weight_strategy, -- 默认使用权重策略
}

-- 复合策略解析
-- 例如: "geo+asn" 表示先用 geo 策略，如果匹配不到再用 asn 策略
local function parse_composite_strategy(strategy_name)
    local parts = {}
    for part in strategy_name:gmatch("[^+]+") do
        table.insert(parts, part)
    end
    return parts
end

-- 选择目标服务器
function _M.select(strategy_name, targets, client_info)
    if not strategy_name or not targets or #targets == 0 then
        return nil
    end

    -- 处理复合策略
    local strategy_parts = parse_composite_strategy(strategy_name)

    for _, part in ipairs(strategy_parts) do
        local strategy = strategies[part]
        if strategy and strategy.select then
            local target = strategy.select(targets, client_info)
            if target then
                return target
            end
        end
    end

    -- 降级到权重策略
    return weight_strategy.select(targets, client_info)
end

-- 注册自定义策略
function _M.register(name, strategy)
    strategies[name] = strategy
end

return _M
