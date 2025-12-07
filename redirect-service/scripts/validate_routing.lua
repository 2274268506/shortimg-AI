#!/usr/bin/env lua

-- validate_routing.lua
-- 验证路由配置文件的语法和逻辑

local yaml = require "lyaml"

-- 颜色定义
local colors = {
    reset = "\27[0m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    cyan = "\27[36m"
}

local function log(level, msg)
    local prefix = {
        ERROR = colors.red .. "✗ 错误" .. colors.reset,
        WARN = colors.yellow .. "⚠ 警告" .. colors.reset,
        INFO = colors.blue .. "ℹ 信息" .. colors.reset,
        SUCCESS = colors.green .. "✓ 成功" .. colors.reset
    }
    print(string.format("[%s] %s", prefix[level] or "INFO", msg))
end

-- 加载配置文件
local function load_config(file_path)
    local file = io.open(file_path, "r")
    if not file then
        log("ERROR", "无法打开配置文件: " .. file_path)
        return nil
    end

    local content = file:read("*all")
    file:close()

    local success, config = pcall(yaml.load, content)
    if not success then
        log("ERROR", "YAML解析失败: " .. tostring(config))
        return nil
    end

    return config
end

-- 验证CDN节点
local function validate_cdn_nodes(nodes)
    if not nodes or type(nodes) ~= "table" or #nodes == 0 then
        log("ERROR", "cdn_nodes 配置缺失或为空")
        return false
    end

    local errors = 0
    local warnings = 0
    local node_ids = {}

    for i, node in ipairs(nodes) do
        -- 检查必需字段
        if not node.id then
            log("ERROR", string.format("节点 #%d 缺少 id 字段", i))
            errors = errors + 1
        else
            -- 检查ID重复
            if node_ids[node.id] then
                log("ERROR", string.format("节点ID重复: %s", node.id))
                errors = errors + 1
            end
            node_ids[node.id] = true
        end

        if not node.name then
            log("WARN", string.format("节点 %s 缺少 name 字段", node.id or "#" .. i))
            warnings = warnings + 1
        end

        if not node.domain_env then
            log("ERROR", string.format("节点 %s 缺少 domain_env 字段", node.id or "#" .. i))
            errors = errors + 1
        end

        if not node.default_domain then
            log("WARN", string.format("节点 %s 缺少 default_domain 字段", node.id or "#" .. i))
            warnings = warnings + 1
        end

        if not node.default_protocol then
            log("WARN", string.format("节点 %s 缺少 default_protocol 字段", node.id or "#" .. i))
            warnings = warnings + 1
        elseif node.default_protocol ~= "http" and node.default_protocol ~= "https" then
            log("ERROR", string.format("节点 %s 的 default_protocol 必须是 http 或 https", node.id or "#" .. i))
            errors = errors + 1
        end
    end

    log("INFO", string.format("CDN节点检查完成: %d个节点, %d个错误, %d个警告", #nodes, errors, warnings))
    return errors == 0
end

-- 验证路由规则
local function validate_routing_rules(rules, node_ids)
    if not rules or type(rules) ~= "table" then
        log("WARN", "routing_rules 配置缺失或为空")
        return true
    end

    local errors = 0
    local warnings = 0

    -- 支持的条件类型
    local valid_condition_types = {
        ip_range = true,
        province = true,
        isp = true,
        country = true,
        asn = true,
        path_prefix = true,
        time_range = true,
        percentage = true,
        header = true,
        query_param = true
    }

    for i, rule in ipairs(rules) do
        local rule_name = rule.name or ("#" .. i)

        -- 检查必需字段
        if not rule.name then
            log("WARN", string.format("规则 #%d 缺少 name 字段", i))
            warnings = warnings + 1
        end

        if not rule.priority then
            log("ERROR", string.format("规则 %s 缺少 priority 字段", rule_name))
            errors = errors + 1
        elseif type(rule.priority) ~= "number" then
            log("ERROR", string.format("规则 %s 的 priority 必须是数字", rule_name))
            errors = errors + 1
        end

        if rule.enabled == nil then
            log("WARN", string.format("规则 %s 缺少 enabled 字段", rule_name))
            warnings = warnings + 1
        end

        if not rule.target then
            log("ERROR", string.format("规则 %s 缺少 target 字段", rule_name))
            errors = errors + 1
        elseif not node_ids[rule.target] then
            log("ERROR", string.format("规则 %s 的 target '%s' 不存在于 cdn_nodes 中", rule_name, rule.target))
            errors = errors + 1
        end

        -- 检查条件
        if not rule.conditions or type(rule.conditions) ~= "table" then
            log("WARN", string.format("规则 %s 没有配置 conditions", rule_name))
            warnings = warnings + 1
        else
            for j, condition in ipairs(rule.conditions) do
                if not condition.type then
                    log("ERROR", string.format("规则 %s 的条件 #%d 缺少 type 字段", rule_name, j))
                    errors = errors + 1
                elseif not valid_condition_types[condition.type] then
                    log("ERROR", string.format("规则 %s 的条件类型 '%s' 不支持", rule_name, condition.type))
                    errors = errors + 1
                end

                -- 条件类型特定验证
                if condition.type == "ip_range" then
                    if not condition.ranges or #condition.ranges == 0 then
                        log("ERROR", string.format("规则 %s 的 ip_range 条件缺少 ranges", rule_name))
                        errors = errors + 1
                    end
                elseif condition.type == "province" or condition.type == "isp" or condition.type == "asn" then
                    if not condition.values or #condition.values == 0 then
                        log("ERROR", string.format("规则 %s 的 %s 条件缺少 values", rule_name, condition.type))
                        errors = errors + 1
                    end
                elseif condition.type == "country" then
                    if not condition.value then
                        log("ERROR", string.format("规则 %s 的 country 条件缺少 value", rule_name))
                        errors = errors + 1
                    end
                elseif condition.type == "time_range" then
                    if not condition.start_hour or not condition.end_hour then
                        log("ERROR", string.format("规则 %s 的 time_range 条件缺少 start_hour 或 end_hour", rule_name))
                        errors = errors + 1
                    end
                elseif condition.type == "percentage" then
                    if not condition.value then
                        log("ERROR", string.format("规则 %s 的 percentage 条件缺少 value", rule_name))
                        errors = errors + 1
                    elseif condition.value < 0 or condition.value > 100 then
                        log("ERROR", string.format("规则 %s 的 percentage 值必须在 0-100 之间", rule_name))
                        errors = errors + 1
                    end
                elseif condition.type == "header" or condition.type == "query_param" then
                    if not condition.name or not condition.value then
                        log("ERROR", string.format("规则 %s 的 %s 条件缺少 name 或 value", rule_name, condition.type))
                        errors = errors + 1
                    end
                end
            end
        end
    end

    log("INFO", string.format("路由规则检查完成: %d条规则, %d个错误, %d个警告", #rules, errors, warnings))
    return errors == 0
end

-- 验证默认路由
local function validate_default_routing(default_routing, node_ids)
    if not default_routing then
        log("WARN", "default_routing 配置缺失")
        return true
    end

    local errors = 0

    if default_routing.target and not node_ids[default_routing.target] then
        log("ERROR", string.format("default_routing 的 target '%s' 不存在于 cdn_nodes 中", default_routing.target))
        errors = errors + 1
    end

    if default_routing.fallback_chain then
        for i, node_id in ipairs(default_routing.fallback_chain) do
            if not node_ids[node_id] then
                log("ERROR", string.format("fallback_chain[%d] '%s' 不存在于 cdn_nodes 中", i, node_id))
                errors = errors + 1
            end
        end
    end

    log("INFO", string.format("默认路由检查完成: %d个错误", errors))
    return errors == 0
end

-- 主函数
local function main()
    local config_file = arg[1] or "/usr/local/openresty/nginx/conf/routing_rules.yaml"

    print(colors.cyan .. "========================================" .. colors.reset)
    print(colors.cyan .. "🔍 路由配置验证工具" .. colors.reset)
    print(colors.cyan .. "========================================" .. colors.reset)
    print("")

    log("INFO", "正在加载配置文件: " .. config_file)
    local config = load_config(config_file)

    if not config then
        log("ERROR", "配置加载失败")
        os.exit(1)
    end

    log("SUCCESS", "配置文件解析成功")
    print("")

    -- 提取节点ID
    local node_ids = {}
    if config.cdn_nodes then
        for _, node in ipairs(config.cdn_nodes) do
            if node.id then
                node_ids[node.id] = true
            end
        end
    end

    -- 验证各部分
    local all_valid = true

    print(colors.blue .. "📡 验证CDN节点配置..." .. colors.reset)
    all_valid = validate_cdn_nodes(config.cdn_nodes) and all_valid
    print("")

    print(colors.blue .. "🎯 验证路由规则..." .. colors.reset)
    all_valid = validate_routing_rules(config.routing_rules, node_ids) and all_valid
    print("")

    print(colors.blue .. "🔄 验证默认路由..." .. colors.reset)
    all_valid = validate_default_routing(config.default_routing, node_ids) and all_valid
    print("")

    -- 总结
    print(colors.cyan .. "========================================" .. colors.reset)
    if all_valid then
        log("SUCCESS", "配置验证通过！")
        print(colors.cyan .. "========================================" .. colors.reset)
        os.exit(0)
    else
        log("ERROR", "配置验证失败，请修复上述错误")
        print(colors.cyan .. "========================================" .. colors.reset)
        os.exit(1)
    end
end

-- 运行
main()
