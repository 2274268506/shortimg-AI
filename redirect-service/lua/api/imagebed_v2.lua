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
        logger.info("尝试生成代码: " .. code)
        local exists, err = mysql_client.query("SELECT id FROM short_links WHERE short_code=?", {code})
        retry_count = retry_count + 1

        if err then
            logger.error("查询数据库失败: " .. (err or "unknown"))
            return nil
        end

        logger.info("查询结果: exists=" .. (exists and #exists or "nil"))
        if not exists or #exists == 0 then
            logger.info("找到唯一代码: " .. code)
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
    ngx.log(ngx.ERR, "=== V2 API create 开始 ===")
    local data, err = read_body()
    if not data then
        ngx.log(ngx.ERR, "读取请求体失败: " .. (err or "unknown"))
        return respond_error(err)
    end

    ngx.log(ngx.ERR, "请求数据: " .. cjson.encode(data))

    -- 必需字段
    local image_path = data.image_path
    if not image_path then
        ngx.log(ngx.ERR, "缺少 image_path")
        return respond_error("缺少 image_path 字段")
    end

    -- 可选字段
    local code = data.custom_code
    local enable_geo_routing = data.enable_geo_routing or false
    local expire_time = data.expire_time

    -- 生成唯一代码
    if not code then
        ngx.log(ngx.ERR, "开始生成唯一代码...")
        code = generate_unique_code("img-", 12)
        ngx.log(ngx.ERR, "生成代码结果: " .. (code or "NIL"))
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

    -- 直接存储路径，重定向时根据分流规则动态拼接CDN域名
    -- targets 字段存储图片路径，格式: "/i/uuid"
    local targets_json = cjson.encode(image_path)
    
    -- 根据是否启用地理路由选择策略
    -- geo: 根据地理位置分流到不同CDN节点
    -- weight: 简单权重分流
    local strategy = enable_geo_routing and "geo" or "weight"

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
    -- targets 存储路径，重定向时根据分流规则拼接CDN域名
    local cache_data = {
        targets = image_path,  -- 直接存储路径
        strategy = strategy,
        service_type = "imagebed",  -- 图床类型
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
        targets_path = image_path,  -- 存储的是路径，重定向时动态拼接CDN域名
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
                -- 直接存储路径，重定向时根据分流规则动态拼接CDN域名
                local targets_json = cjson.encode(image_path)
                local strategy = enable_geo_routing and "geo" or "weight"

                -- 插入数据库
                local res, db_err = mysql_client.query(
                    "INSERT INTO short_links(short_code,targets,strategy,service_type,created_at,updated_at,visit_count,status) VALUES(?,?,?,?,NOW(),NOW(),0,'active')",
                    {code, targets_json, strategy, "imagebed"}
                )

                if res then
                    -- 写入缓存（存储路径，重定向时动态拼接CDN域名）
                    local cache_data = {
                        targets = image_path,
                        strategy = strategy,
                        service_type = "imagebed"  -- 图床类型
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
    redis_client.set("short_link:" .. code, cjson.encode({
        targets = link_config.targets, 
        strategy = strategy,
        service_type = "generic"  -- 通用短链类型
    }), 3600)

    logger.info("创建通用短链: " .. code .. " -> " .. target_url)

    return respond_success({
        code = code,
        short_url = ngx.var.scheme .. "://" .. ngx.var.host .. "/" .. code,
        target_url = target_url,
        expire_at = expire_at,
        created_at = ngx.time()
    })
end

-- 获取短链列表
function _M.list()
    local args = ngx.req.get_uri_args()
    local page = tonumber(args.page) or 1
    local limit = tonumber(args.limit) or 20
    local service_type = args.service_type

    -- 计算偏移量
    local offset = (page - 1) * limit

    -- 构建查询条件
    local where_clause = ""
    local params = {}

    if service_type and service_type ~= "" then
        where_clause = "WHERE service_type = ?"
        table.insert(params, service_type)
    end

    -- 查询总数
    local count_sql = "SELECT COUNT(*) as total FROM short_links " .. where_clause
    local count_result, err = mysql_client.query(count_sql, params)

    if err then
        logger.error("查询短链总数失败: " .. err)
        return respond_error("查询失败: " .. err, 500)
    end

    local total = (count_result and count_result[1] and count_result[1].total) or 0

    -- 查询列表
    local query_params = {}
    for _, p in ipairs(params) do
        table.insert(query_params, p)
    end
    table.insert(query_params, limit)
    table.insert(query_params, offset)

    local list_sql = [[
        SELECT short_code, strategy, status, service_type,
               created_at, updated_at, visit_count
        FROM short_links
    ]] .. where_clause .. " ORDER BY created_at DESC LIMIT ? OFFSET ?"

    local links, err = mysql_client.query(list_sql, query_params)

    if err then
        logger.error("查询短链列表失败: " .. err)
        return respond_error("查询失败: " .. err, 500)
    end

    return respond_success({
        links = links or {},
        total = total,
        page = page,
        limit = limit,
        total_pages = math.ceil(total / limit)
    })
end

-- 获取单个短链详情
function _M.get()
    local uri = ngx.var.uri
    local code = uri:match("^/api/v2/imagebed/([^/]+)$")
    
    if not code then
        return respond_error("缺少短链代码", 400)
    end

    logger.info("查询短链详情: " .. code)

    -- 先尝试从 Redis 获取
    local cache_key = "short_link:" .. code
    local cached = redis_client.get(cache_key)
    
    if cached then
        local data = cjson.decode(cached)
        if data then
            logger.info("从缓存获取短链: " .. code)
            return respond_success(data)
        end
    end

    -- 从数据库查询
    local result, err = mysql_client.query(
        "SELECT * FROM short_links WHERE short_code=?",
        {code}
    )

    if err then
        logger.error("查询短链失败: " .. err)
        return respond_error("查询失败: " .. err, 500)
    end

    if not result or #result == 0 then
        return respond_error("短链不存在", 404)
    end

    local link = result[1]
    
    -- 解析 targets JSON
    if link.targets then
        local targets_data = cjson.decode(link.targets)
        if targets_data then
            link.targets = targets_data
        end
    end

    -- 缓存到 Redis
    redis_client.setex(cache_key, 3600, cjson.encode(link))

    return respond_success(link)
end

-- 更新短链
function _M.update()
    local uri = ngx.var.uri
    local code = uri:match("^/api/v2/imagebed/([^/]+)$")
    
    if not code then
        return respond_error("缺少短链代码", 400)
    end

    local data, err = read_body()
    if not data then
        return respond_error(err, 400)
    end

    logger.info("更新短链: " .. code)

    -- 构建更新 SQL
    local updates = {}
    local params = {}

    if data.strategy then
        table.insert(updates, "strategy = ?")
        table.insert(params, data.strategy)
    end

    -- 支持两种格式：image_path（图床专用）或 targets（通用格式）
    if data.image_path then
        -- 图床专用：存储路径字符串（使用 cjson.encode 以匹配创建时的格式）
        local targets_value = cjson.encode(data.image_path)
        logger.info("Updating imagebed shortlink, targets_value type: " .. type(targets_value) .. ", value: " .. targets_value)
        
        table.insert(updates, "targets = ?")
        table.insert(params, targets_value)
        
        -- 同时更新缓存
        local cache_data = {
            targets = data.image_path,
            service_type = "imagebed"
        }
        
        -- 获取当前的 strategy
        local current = mysql_client.query("SELECT strategy FROM short_links WHERE short_code = ?", {code})
        if current and #current > 0 then
            cache_data.strategy = current[1].strategy
        end
        
        redis_client.set("short_link:" .. code, cjson.encode(cache_data), 3600)
    elseif data.targets then
        -- 通用格式
        table.insert(updates, "targets = ?")
        table.insert(params, cjson.encode(data.targets))
        
        -- 清除缓存，让下次访问时重新加载
        redis_client.del("short_link:" .. code)
    end

    if data.status then
        table.insert(updates, "status = ?")
        table.insert(params, data.status)
    end

    if #updates == 0 then
        return respond_error("没有需要更新的字段", 400)
    end

    table.insert(updates, "updated_at = NOW()")
    table.insert(params, code)

    local sql = "UPDATE short_links SET " .. table.concat(updates, ", ") .. " WHERE short_code = ?"

    local result, err = mysql_client.query(sql, params)

    if err then
        logger.error("更新短链失败: " .. err)
        return respond_error("更新失败: " .. err, 500)
    end

    -- 清除缓存
    redis_client.del("short_link:" .. code)

    logger.info("短链更新成功: " .. code)
    return respond_success({
        short_code = code,
        message = "更新成功"
    })
end

-- 删除短链
function _M.delete()
    local uri = ngx.var.uri
    local code = uri:match("^/api/v2/imagebed/([^/]+)$")
    
    if not code then
        return respond_error("缺少短链代码", 400)
    end

    -- 检查是否永久删除
    local args = ngx.req.get_uri_args()
    local permanent = args.permanent == "true"

    logger.info("删除短链请求 (永久=" .. tostring(permanent) .. "): " .. code)

    local sql
    if permanent then
        -- 永久删除:物理删除记录
        sql = "DELETE FROM short_links WHERE short_code = ?"
    else
        -- 软删除:仅更新状态
        sql = "UPDATE short_links SET status = 'deleted', updated_at = NOW() WHERE short_code = ?"
    end

    local result, err = mysql_client.query(sql, {code})

    if err then
        logger.error("删除短链失败: " .. err)
        return respond_error("删除失败: " .. err, 500)
    end

    -- 删除 Redis 缓存
    redis_client.del("short_link:" .. code)

    logger.info("短链已删除 (永久=" .. tostring(permanent) .. "): " .. code)
    return respond_success({
        code = code,
        permanent = permanent,
        message = "短链已删除"
    })
end

-- 获取统计概览
function _M.stats_overview()
    logger.info("查询统计概览")

    -- 查询总链接数
    local total_sql = "SELECT COUNT(*) as total FROM short_links WHERE status != 'deleted'"
    local total_result, err = mysql_client.query(total_sql)
    
    if err then
        logger.error("查询总链接数失败: " .. err)
        return respond_error("查询失败: " .. err, 500)
    end
    
    local total_links = (total_result and total_result[1] and total_result[1].total) or 0

    -- 查询总访问次数
    local visits_sql = "SELECT SUM(visit_count) as total_visits FROM short_links"
    local visits_result, err = mysql_client.query(visits_sql)
    
    if err then
        logger.error("查询总访问次数失败: " .. err)
        return respond_error("查询失败: " .. err, 500)
    end
    
    local total_visits = (visits_result and visits_result[1] and visits_result[1].total_visits) or 0

    -- 查询今日访问（简化版，使用 Redis 或其他方式可以更精确）
    local today_visits = 0  -- 暂时返回0，后续可以从访问日志表获取

    -- 查询独立访客数（简化版）
    local unique_visitors = math.floor(total_visits * 0.7)  -- 估算值

    return respond_success({
        total_links = tonumber(total_links),
        total_visits = tonumber(total_visits),
        today_visits = tonumber(today_visits),
        unique_visitors = tonumber(unique_visitors)
    })
end

-- 路由处理函数（入口）
function _M.handle()
    local method = ngx.var.request_method
    local uri = ngx.var.uri

    -- GET 请求
    if method == "GET" then
        -- GET /api/v2/imagebed/stats/overview - 统计概览
        if uri == "/api/v2/imagebed/stats/overview" then
            return _M.stats_overview()
        -- GET /api/v2/imagebed - 获取列表
        elseif uri == "/api/v2/imagebed" then
            return _M.list()
        -- GET /api/v2/imagebed/:code - 获取单个详情
        elseif uri:match("^/api/v2/imagebed/[^/]+$") then
            return _M.get()
        else
            return respond_error("未知的 API 端点", 404)
        end
    
    -- PUT 请求 - 更新
    elseif method == "PUT" then
        if uri:match("^/api/v2/imagebed/[^/]+$") then
            return _M.update()
        else
            return respond_error("未知的 API 端点", 404)
        end
    
    -- DELETE 请求 - 删除
    elseif method == "DELETE" then
        if uri:match("^/api/v2/imagebed/[^/]+$") then
            return _M.delete()
        else
            return respond_error("未知的 API 端点", 404)
        end
    
    -- POST 请求 - 创建
    elseif method == "POST" then
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
    else
        return respond_error("不支持的请求方法", 405)
    end
end

return _M
