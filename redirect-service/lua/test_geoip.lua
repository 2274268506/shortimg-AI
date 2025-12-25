-- test_geoip.lua
-- GeoIP 功能测试脚本

local geoip_manager = require "geoip_manager"
local geoip_query = require "geoip_query"

print("=== GeoIP 数据库管理测试 ===\n")

-- 1. 获取所有可用数据库
print("1. 检查可用的 GeoIP 数据库:")
local available = geoip_manager.get_available_databases()
for i, db in ipairs(available) do
    print(string.format("  [%d] %s (%s)", i, db.name, db.id))
    print(string.format("      路径: %s", db.path))
    print(string.format("      类型: %s", db.type))
    print(string.format("      存在: %s", db.exists and "是" or "否"))
    print(string.format("      优先级: %d", db.priority))
    print(string.format("      说明: %s", db.description))
    print()
end

-- 2. 验证数据库文件
print("\n2. 验证数据库文件:")
local validation = geoip_manager.validate_databases()
for _, status in ipairs(validation) do
    local status_str = status.readable and "✓ 可用" or "✗ 不可用"
    local size_str = status.size > 0 and string.format("%.2f MB", status.size / 1024 / 1024) or "0 B"
    print(string.format("  %s %s - %s", status_str, status.name, size_str))
end

-- 3. 模拟路由规则
print("\n3. 模拟路由规则:")
local mock_rules = {
    {
        name = "国内电信",
        enabled = true,
        conditions = {
            {type = "country", value = "CN"},
            {type = "isp", values = {"China Telecom"}}
        }
    },
    {
        name = "国内联通",
        enabled = true,
        conditions = {
            {type = "country", value = "CN"},
            {type = "province", values = {"北京", "上海"}}
        }
    },
    {
        name = "海外",
        enabled = true,
        conditions = {
            {type = "country", operator = "not_equals", value = "CN"}
        }
    },
    {
        name = "ASN路由",
        enabled = true,
        conditions = {
            {type = "asn", values = {"4134", "4837"}}
        }
    }
}

-- 4. 根据规则选择数据库
print("\n4. 根据路由规则自动选择数据库:")
local selected = geoip_manager.select_databases(mock_rules)
print(string.format("  共选择 %d 个数据库:", #selected))
for i, db in ipairs(selected) do
    print(string.format("  [%d] %s - 得分: %d", i, db.name, db.score))
end

-- 5. 生成推荐
print("\n5. 数据库推荐:")
local recommendations = geoip_manager.generate_recommendations(mock_rules)
print("  需求分析:")
print(string.format("    - 需要国家信息: %s", recommendations.requirements.need_country and "是" or "否"))
print(string.format("    - 需要省份信息: %s", recommendations.requirements.need_province and "是" or "否"))
print(string.format("    - 需要城市信息: %s", recommendations.requirements.need_city and "是" or "否"))
print(string.format("    - 需要运营商信息: %s", recommendations.requirements.need_isp and "是" or "否"))
print(string.format("    - 需要ASN信息: %s", recommendations.requirements.need_asn and "是" or "否"))
print("\n  推荐总结:")
print(recommendations.summary)

-- 6. 测试IP查询 (如果数据库可用)
print("\n6. 测试IP查询:")
local test_ips = {
    "1.2.3.4",          -- 中国 电信
    "8.8.8.8",          -- 美国 Google
    "114.114.114.114",  -- 中国 南京信风
    "202.106.0.20"      -- 中国 北京联通
}

for _, ip in ipairs(test_ips) do
    print(string.format("\n  查询 IP: %s", ip))

    -- 尝试使用选中的数据库查询
    if #selected > 0 then
        local result, all_results = geoip_query.query(ip, selected)
        if result then
            print(string.format("    国家: %s (%s)", result.country or "未知", result.country_code or "-"))
            print(string.format("    省份: %s", result.province or "未知"))
            print(string.format("    城市: %s", result.city or "未知"))
            print(string.format("    运营商: %s", result.isp or "未知"))
            print(string.format("    ASN: %s", result.asn or "未知"))
            print(string.format("    数据源: %s", table.concat(result.sources, ", ")))
        else
            print("    查询失败")
        end
    else
        print("    没有可用的数据库")
    end
end

print("\n=== 测试完成 ===")
