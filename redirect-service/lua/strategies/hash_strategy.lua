-- strategies/hash_strategy.lua
-- 一致性哈希策略（同一用户访问同一服务器）

local _M = {}

-- 简单哈希函数
local function hash(str)
    local h = 0
    for i = 1, #str do
        h = (h * 31 + string.byte(str, i)) % 2^32
    end
    return h
end

-- 一致性哈希选择
function _M.select(targets, client_info)
    if #targets == 0 then
        return nil
    end

    -- 使用客户端 IP 作为哈希 key
    local hash_key = client_info.ip
    local hash_value = hash(hash_key)

    -- 选择目标
    local index = (hash_value % #targets) + 1
    return targets[index]
end

return _M
