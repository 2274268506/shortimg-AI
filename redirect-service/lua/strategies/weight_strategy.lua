-- strategies/weight_strategy.lua
-- 权重轮询策略

local _M = {}

local ngx_shared = ngx.shared

-- 加权轮询选择
function _M.select(targets, client_info)
    if #targets == 0 then
        return nil
    end

    -- 计算总权重
    local total_weight = 0
    for _, target in ipairs(targets) do
        total_weight = total_weight + (target.weight or 1)
    end

    -- 使用共享内存保存当前权重
    local stats = ngx_shared.stats
    local key = "weight_counter"
    local counter = stats:get(key) or 0
    counter = (counter + 1) % total_weight
    stats:set(key, counter)

    -- 根据权重选择
    local current_weight = 0
    for _, target in ipairs(targets) do
        current_weight = current_weight + (target.weight or 1)
        if counter < current_weight then
            return target
        end
    end

    return targets[1]
end

return _M
