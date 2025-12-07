-- routing_engine.lua
-- 动态路由引擎 - 支持灵活的分流规则配置

local yaml = require "lyaml"
local _M = {}

-- 全局缓存
local routing_config = nil
local cdn_nodes_map = {}
local last_load_time = 0
local config_file_path = "/usr/local/openresty/nginx/conf/routing_rules.yaml"

-- 日志函数
local function log(level, msg)
    ngx.log(level, "[RoutingEngine] ", msg)
end

-- 加载配置文件
local function load_config()
    local file = io.open(config_file_path, "r")
    if not file then
        log(ngx.ERR, "无法打开配置文件: " .. config_file_path)
        return nil
    end

    local content = file:read("*all")
    file:close()

    local config = yaml.load(content)
    if not config then
        log(ngx.ERR, "配置文件解析失败")
        return nil
    end

    return config
end

-- 初始化CDN节点映射
local function init_cdn_nodes(nodes)
    cdn_nodes_map = {}

    for _, node in ipairs(nodes or {}) do
        local domain = os.getenv(node.domain_env) or node.default_domain
        local protocol = os.getenv(node.protocol_env) or node.default_protocol
        local port = os.getenv(node.port_env) or node.default_port or ""

        cdn_nodes_map[node.id] = {
            id = node.id,
            name = node.name,
            domain = domain,
            protocol = protocol,
            port = port
        }
    end

    log(ngx.INFO, "已加载 " .. #nodes .. " 个CDN节点")
end

-- 获取配置（带缓存）
function _M.get_config(force_reload)
    local now = ngx.time()

    -- 如果需要强制重载或超过缓存时间
    if force_reload or not routing_config or (now - last_load_time) > 300 then
        routing_config = load_config()
        if routing_config then
            init_cdn_nodes(routing_config.cdn_nodes)
            last_load_time = now
            log(ngx.INFO, "配置已重载")
        end
    end

    return routing_config
end

-- 检查IP是否在范围内
local function ip_in_range(ip, range)
    -- 简化实现，实际应使用更完善的IP段匹配
    local function ip_to_number(ip_str)
        local parts = {}
        for part in string.gmatch(ip_str, "%d+") do
            table.insert(parts, tonumber(part))
        end
        if #parts ~= 4 then return nil end
        return parts[1] * 256^3 + parts[2] * 256^2 + parts[3] * 256 + parts[4]
    end

    local ip_num = ip_to_number(ip)
    if not ip_num then return false end

    -- 解析CIDR
    local network, bits = range:match("([^/]+)/(%d+)")
    if not network or not bits then return false end

    local network_num = ip_to_number(network)
    if not network_num then return false end

    bits = tonumber(bits)
    local mask = bit.lshift(0xFFFFFFFF, 32 - bits)

    return bit.band(ip_num, mask) == bit.band(network_num, mask)
end

-- 检查值是否在列表中
local function value_in_list(value, list)
    if not value or not list then return false end

    for _, item in ipairs(list) do
        if value == item or (type(value) == "string" and value:find(item)) then
            return true
        end
    end

    return false
end

-- 检查条件是否匹配
local function check_condition(condition, client_info, request_info)
    local ctype = condition.type

    -- IP范围匹配
    if ctype == "ip_range" then
        local client_ip = client_info.ip
        for _, range in ipairs(condition.ranges or {}) do
            if ip_in_range(client_ip, range) then
                return true
            end
        end
        return false

    -- 省份匹配
    elseif ctype == "province" then
        return value_in_list(client_info.province, condition.values)

    -- 运营商匹配
    elseif ctype == "isp" then
        return value_in_list(client_info.isp, condition.values)

    -- 国家匹配
    elseif ctype == "country" then
        if condition.operator == "not_equals" then
            return client_info.country ~= condition.value
        else
            return client_info.country == condition.value
        end

    -- ASN匹配
    elseif ctype == "asn" then
        return value_in_list(tostring(client_info.asn), condition.values)

    -- 路径前缀匹配
    elseif ctype == "path_prefix" then
        local path = request_info.path
        for _, prefix in ipairs(condition.values or {}) do
            if path:sub(1, #prefix) == prefix then
                return true
            end
        end
        return false

    -- 时间段匹配
    elseif ctype == "time_range" then
        local hour = tonumber(os.date("%H"))
        local start_hour = condition.start_hour or 0
        local end_hour = condition.end_hour or 24

        if start_hour <= end_hour then
            return hour >= start_hour and hour < end_hour
        else
            -- 跨天的情况
            return hour >= start_hour or hour < end_hour
        end

    -- 百分比匹配（用于A/B测试）
    elseif ctype == "percentage" then
        local percentage = condition.value or 0
        -- 使用IP最后一个字节作为随机源
        local ip_parts = {}
        for part in client_info.ip:gmatch("%d+") do
            table.insert(ip_parts, tonumber(part))
        end
        local random_value = (ip_parts[4] or 0) % 100
        return random_value < percentage

    -- HTTP Header匹配
    elseif ctype == "header" then
        local header_value = ngx.var["http_" .. condition.name:lower():gsub("-", "_")]
        return header_value == condition.value

    -- URL参数匹配
    elseif ctype == "query_param" then
        local args = ngx.req.get_uri_args()
        return args[condition.name] == condition.value

    end

    return false
end

-- 检查规则是否匹配
local function check_rule(rule, client_info, request_info)
    if not rule.enabled then
        return false
    end

    -- 所有条件必须都满足（AND逻辑）
    for _, condition in ipairs(rule.conditions or {}) do
        if not check_condition(condition, client_info, request_info) then
            return false
        end
    end

    return true
end

-- 选择目标CDN
function _M.select_cdn(client_info, request_info)
    local config = _M.get_config()
    if not config then
        log(ngx.WARN, "配置未加载，使用默认CDN")
        return "public"
    end

    -- 按优先级排序规则
    local sorted_rules = {}
    for _, rule in ipairs(config.routing_rules or {}) do
        table.insert(sorted_rules, rule)
    end
    table.sort(sorted_rules, function(a, b)
        return (a.priority or 999) < (b.priority or 999)
    end)

    -- 匹配规则
    for _, rule in ipairs(sorted_rules) do
        if check_rule(rule, client_info, request_info) then
            log(ngx.INFO, "匹配规则: " .. rule.name .. " -> " .. rule.target)
            return rule.target
        end
    end

    -- 使用默认路由
    local default_target = (config.default_routing and config.default_routing.target) or "public"
    log(ngx.INFO, "使用默认路由: " .. default_target)
    return default_target
end

-- 获取CDN节点信息
function _M.get_cdn_node(cdn_id)
    return cdn_nodes_map[cdn_id]
end

-- 构建完整URL
function _M.build_url(cdn_id, path)
    local node = _M.get_cdn_node(cdn_id)
    if not node then
        log(ngx.ERR, "CDN节点不存在: " .. tostring(cdn_id))
        node = _M.get_cdn_node("public")
    end

    if not node then
        return nil
    end

    -- 确保路径以 / 开头
    if not path:match("^/") then
        path = "/" .. path
    end

    -- 构建URL
    local url = node.protocol .. "://" .. node.domain
    if node.port and node.port ~= "" and node.port ~= "80" and node.port ~= "443" then
        url = url .. ":" .. node.port
    end
    url = url .. path

    return url
end

-- 获取降级链
function _M.get_fallback_chain()
    local config = _M.get_config()
    if config and config.default_routing and config.default_routing.fallback_chain then
        return config.default_routing.fallback_chain
    end
    return {"public", "private", "fallback"}
end

-- 重载配置（用于热更新）
function _M.reload()
    log(ngx.INFO, "手动重载配置")
    return _M.get_config(true)
end

return _M
