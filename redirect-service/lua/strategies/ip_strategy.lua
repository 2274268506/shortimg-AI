-- strategies/ip_strategy.lua
-- 基于 IP 段的分流策略

local _M = {}

-- IP 转数字
local function ip_to_num(ip)
    if not ip then return 0 end

    local parts = {}
    for part in ip:gmatch("%d+") do
        table.insert(parts, tonumber(part))
    end

    if #parts ~= 4 then
        return 0
    end

    return parts[1] * 16777216 + parts[2] * 65536 + parts[3] * 256 + parts[4]
end

-- 检查 IP 是否在范围内
local function ip_in_range(ip, cidr)
    if not cidr then return false end

    local ip_cidr, mask = cidr:match("([^/]+)/(%d+)")
    if not ip_cidr or not mask then
        return false
    end

    local ip_num = ip_to_num(ip)
    local cidr_num = ip_to_num(ip_cidr)
    local mask_num = bit.lshift(0xFFFFFFFF, 32 - tonumber(mask))

    return bit.band(ip_num, mask_num) == bit.band(cidr_num, mask_num)
end

-- 根据 IP 段选择目标
function _M.select(targets, client_info)
    local ip = client_info.ip
    if not ip then
        return nil
    end

    -- 遍历所有目标，查找匹配的 IP 段
    for _, target in ipairs(targets) do
        if target.ip_ranges then
            for _, range in ipairs(target.ip_ranges) do
                if ip_in_range(ip, range) then
                    return target
                end
            end
        end
    end

    return nil
end

return _M
