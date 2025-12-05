-- strategies/asn_strategy.lua
-- 基于 ASN（自治系统号）的分流策略

local _M = {}

-- ASN 到运营商的映射
local asn_to_isp = {
    -- 中国电信
    ["4134"] = "telecom",
    ["4809"] = "telecom",
    ["23724"] = "telecom",

    -- 中国联通
    ["4837"] = "unicom",
    ["9929"] = "unicom",
    ["17621"] = "unicom",

    -- 中国移动
    ["9808"] = "mobile",
    ["24400"] = "mobile",
    ["24547"] = "mobile",

    -- 教育网
    ["4538"] = "edu",
    ["24349"] = "edu",
}

-- 根据 ASN 选择目标
function _M.select(targets, client_info)
    local asn = client_info.asn
    if not asn or asn == "UNKNOWN" then
        return nil
    end

    -- 去除 "AS" 前缀
    asn = asn:gsub("^AS", "")

    local isp = asn_to_isp[asn]
    if not isp then
        return nil
    end

    -- 查找匹配的 ISP 节点
    for _, target in ipairs(targets) do
        if target.isp == isp then
            return target
        end
    end

    return nil
end

return _M
