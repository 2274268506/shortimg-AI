-- geoip_query.lua
-- 统一的 GeoIP 查询接口，支持 qqwry.dat 和 MaxMind MMDB

local _M = {}

-- 缓存已加载的数据库
local loaded_databases = {}

-- 日志函数
local function log(level, msg)
    ngx.log(level, "[GeoIPQuery] ", msg)
end

-- 加载 MaxMind MMDB 数据库
local function load_maxmind_db(db_path)
    if loaded_databases[db_path] then
        return loaded_databases[db_path]
    end

    local ok, geoip = pcall(require, "resty.maxminddb")
    if not ok then
        log(ngx.ERR, "无法加载 resty.maxminddb 模块")
        return nil
    end

    local db, err = geoip:new(db_path)
    if not db then
        log(ngx.ERR, "无法打开 MaxMind 数据库: " .. db_path .. ", error: " .. tostring(err))
        return nil
    end

    loaded_databases[db_path] = {
        type = "maxmind",
        db = db
    }

    log(ngx.INFO, "已加载 MaxMind 数据库: " .. db_path)
    return loaded_databases[db_path]
end

-- 加载纯真IP数据库 (qqwry.dat)
local function load_qqwry_db(db_path)
    if loaded_databases[db_path] then
        return loaded_databases[db_path]
    end

    local ok, qqwry = pcall(require, "qqwry")
    if not ok then
        log(ngx.ERR, "无法加载 qqwry 模块")
        return nil
    end

    local db, err = qqwry:new(db_path)
    if not db then
        log(ngx.ERR, "无法打开纯真IP数据库: " .. db_path .. ", error: " .. tostring(err))
        return nil
    end

    loaded_databases[db_path] = {
        type = "qqwry",
        db = db
    }

    log(ngx.INFO, "已加载纯真IP数据库: " .. db_path)
    return loaded_databases[db_path]
end

-- 加载数据库 (自动识别类型)
function _M.load_database(db_path, db_type)
    if db_type == "maxmind" then
        return load_maxmind_db(db_path)
    elseif db_type == "qqwry" then
        return load_qqwry_db(db_path)
    else
        -- 根据文件扩展名自动识别
        if db_path:match("%.mmdb$") then
            return load_maxmind_db(db_path)
        elseif db_path:match("%.dat$") then
            return load_qqwry_db(db_path)
        else
            log(ngx.ERR, "无法识别数据库类型: " .. db_path)
            return nil
        end
    end
end

-- 查询 MaxMind 数据库
local function query_maxmind(db_wrapper, ip)
    local db = db_wrapper.db
    local res, err = db:lookup(ip)

    if not res then
        return nil, err
    end

    local result = {
        ip = ip,
        country = nil,
        country_code = nil,
        province = nil,
        city = nil,
        isp = nil,
        asn = nil,
        latitude = nil,
        longitude = nil,
        source = "maxmind"
    }

    -- 提取国家信息
    if res.country then
        result.country = res.country.names and res.country.names.en
        result.country_code = res.country.iso_code
    end

    if res.registered_country then
        result.country = result.country or (res.registered_country.names and res.registered_country.names.en)
        result.country_code = result.country_code or res.registered_country.iso_code
    end

    -- 提取省份/州信息
    if res.subdivisions and #res.subdivisions > 0 then
        result.province = res.subdivisions[1].names and res.subdivisions[1].names.en
    end

    -- 提取城市信息
    if res.city then
        result.city = res.city.names and res.city.names.en
    end

    -- 提取经纬度
    if res.location then
        result.latitude = res.location.latitude
        result.longitude = res.location.longitude
    end

    -- 提取ASN信息 (如果是ASN数据库)
    if res.autonomous_system_number then
        result.asn = res.autonomous_system_number
        result.isp = res.autonomous_system_organization
    end

    return result, nil
end

-- 查询纯真IP数据库
local function query_qqwry(db_wrapper, ip)
    local db = db_wrapper.db
    local res, err = db:query(ip)

    if not res then
        return nil, err
    end

    -- 纯真IP库返回格式: {country="国家/省份", area="城市/运营商"}
    local result = {
        ip = ip,
        country = nil,
        country_code = nil,
        province = nil,
        city = nil,
        isp = nil,
        source = "qqwry"
    }

    -- 解析国家/省份字段
    if res.country then
        local country_str = res.country

        -- 判断是否为中国IP
        if country_str:match("中国") or country_str:match("CN") then
            result.country = "China"
            result.country_code = "CN"

            -- 提取省份
            local province = country_str:match("([^%s]+省)") or
                           country_str:match("([^%s]+市)") or  -- 直辖市
                           country_str:match("([^%s]+自治区)") or
                           country_str:match("([^%s]+特别行政区)")
            if province then
                result.province = province
            end
        else
            result.country = country_str
            -- 简单映射常见国家代码
            if country_str:match("美国") or country_str:match("United States") then
                result.country_code = "US"
            elseif country_str:match("日本") or country_str:match("Japan") then
                result.country_code = "JP"
            elseif country_str:match("韩国") or country_str:match("Korea") then
                result.country_code = "KR"
            end
        end
    end

    -- 解析城市/运营商字段
    if res.area then
        local area_str = res.area

        -- 识别运营商
        if area_str:match("电信") or area_str:match("ChinaNet") then
            result.isp = "China Telecom"
        elseif area_str:match("联通") or area_str:match("China Unicom") then
            result.isp = "China Unicom"
        elseif area_str:match("移动") or area_str:match("China Mobile") then
            result.isp = "China Mobile"
        elseif area_str:match("铁通") then
            result.isp = "China Tietong"
        elseif area_str:match("教育网") or area_str:match("CERNET") then
            result.isp = "CERNET"
        else
            -- 尝试提取城市信息
            local city = area_str:match("([^%s]+市)")
            if city then
                result.city = city
            end
        end
    end

    return result, nil
end

-- 统一查询接口
function _M.query(ip, databases)
    local results = {}
    local merged_result = {
        ip = ip,
        country = nil,
        country_code = nil,
        province = nil,
        city = nil,
        isp = nil,
        asn = nil,
        latitude = nil,
        longitude = nil,
        sources = {}
    }

    -- 遍历所有数据库查询
    for _, db_info in ipairs(databases or {}) do
        local db_wrapper = _M.load_database(db_info.path, db_info.type)
        if db_wrapper then
            local result, err

            if db_wrapper.type == "maxmind" then
                result, err = query_maxmind(db_wrapper, ip)
            elseif db_wrapper.type == "qqwry" then
                result, err = query_qqwry(db_wrapper, ip)
            end

            if result then
                table.insert(results, result)
                table.insert(merged_result.sources, result.source)

                -- 合并结果 (优先使用非空值)
                merged_result.country = merged_result.country or result.country
                merged_result.country_code = merged_result.country_code or result.country_code
                merged_result.province = merged_result.province or result.province
                merged_result.city = merged_result.city or result.city
                merged_result.isp = merged_result.isp or result.isp
                merged_result.asn = merged_result.asn or result.asn
                merged_result.latitude = merged_result.latitude or result.latitude
                merged_result.longitude = merged_result.longitude or result.longitude
            else
                log(ngx.WARN, string.format(
                    "查询失败 [%s]: %s - %s",
                    db_info.name or db_info.path,
                    ip,
                    tostring(err)
                ))
            end
        end
    end

    return merged_result, results
end

-- 简化查询 (使用单个数据库)
function _M.query_single(ip, db_path, db_type)
    local db_wrapper = _M.load_database(db_path, db_type)
    if not db_wrapper then
        return nil, "无法加载数据库"
    end

    if db_wrapper.type == "maxmind" then
        return query_maxmind(db_wrapper, ip)
    elseif db_wrapper.type == "qqwry" then
        return query_qqwry(db_wrapper, ip)
    end

    return nil, "未知数据库类型"
end

-- 清理缓存
function _M.clear_cache()
    loaded_databases = {}
    log(ngx.INFO, "已清理数据库缓存")
end

-- 获取已加载的数据库列表
function _M.get_loaded_databases()
    local list = {}
    for path, wrapper in pairs(loaded_databases) do
        table.insert(list, {
            path = path,
            type = wrapper.type
        })
    end
    return list
end

return _M
