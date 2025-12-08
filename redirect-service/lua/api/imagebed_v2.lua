-- api/imagebed_v2.lua
-- 图床短链集成 API（使用高级路由引擎）

local cjson = require "cjson.safe"
local logger = require "utils.logger"
local code_generator = require "utils.code_generator"
local cdn_builder = require "utils.cdn_builder"
local mysql_client = require "storage.mysql_client"
local redis_client = require "storage.redis_client"

local _M = {}

local function respond_json(data, status)
    ngx.status = status or 200
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.say(cjson.encode(data))
    return ngx.exit(ngx.status)
end

local function respond_error(message, status)
    return respond_json({success = false, error = message}, status or 400)
end

local function respond_success(data)
    return respond_json({success = true, data = data}, 200)
end

local function read_body()
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    if not body then return nil, "请求体为空" end

    local data, err = cjson.decode(body)
    if not data then return nil, "JSON解析失败" end

    return data
end

-- 生成唯一短链代码
local function generate_unique_code(prefix, length)
    local max_retries = 10
    local retry_count = 0

    repeat
        local code = (prefix or "") .. code_generator.generate(length or 12)
        local exists, err = mysql_client.query("SELECT id FROM short_links WHERE short_code=?", {code})
        retry_count = retry_count + 1

        if err then
            logger.error("查询数据库失败: " .. (err or "unknown"))
            return nil
        end

        if not exists or #exists == 0 then
            return code
        end

        if retry_count >= max_retries then
            logger.error("生成唯一代码失败，已重试" .. max_retries .. "次")
            return nil
        end
    until false
end

-- 创建图床短链（V2 - 使用高级路由）
function _M.create()
    local data, err = read_body()
    if not data then return respond_error(err) end

    -- 必需字段
    local image_path = data.image_path
    if not image_path then
        return respond_error("缺少 image_path 字段")
    end

    -- 可选字段
    local code = data.custom_code
    local enable_geo_routing = data.enable_geo_routing or false
    local expire_time = data.expire_time

    -- 生成唯一代码
    if not code then
        code = generate_unique_code("img-", 12)
        if not code then
            return respond_error("生成唯一代码失败，请稍后重试", 500)
        end
    else
        -- 检查自定义代码唯一性
        local exists = mysql_client.query("SELECT id FROM short_links WHERE short_code=?", {code})
        if exists and #exists > 0 then
            return respond_error("代码已存在")
        end
    end

    -- 使用 CDN 构建器生成 targets 配置
    local link_config = cdn_builder.build_image_targets(image_path, enable_geo_routing)
    
    local targets_json = cjson.encode(link_config.targets)
    local strategy = link_config.strategy

    -- 计算过期时间
    local expire_at = (expire_time and expire_time > 0) and (ngx.time() + expire_time) or nil

    -- 插入数据库
    local res, err
    if expire_at then
        res, err = mysql_client.query(
            "INSERT INTO short_links(short_code,targets,strategy,service_type,expires_at,created_at,updated_at,visit_count,status) VALUES(?,?,?,?,?,NOW(),NOW(),0,'active')",
            {code, targets_json, strategy, "imagebed", ngx.localtime(expire_at)}
        )
    else
        res, err = mysql_client.query(
            "INSERT INTO short_links(short_code,targets,strategy,service_type,created_at,updated_at,visit_count,status) VALUES(?,?,?,?,NOW(),NOW(),0,'active')",
            {code, targets_json, strategy, "imagebed"}
        )
    end

    if not res then
        logger.error("创建失败:" .. (err or "unknown"))
        return respond_error("创建失败", 500)
    end

    -- 写入 Redis 缓存
    local cache_data = {
        targets = link_config.targets,
        strategy = strategy,
        fallback_url = fallback_url
    }
    redis_client.set("short_link:" .. code, cjson.encode(cache_data), 3600)

    logger.info(string.format("创建图床短链: %s -> %s (策略: %s, GeoIP: %s)", 
        code, image_path, strategy, enable_geo_routing and "启用" or "禁用"))

    return respond_success({
        code = code,
        short_url = ngx.var.scheme .. "://" .. ngx.var.host .. "/" .. code,
        image_path = image_path,
        strategy = strategy,
        geo_routing_enabled = enable_geo_routing,
        targets_count = #link_config.targets,
        expire_at = expire_at,
        created_at = ngx.time()
    })
end

-- 批量创建图床短链
function _M.batch_create()
    local data, err = read_body()
    if not data then return respond_error(err) end
    
    if not data.images or #data.images == 0 then
        return respond_error("缺少 images 数组")
    end
    
    if #data.images > 100 then
        return respond_error("单次最多创建 100 个短链")
    end

    local enable_geo_routing = data.enable_geo_routing or false
    local results = {
        total = #data.images,
        success = 0,
        failed = 0,
        results = {}
    }

    for i, img in ipairs(data.images) do
        local image_path = img.image_path or img.path
        
        if not image_path then
            table.insert(results.results, {
                index = i,
                success = false,
                error = "缺少 image_path"
            })
            results.failed = results.failed + 1
        else
            -- 生成代码
            local code = img.custom_code or generate_unique_code("img-", 12)
            
            if not code then
                table.insert(results.results, {
                    index = i,
                    image_path = image_path,
                    success = false,
                    error = "生成唯一代码失败"
                })
                results.failed = results.failed + 1
            else
                -- 使用 CDN 构建器生成配置
                local link_config = cdn_builder.build_image_targets(image_path, enable_geo_routing)
                
                local targets_json = cjson.encode(link_config.targets)
                local strategy = link_config.strategy

                -- 插入数据库
                local res, db_err = mysql_client.query(
                    "INSERT INTO short_links(short_code,targets,strategy,service_type,created_at,updated_at,visit_count,status) VALUES(?,?,?,?,NOW(),NOW(),0,'active')",
                    {code, targets_json, strategy, "imagebed"}
                )

                if res then
                    -- 写入缓存
                    local cache_data = {
                        targets = link_config.targets,
                        strategy = strategy
                    }
                    redis_client.set("short_link:" .. code, cjson.encode(cache_data), 3600)

                    table.insert(results.results, {
                        index = i,
                        success = true,
                        code = code,
                        short_url = ngx.var.scheme .. "://" .. ngx.var.host .. "/" .. code,
                        image_path = image_path,
                        strategy = strategy
                    })
                    results.success = results.success + 1
                else
                    table.insert(results.results, {
                        index = i,
                        image_path = image_path,
                        success = false,
                        error = "数据库插入失败: " .. (db_err or "unknown")
                    })
                    results.failed = results.failed + 1
                end
            end
        end
    end

    return respond_success(results)
end

-- 创建通用短链（完整URL）
function _M.create_generic()
    local data, err = read_body()
    if not data then return respond_error(err) end

    local target_url = data.url
    if not target_url or not target_url:match("^https?://") then
        return respond_error("缺少有效的 url 字段")
    end

    local code = data.custom_code or generate_unique_code("", 8)
    if not code then
        return respond_error("生成唯一代码失败", 500)
    end

    -- 通用短链：单个完整URL
    local link_config = cdn_builder.build_generic_target(target_url)
    
    local targets_json = cjson.encode(link_config.targets)
    local strategy = link_config.strategy

    local expire_at = (data.expire_time and data.expire_time > 0) and (ngx.time() + data.expire_time) or nil

    local res, db_err
    if expire_at then
        res, db_err = mysql_client.query(
            "INSERT INTO short_links(short_code,targets,strategy,service_type,expires_at,created_at,updated_at,visit_count,status) VALUES(?,?,?,?,?,NOW(),NOW(),0,'active')",
            {code, targets_json, strategy, "generic", ngx.localtime(expire_at)}
        )
    else
        res, db_err = mysql_client.query(
            "INSERT INTO short_links(short_code,targets,strategy,service_type,created_at,updated_at,visit_count,status) VALUES(?,?,?,NOW(),NOW(),0,'active')",
            {code, targets_json, strategy, "generic"}
        )
    end

    if not res then
        logger.error("创建失败:" .. (db_err or "unknown"))
        return respond_error("创建失败", 500)
    end

    -- 写入缓存
    redis_client.set("short_link:" .. code, cjson.encode({targets = link_config.targets, strategy = strategy}), 3600)

    logger.info("创建通用短链: " .. code .. " -> " .. target_url)

    return respond_success({
        code = code,
        short_url = ngx.var.scheme .. "://" .. ngx.var.host .. "/" .. code,
        target_url = target_url,
        expire_at = expire_at,
        created_at = ngx.time()
    })
end

-- 路由处理函数（入口）
function _M.handle()
    local method = ngx.var.request_method
    local uri = ngx.var.uri

    if method ~= "POST" then
        return respond_error("仅支持 POST 请求", 405)
    end

    -- V2 图床 API 路由
    if uri:match("^/api/v2/imagebed/create$") then
        return _M.create()
    elseif uri:match("^/api/v2/imagebed/batch$") then
        return _M.batch_create()
    
    -- V2 通用短链 API 路由
    elseif uri:match("^/api/v2/generic/create$") then
        return _M.create_generic()
    else
        return respond_error("未知的 API 端点", 404)
    end
end

return _M
