-- strategies/geo_strategy.lua
-- 基于地理位置的分流策略

local _M = {}

-- 地区优先级配置
local region_priority = {
    ["cn-north"] = {"北京", "天津", "河北", "山西", "内蒙古", "辽宁", "吉林", "黑龙江"},
    ["cn-east"] = {"上海", "江苏", "浙江", "安徽", "福建", "江西", "山东"},
    ["cn-south"] = {"广东", "广西", "海南", "湖南", "湖北"},
    ["cn-west"] = {"重庆", "四川", "贵州", "云南", "西藏", "陕西", "甘肃", "青海", "宁夏", "新疆"},
    ["cn-central"] = {"河南"},
    ["overseas"] = {}
}

-- 判断省份属于哪个区域
local function get_region_by_province(province)
    for region, provinces in pairs(region_priority) do
        for _, prov in ipairs(provinces) do
            if province:find(prov) then
                return region
            end
        end
    end
    return "overseas" -- 默认海外
end

-- ISP 映射
local isp_map = {
    ["China Telecom"] = "telecom",
    ["China Unicom"] = "unicom",
    ["China Mobile"] = "mobile",
    ["ChinaNet"] = "telecom",
    ["CERNET"] = "edu",
}

local function normalize_isp(isp_name)
    if not isp_name then
        return "unknown"
    end

    for pattern, normalized in pairs(isp_map) do
        if isp_name:find(pattern) then
            return normalized
        end
    end

    return "unknown"
end

-- 根据地理位置选择目标
function _M.select(targets, client_info)
    local country = client_info.country or "UNKNOWN"
    local province = client_info.province or "UNKNOWN"
    local isp = normalize_isp(client_info.isp)

    -- 如果不是中国，选择海外节点
    if country ~= "CN" then
        for _, target in ipairs(targets) do
            if target.region == "overseas" then
                return target
            end
        end
    end

    -- 根据省份确定区域
    local region = get_region_by_province(province)

    -- 优先匹配：区域 + ISP
    for _, target in ipairs(targets) do
        if target.region == region and target.isp == isp then
            return target
        end
    end

    -- 次优匹配：仅区域
    for _, target in ipairs(targets) do
        if target.region == region then
            return target
        end
    end

    -- 如果都不匹配，返回 nil 让策略管理器降级
    return nil
end

return _M
