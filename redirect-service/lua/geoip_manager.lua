-- geoip_manager.lua
-- GeoIP 数据库管理器 - 根据分流规则自动选择合适的数据库

local _M = {}

-- GeoIP 数据库配置
local GEOIP_DATABASES = {
    -- 纯真IP数据库 (qqwry.dat) - 适合国内IP查询
    qqwry = {
        path = "/usr/local/openresty/nginx/geoip/qqwry.dat",
        type = "qqwry",
        name = "纯真IP数据库",
        description = "国内IP数据库，包含详细的省份、城市、运营商信息",
        suitable_for = {
            country = {"CN"},  -- 适合中国IP
            has_isp = true,     -- 包含运营商信息
            has_province = true -- 包含省份信息
        },
        priority = 10  -- 优先级（数字越小优先级越高）
    },

    -- MaxMind GeoLite2 Country (国家级) - 适合国家级分流
    geolite2_country = {
        path = "/usr/local/openresty/nginx/geoip/GeoLite2-Country.mmdb",
        type = "maxmind",
        name = "GeoLite2 Country",
        description = "全球国家级IP数据库，体积小，查询快",
        suitable_for = {
            country = {"*"},    -- 适合所有国家
            has_isp = false,
            has_province = false,
            global = true       -- 全球数据
        },
        priority = 20
    },

    -- MaxMind GeoLite2 City (城市级) - 最详细但体积大
    geolite2_city = {
        path = "/usr/local/openresty/nginx/geoip/GeoLite2-City.mmdb",
        type = "maxmind",
        name = "GeoLite2 City",
        description = "全球城市级IP数据库，包含经纬度、时区等详细信息",
        suitable_for = {
            country = {"*"},
            has_isp = false,
            has_province = true,
            has_city = true,
            global = true
        },
        priority = 30
    },

    -- MaxMind GeoLite2 ASN - 适合ASN路由
    geolite2_asn = {
        path = "/usr/local/openresty/nginx/geoip/GeoLite2-ASN.mmdb",
        type = "maxmind",
        name = "GeoLite2 ASN",
        description = "全球ASN数据库，用于运营商识别",
        suitable_for = {
            has_asn = true,
            has_isp = true
        },
        priority = 15
    }
}

-- 日志函数
local function log(level, msg)
    ngx.log(level, "[GeoIPManager] ", msg)
end

-- 分析路由规则需要的GeoIP能力
local function analyze_routing_requirements(routing_rules)
    local requirements = {
        need_country = false,
        need_province = false,
        need_city = false,
        need_isp = false,
        need_asn = false,
        countries = {}
    }

    for _, rule in ipairs(routing_rules or {}) do
        if rule.enabled ~= false then
            for _, condition in ipairs(rule.conditions or {}) do
                local ctype = condition.type

                if ctype == "country" then
                    requirements.need_country = true
                    if condition.value then
                        requirements.countries[condition.value] = true
                    end
                elseif ctype == "province" then
                    requirements.need_province = true
                elseif ctype == "city" then
                    requirements.need_city = true
                elseif ctype == "isp" then
                    requirements.need_isp = true
                elseif ctype == "asn" then
                    requirements.need_asn = true
                end
            end
        end
    end

    return requirements
end

-- 计算数据库匹配分数
local function calculate_database_score(db_info, requirements)
    local score = 0

    -- 优先级基础分（优先级越高分数越低）
    score = 100 - db_info.priority

    -- 功能匹配加分
    if requirements.need_country and db_info.suitable_for.country then
        score = score + 20
    end

    if requirements.need_province and db_info.suitable_for.has_province then
        score = score + 15
    end

    if requirements.need_city and db_info.suitable_for.has_city then
        score = score + 15
    end

    if requirements.need_isp and db_info.suitable_for.has_isp then
        score = score + 25
    end

    if requirements.need_asn and db_info.suitable_for.has_asn then
        score = score + 20
    end

    -- 针对特定国家的加分
    local has_cn_requirement = requirements.countries["CN"]
    if has_cn_requirement then
        -- 如果需要查询中国IP
        if db_info.suitable_for.country then
            for _, country in ipairs(db_info.suitable_for.country) do
                if country == "CN" then
                    score = score + 30  -- 专门针对CN的数据库加分
                    break
                end
            end
        end
    end

    -- 全球数据库基础分
    if db_info.suitable_for.global then
        score = score + 10
    end

    return score
end

-- 选择最佳GeoIP数据库组合
function _M.select_databases(routing_rules)
    local requirements = analyze_routing_requirements(routing_rules)

    log(ngx.INFO, string.format(
        "路由需求分析: country=%s, province=%s, city=%s, isp=%s, asn=%s",
        tostring(requirements.need_country),
        tostring(requirements.need_province),
        tostring(requirements.need_city),
        tostring(requirements.need_isp),
        tostring(requirements.need_asn)
    ))

    -- 计算每个数据库的得分
    local scored_databases = {}
    for db_id, db_info in pairs(GEOIP_DATABASES) do
        local score = calculate_database_score(db_info, requirements)
        table.insert(scored_databases, {
            id = db_id,
            info = db_info,
            score = score
        })
    end

    -- 按分数排序
    table.sort(scored_databases, function(a, b)
        return a.score > b.score
    end)

    -- 选择数据库组合
    local selected = {}
    local covered_features = {
        country = false,
        province = false,
        city = false,
        isp = false,
        asn = false
    }

    -- 优先选择高分数据库
    for _, db in ipairs(scored_databases) do
        local db_info = db.info
        local should_select = false

        -- 检查是否需要这个数据库
        if requirements.need_country and not covered_features.country then
            if db_info.suitable_for.country then
                should_select = true
                covered_features.country = true
            end
        end

        if requirements.need_province and not covered_features.province then
            if db_info.suitable_for.has_province then
                should_select = true
                covered_features.province = true
            end
        end

        if requirements.need_city and not covered_features.city then
            if db_info.suitable_for.has_city then
                should_select = true
                covered_features.city = true
            end
        end

        if requirements.need_isp and not covered_features.isp then
            if db_info.suitable_for.has_isp then
                should_select = true
                covered_features.isp = true
            end
        end

        if requirements.need_asn and not covered_features.asn then
            if db_info.suitable_for.has_asn then
                should_select = true
                covered_features.asn = true
            end
        end

        if should_select then
            table.insert(selected, {
                id = db.id,
                path = db_info.path,
                type = db_info.type,
                name = db_info.name,
                score = db.score
            })

            log(ngx.INFO, string.format(
                "选择数据库: %s (%s) - 得分: %d",
                db_info.name, db.id, db.score
            ))
        end
    end

    -- 如果没有选择任何数据库，使用默认的 Country 数据库
    if #selected == 0 then
        log(ngx.WARN, "未找到匹配的数据库，使用默认 GeoLite2-Country")
        table.insert(selected, {
            id = "geolite2_country",
            path = GEOIP_DATABASES.geolite2_country.path,
            type = GEOIP_DATABASES.geolite2_country.type,
            name = GEOIP_DATABASES.geolite2_country.name,
            score = 0
        })
    end

    return selected
end

-- 获取所有可用数据库信息
function _M.get_available_databases()
    local available = {}

    for db_id, db_info in pairs(GEOIP_DATABASES) do
        -- 检查文件是否存在
        local file = io.open(db_info.path, "r")
        local exists = file ~= nil
        if exists then
            file:close()
        end

        table.insert(available, {
            id = db_id,
            name = db_info.name,
            path = db_info.path,
            type = db_info.type,
            description = db_info.description,
            exists = exists,
            priority = db_info.priority
        })
    end

    -- 按优先级排序
    table.sort(available, function(a, b)
        return a.priority < b.priority
    end)

    return available
end

-- 生成推荐的数据库配置
function _M.generate_recommendations(routing_rules)
    local requirements = analyze_routing_requirements(routing_rules)
    local selected = _M.select_databases(routing_rules)

    local recommendations = {
        requirements = requirements,
        selected_databases = selected,
        summary = ""
    }

    -- 生成总结
    local summary_parts = {}
    table.insert(summary_parts, "根据您的路由规则分析：")

    if requirements.need_isp or requirements.need_province then
        table.insert(summary_parts, "- 建议使用 qqwry.dat (纯真IP库) 用于国内IP的运营商和省份识别")
    end

    if requirements.need_country then
        table.insert(summary_parts, "- 建议使用 GeoLite2-Country.mmdb 用于快速的国家级分流")
    end

    if requirements.need_asn then
        table.insert(summary_parts, "- 建议使用 GeoLite2-ASN.mmdb 用于ASN/运营商识别")
    end

    if requirements.need_city then
        table.insert(summary_parts, "- 建议使用 GeoLite2-City.mmdb 用于详细的城市级定位")
    end

    recommendations.summary = table.concat(summary_parts, "\n")

    return recommendations
end

-- 验证数据库文件
function _M.validate_databases()
    local results = {}

    for db_id, db_info in pairs(GEOIP_DATABASES) do
        local file = io.open(db_info.path, "r")
        local status = {
            id = db_id,
            name = db_info.name,
            path = db_info.path,
            exists = false,
            readable = false,
            size = 0
        }

        if file then
            status.exists = true
            status.readable = true

            -- 获取文件大小
            local current_pos = file:seek()
            local size = file:seek("end")
            file:seek("set", current_pos)
            status.size = size

            file:close()
        end

        table.insert(results, status)
    end

    return results
end

return _M
