-- api/imagebed.lua
-- 图床短链集成 API（简化版）

local cjson = require "cjson.safe"
local logger = require "utils.logger"
local code_generator = require "utils.code_generator"
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

-- 创建图床短链
function _M.create()
    local data, err = read_body()
    if not data then return respond_error(err) end

    -- 兼容两种格式：image_url（完整URL）和 image_path（CDN路径）
    local image_url = data.image_url
    local image_path = data.image_path

    if not image_url and not image_path then
        return respond_error("缺少image_url或image_path字段")
    end

    local code = data.custom_code

    -- 如果是自定义代码，检查唯一性
    if code then
        local exists = mysql_client.query("SELECT id FROM short_links WHERE short_code=?", {code})
        if exists and #exists > 0 then return respond_error("代码已存在") end
    else
        -- 自动生成代码，带重试机制确保唯一性
        local max_retries = 10
        local retry_count = 0

        repeat
            -- 图床短链使用 'img-' 前缀
            code = "img-" .. code_generator.generate(12)
            local exists = mysql_client.query("SELECT id FROM short_links WHERE short_code=?", {code})
            retry_count = retry_count + 1

            if not exists or #exists == 0 then
                break
            end

            if retry_count >= max_retries then
                logger.error("生成唯一代码失败，已重试" .. max_retries .. "次")
                return respond_error("生成唯一代码失败，请稍后重试", 500)
            end
        until false
    end

    local expire_at = (data.expire_time and data.expire_time > 0) and (ngx.time() + data.expire_time) or nil

    -- 根据输入类型构建targets
    local targets
    if image_path then
        -- 使用路径模式，触发GeoIP分流
        targets = cjson.encode({{path = image_path, weight = 100}})
        logger.info("创建图床短链(路径模式，GeoIP分流): " .. code .. " -> " .. image_path)
    else
        -- 使用完整URL模式
        targets = cjson.encode({{url = image_url, weight = 100}})
        logger.info("创建图床短链(URL模式): " .. code .. " -> " .. image_url)
    end

    local res, err
    if expire_at then
        res, err = mysql_client.query(
            "INSERT INTO short_links(short_code,targets,strategy,service_type,expires_at,created_at,updated_at,visit_count,status) VALUES(?,?,?,?,?,NOW(),NOW(),0,'active')",
            {code, targets, "weight", "imagebed", ngx.localtime(expire_at)}
        )
    else
        res, err = mysql_client.query(
            "INSERT INTO short_links(short_code,targets,strategy,service_type,created_at,updated_at,visit_count,status) VALUES(?,?,?,?,NOW(),NOW(),0,'active')",
            {code, targets, "weight", "imagebed"}
        )
    end

    if not res then
        logger.error("创建失败:" .. (err or "unknown"))
        return respond_error("创建失败", 500)
    end

    redis_client.set("link:" .. code, cjson.encode({targets=targets}), 3600)

    return respond_success({
        code = code,
        short_url = ngx.var.scheme .. "://" .. ngx.var.host .. "/" .. code,
        long_url = image_url or image_path,  -- 返回原始URL或路径
        expire_at = expire_at,
        created_at = ngx.time()
    })
end

-- 批量创建
function _M.batch_create()
    local data, err = read_body()
    if not data then return respond_error(err) end
    if not data.images or #data.images == 0 then return respond_error("缺少images数组") end
    if #data.images > 100 then return respond_error("最多100个") end

    local results = {total = #data.images, success = 0, failed = 0, results = {}}
    local used_codes = {}  -- 跟踪本批次已使用的代码

    for i, img in ipairs(data.images) do
        -- 兼容两种格式：image_url 和 image_path
        local image_url = img.image_url
        local image_path = img.image_path

        if (image_url and image_url:match("^https?://")) or image_path then
            local code = img.custom_code

            -- 如果没有自定义代码，生成唯一代码
            if not code then
                local max_retries = 10
                local retry_count = 0

                repeat
                    code = "img-" .. code_generator.generate(12)

                    -- 检查数据库和本批次中的唯一性
                    local exists = mysql_client.query("SELECT id FROM short_links WHERE short_code=?", {code})
                    retry_count = retry_count + 1

                    if (not exists or #exists == 0) and not used_codes[code] then
                        used_codes[code] = true
                        break
                    end

                    if retry_count >= max_retries then
                        code = nil
                        break
                    end
                until false

                if not code then
                    results.failed = results.failed + 1
                    table.insert(results.results, {success=false, error="生成唯一代码失败"})
                    goto continue
                end
            else
                -- 自定义代码检查唯一性
                local exists = mysql_client.query("SELECT id FROM short_links WHERE short_code=?", {code})
                if exists and #exists > 0 then
                    results.failed = results.failed + 1
                    table.insert(results.results, {success=false, error="代码已存在"})
                    goto continue
                end
                used_codes[code] = true
            end

            local expire_at = (data.expire_time and data.expire_time > 0) and (ngx.time() + data.expire_time) or nil

            -- 根据输入类型构建targets
            local targets
            if image_path then
                -- 使用路径模式，触发GeoIP分流
                targets = cjson.encode({{path = image_path, weight = 100}})
            else
                -- 使用URL模式
                targets = cjson.encode({{url = image_url, weight = 100}})
            end

            local res, err
            if expire_at then
                res, err = mysql_client.query(
                    "INSERT INTO short_links(short_code,targets,strategy,service_type,expires_at,created_at,updated_at,visit_count,status) VALUES(?,?,?,?,?,NOW(),NOW(),0,'active')",
                    {code, targets, "weight", "imagebed", ngx.localtime(expire_at)}
                )
            else
                res, err = mysql_client.query(
                    "INSERT INTO short_links(short_code,targets,strategy,service_type,created_at,updated_at,visit_count,status) VALUES(?,?,?,?,NOW(),NOW(),0,'active')",
                    {code, targets, "weight", "imagebed"}
                )
            end

            if res then
                results.success = results.success + 1
                table.insert(results.results, {success=true, code=code, short_url=ngx.var.scheme.."://"..ngx.var.host.."/"..code, long_url=image_url or image_path})
            else
                results.failed = results.failed + 1
                table.insert(results.results, {success=false, error=err or "unknown"})
            end
        else
            results.failed = results.failed + 1
            table.insert(results.results, {success=false, error="无效URL"})
        end

        ::continue::
    end

    return respond_success(results)
end

-- 获取信息
function _M.get_info()
    local code = ngx.var.uri:match("^/api/imagebed/info/(.+)$")
    if not code then return respond_error("缺少代码") end

    local cache = redis_client.get("link:" .. code)
    if cache then
        local link = cjson.decode(cache)
        local targets_arr = cjson.decode(link.targets)
        local first_url = targets_arr and targets_arr[1] and targets_arr[1].url or ""
        return respond_success({code=code, long_url=first_url, from_cache=true})
    end

    local res = mysql_client.query("SELECT short_code,targets,expires_at,visit_count,created_at,updated_at FROM short_links WHERE short_code=? AND status='active'", {code})

    if not res or #res == 0 then return respond_error("不存在", 404) end

    local link = res[1]

    -- 从targets数组中提取第一个URL
    local targets_arr = cjson.decode(link.targets)
    local long_url = targets_arr and targets_arr[1] and targets_arr[1].url or ""

    return respond_success({
        code = link.short_code,
        long_url = long_url,
        visit_count = link.visit_count,
        expires_at = link.expires_at,
        created_at = link.created_at,
        updated_at = link.updated_at,
        from_cache = false
    })
end

-- 更新元数据（当前表结构不支持metadata字段）
function _M.update_metadata()
    return respond_error("当前版本不支持元数据更新", 501)
end

-- 统计
function _M.get_stats()
    local total = mysql_client.query("SELECT COUNT(*)as c FROM short_links WHERE status='active'")
    local today = mysql_client.query("SELECT COUNT(*)as c FROM short_links WHERE DATE(created_at)=CURDATE() AND status='active'")
    local clicks = mysql_client.query("SELECT SUM(visit_count)as c FROM short_links WHERE status='active'")
    local top = mysql_client.query("SELECT short_code,targets,visit_count,created_at FROM short_links WHERE status='active' ORDER BY visit_count DESC LIMIT 10")

    local top_images = {}
    if top then
        for _, row in ipairs(top) do
            local targets_arr = cjson.decode(row.targets)
            local url = targets_arr and targets_arr[1] and targets_arr[1].url or ""
            table.insert(top_images, {code=row.short_code, long_url=url, visit_count=row.visit_count, created_at=row.created_at})
        end
    end

    return respond_success({
        total_links = (total and #total>0) and total[1].c or 0,
        today_created = (today and #today>0) and today[1].c or 0,
        total_clicks = (clicks and #clicks>0 and clicks[1].c) or 0,
        top_images = top_images
    })
end

return _M
