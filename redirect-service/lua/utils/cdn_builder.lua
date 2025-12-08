-- utils/cdn_builder.lua
-- CDN URL 构建工具
-- 用于在创建短链时生成完整的 CDN URL
-- 所有 CDN 配置从 routing_rules.yaml 读取

local yaml = require "lyaml"
local logger = require "utils.logger"
local io = require "io"

local _M = {}

-- 缓存 CDN 配置
local cdn_nodes_cache = nil
local cache_time = 0
local cache_ttl = 300  -- 5分钟缓存

-- 从 routing_rules.yaml 加载 CDN 节点配置
local function load_cdn_nodes()
    local now = ngx.time()
    if cdn_nodes_cache and (now - cache_time) < cache_ttl then
        return cdn_nodes_cache
    end
    
    local config_path = "/usr/local/openresty/nginx/lua/routing_rules.yaml"
    local file = io.open(config_path, "r")
    if not file then
        logger.error("无法打开配置文件: " .. config_path)
        return {}
    end
    
    local content = file:read("*all")
    file:close()
    
    local config = yaml.load(content)
    if not config or not config.cdn_nodes then
        logger.error("无效的配置文件格式")
        return {}
    end
    
    -- 构建 CDN 节点映射表
    local nodes = {}
    for _, node in ipairs(config.cdn_nodes) do
        local domain = os.getenv(node.domain_env) or node.default_domain
        local protocol = os.getenv(node.protocol_env) or node.default_protocol
        
        -- 读取端口配置（优先环境变量，其次 default_port）
        local port = nil
        if node.port_env then
            local port_str = os.getenv(node.port_env)
            if port_str and port_str ~= "" then
                port = tonumber(port_str)
            end
        end
        if not port and node.default_port then
            port = tonumber(node.default_port)
        end
        
        nodes[node.id] = {
            name = node.name,
            domain = domain,
            protocol = protocol,
            port = port
        }
    end
    
    cdn_nodes_cache = nodes
    cache_time = now
    
    logger.info("已加载 " .. #config.cdn_nodes .. " 个 CDN 节点配置")
    return nodes
end

-- 生成单个 CDN 的完整 URL
-- @param cdn_id: CDN 标识（如 "telecom", "unicom", "overseas"）
-- @param path: 资源路径（如 "/uploads/2024/image.jpg"）
-- @return: 完整 URL
function _M.build_url(cdn_id, path)
    local nodes = load_cdn_nodes()
    local cdn = nodes[cdn_id]
    
    if not cdn then
        logger.warn("未找到 CDN 节点: " .. cdn_id .. "，使用 backup")
        cdn = nodes.backup or nodes.china
    end
    
    if not cdn then
        logger.error("无可用的 CDN 节点")
        return nil
    end
    
    -- 确保路径以 / 开头
    if not path:match("^/") then
        path = "/" .. path
    end
    
    -- 构建URL，处理端口
    logger.info("构建URL - CDN ID: " .. cdn_id .. ", domain: " .. cdn.domain .. ", port: " .. tostring(cdn.port))
    local url = cdn.protocol .. "://" .. cdn.domain
    if cdn.port and cdn.port ~= 80 and cdn.port ~= 443 then
        url = url .. ":" .. cdn.port
        logger.info("添加端口: " .. cdn.port)
    end
    url = url .. path
    logger.info("最终URL: " .. url)
    
    return url
end

-- 为所有配置的 CDN 生成 targets 数组
-- @param path: 资源路径
-- @param options: 可选配置
--   - cdns: CDN 列表，如 {"telecom", "unicom", "overseas"}
--   - attributes: 为每个 CDN 添加的额外属性（region, isp, weight 等）
-- @return: targets 数组
function _M.build_targets(path, options)
    options = options or {}
    local cdns = options.cdns or {"china"} -- 默认使用国内通用 CDN
    local targets = {}
    
    for i, cdn_id in ipairs(cdns) do
        local url = _M.build_url(cdn_id, path)
        if url then
            local target = { url = url }
            
            -- 添加额外属性
            if options.attributes and options.attributes[cdn_id] then
                for k, v in pairs(options.attributes[cdn_id]) do
                    target[k] = v
                end
            end
            
            table.insert(targets, target)
        end
    end
    
    return targets
end

-- 为图床服务生成多 CDN targets（推荐用法）
-- @param path: 图片路径
-- @param enable_geo_routing: 是否启用地理位置路由
-- @return: { targets: [...], strategy: "..." }
function _M.build_image_targets(path, enable_geo_routing)
    -- 获取客户端IP
    local client_ip = ngx.var.remote_addr or ngx.var.http_x_forwarded_for or ngx.var.http_x_real_ip
    
    -- 检查是否为私有IP（内网）
    local function is_private_ip(ip)
        if not ip then return false end
        
        -- 匹配 10.0.0.0/8
        if ip:match("^10%.") then return true end
        
        -- 匹配 172.16.0.0/12
        local second = ip:match("^172%.(%d+)%.")
        if second then
            local num = tonumber(second)
            if num >= 16 and num <= 31 then return true end
        end
        
        -- 匹配 192.168.0.0/16
        if ip:match("^192%.168%.") then return true end
        
        -- 本地回环
        if ip:match("^127%.") then return true end
        if ip == "::1" then return true end
        
        return false
    end
    
    -- 如果是内网IP，强制使用 private CDN
    if is_private_ip(client_ip) then
        local url = _M.build_url("private", path)
        if url then
            logger.info("检测到内网IP: " .. (client_ip or "unknown") .. "，使用 private CDN")
            return {
                targets = {
                    { url = url }
                },
                strategy = "weight"
            }
        end
    end
    
    if not enable_geo_routing then
        -- 简单模式：只使用国内通用 CDN
        local url = _M.build_url("china", path)
        if not url then
            logger.error("无法生成 CDN URL")
            return nil
        end
        
        return {
            targets = {
                { url = url }
            },
            strategy = "weight"
        }
    end
    
    -- 高级模式：多 CDN + 地理位置+运营商路由
    local telecom_url = _M.build_url("telecom", path)
    local unicom_url = _M.build_url("unicom", path)
    local mobile_url = _M.build_url("mobile", path)
    local overseas_url = _M.build_url("overseas", path)
    local backup_url = _M.build_url("backup", path)
    
    local targets = {}
    
    -- 电信 CDN
    if telecom_url then
        table.insert(targets, {
            url = telecom_url,
            isp = "telecom",
            weight = 100
        })
    end
    
    -- 联通 CDN
    if unicom_url then
        table.insert(targets, {
            url = unicom_url,
            isp = "unicom",
            weight = 100
        })
    end
    
    -- 移动 CDN
    if mobile_url then
        table.insert(targets, {
            url = mobile_url,
            isp = "mobile",
            weight = 100
        })
    end
    
    -- 海外 CDN
    if overseas_url then
        table.insert(targets, {
            url = overseas_url,
            region = "overseas",
            weight = 100
        })
    end
    
    -- 备用 CDN（降级）
    if backup_url then
        table.insert(targets, {
            url = backup_url,
            weight = 50
        })
    end
    
    return {
        targets = targets,
        strategy = "geo+weight",
        fallback_url = backup_url
    }
end

-- 为通用短链生成配置（单个URL）
-- @param url: 完整的目标 URL
-- @return: { targets: [...] }
function _M.build_generic_target(url)
    return {
        targets = {
            { url = url }
        },
        strategy = "weight"
    }
end

return _M
