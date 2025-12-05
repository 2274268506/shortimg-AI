-- utils/geoip.lua
-- GeoIP 解析模块

local geoip = require "resty.maxminddb"
local logger = require "utils.logger"

local _M = {}

local geo_db = nil
local asn_db = nil

-- 初始化 GeoIP 数据库
function _M.init(config)
    if config.geo_db_path then
        local err
        geo_db, err = geoip.new(config.geo_db_path)
        if not geo_db then
            logger.error("加载 GeoLite2-City 数据库失败: " .. (err or "unknown"))
        else
            logger.info("GeoLite2-City 数据库加载成功")
        end
    end

    if config.asn_db_path then
        local err
        asn_db, err = geoip.new(config.asn_db_path)
        if not asn_db then
            logger.error("加载 GeoLite2-ASN 数据库失败: " .. (err or "unknown"))
        else
            logger.info("GeoLite2-ASN 数据库加载成功")
        end
    end
end

-- 查询地理位置
function _M.lookup(ip)
    local result = {
        country = "UNKNOWN",
        province = "UNKNOWN",
        city = "UNKNOWN",
        isp = "UNKNOWN",
        asn = "UNKNOWN",
    }

    if not ip then
        return result
    end

    -- 查询国家、省份、城市
    if geo_db then
        local res, err = geo_db:lookup(ip)
        if res then
            if res.country and res.country.names and res.country.names.zh_CN then
                result.country = res.country.iso_code or "UNKNOWN"
            end

            if res.subdivisions and #res.subdivisions > 0 then
                local subdivision = res.subdivisions[1]
                if subdivision.names and subdivision.names.zh_CN then
                    result.province = subdivision.names.zh_CN
                elseif subdivision.names and subdivision.names.en then
                    result.province = subdivision.names.en
                end
            end

            if res.city and res.city.names then
                if res.city.names.zh_CN then
                    result.city = res.city.names.zh_CN
                elseif res.city.names.en then
                    result.city = res.city.names.en
                end
            end
        else
            logger.debug("GeoIP 查询失败: " .. ip .. " - " .. (err or "unknown"))
        end
    end

    -- 查询 ASN 和 ISP
    if asn_db then
        local res, err = asn_db:lookup(ip)
        if res then
            if res.autonomous_system_number then
                result.asn = "AS" .. tostring(res.autonomous_system_number)
            end

            if res.autonomous_system_organization then
                result.isp = res.autonomous_system_organization
            end
        else
            logger.debug("ASN 查询失败: " .. ip .. " - " .. (err or "unknown"))
        end
    end

    return result
end

return _M
