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

    if not data.image_url then return respond_error("缺少image_url字段") end
    if not data.image_url:match("^https?://") then return respond_error("无效的图片URL格式") end

    local code = data.custom_code or code_generator.generate(8)

    if data.custom_code then
        local exists = mysql_client.query("SELECT id FROM short_links WHERE code=?", {code})
        if exists and #exists > 0 then return respond_error("代码已存在") end
    end

    local metadata = data.metadata or {}
    metadata.type = "imagebed"
    metadata.created_by = "imagebed_service"

    local expire_at = (data.expire_time and data.expire_time > 0) and (ngx.time() + data.expire_time) or nil

    local res, err = mysql_client.query(
        "INSERT INTO short_links(code,long_url,metadata,expire_at,created_at,updated_at,click_count,status) VALUES(?,?,?,?,NOW(),NOW(),0,'active')",
        {code, data.image_url, cjson.encode(metadata), expire_at}
    )

    if not res then
        logger.error("创建失败:" .. (err or "unknown"))
        return respond_error("创建失败", 500)
    end

    redis_client.set("link:" .. code, cjson.encode({long_url=data.image_url, metadata=metadata}), 3600)

    logger.info("创建图床短链:" .. code)

    return respond_success({
        code = code,
        short_url = ngx.var.scheme .. "://" .. ngx.var.host .. "/" .. code,
        long_url = data.image_url,
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

    for i, img in ipairs(data.images) do
        if img.image_url and img.image_url:match("^https?://") then
            local code = img.custom_code or code_generator.generate(8)
            local metadata = img.metadata or {}
            metadata.type = "imagebed"
            metadata.created_by = "imagebed_service"
            metadata.batch_index = i

            local expire_at = (data.expire_time and data.expire_time > 0) and (ngx.time() + data.expire_time) or nil

            local res, err = mysql_client.query(
                "INSERT INTO short_links(code,long_url,metadata,expire_at,created_at,updated_at,click_count,status) VALUES(?,?,?,?,NOW(),NOW(),0,'active')",
                {code, img.image_url, cjson.encode(metadata), expire_at}
            )

            if res then
                results.success = results.success + 1
                table.insert(results.results, {success=true, code=code, short_url=ngx.var.scheme.."://"..ngx.var.host.."/"..code, long_url=img.image_url})
            else
                results.failed = results.failed + 1
                table.insert(results.results, {success=false, error=err or "unknown"})
            end
        else
            results.failed = results.failed + 1
            table.insert(results.results, {success=false, error="无效URL"})
        end
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
        return respond_success({code=code, long_url=link.long_url, metadata=link.metadata, from_cache=true})
    end

    local res = mysql_client.query("SELECT code,long_url,metadata,expire_at,click_count,created_at,updated_at FROM short_links WHERE code=? AND status='active'", {code})

    if not res or #res == 0 then return respond_error("不存在", 404) end

    local link = res[1]
    local metadata = cjson.decode(link.metadata) or {}

    if metadata.type ~= "imagebed" then return respond_error("非图床短链", 400) end

    return respond_success({
        code = link.code,
        long_url = link.long_url,
        metadata = metadata,
        click_count = link.click_count,
        expire_at = link.expire_at,
        created_at = link.created_at,
        updated_at = link.updated_at,
        from_cache = false
    })
end

-- 更新元数据
function _M.update_metadata()
    local code = ngx.var.uri:match("^/api/imagebed/metadata/(.+)$")
    if not code then return respond_error("缺少代码") end

    local data, err = read_body()
    if not data then return respond_error(err) end

    local res = mysql_client.query("SELECT metadata FROM short_links WHERE code=? AND status='active'", {code})
    if not res or #res == 0 then return respond_error("不存在", 404) end

    local metadata = cjson.decode(res[1].metadata) or {}
    if metadata.type ~= "imagebed" then return respond_error("非图床短链", 400) end

    for k, v in pairs(data) do
        if k ~= "type" and k ~= "created_by" then metadata[k] = v end
    end

    mysql_client.query("UPDATE short_links SET metadata=?, updated_at=NOW() WHERE code=?", {cjson.encode(metadata), code})

    redis_client.del("link:" .. code)

    logger.info("更新元数据:" .. code)

    return respond_success({code=code, metadata=metadata, updated_at=ngx.time()})
end

-- 统计
function _M.get_stats()
    local total = mysql_client.query("SELECT COUNT(*)as c FROM short_links WHERE JSON_EXTRACT(metadata,'$.type')='imagebed' AND status='active'")
    local today = mysql_client.query("SELECT COUNT(*)as c FROM short_links WHERE JSON_EXTRACT(metadata,'$.type')='imagebed' AND DATE(created_at)=CURDATE() AND status='active'")
    local clicks = mysql_client.query("SELECT SUM(click_count)as c FROM short_links WHERE JSON_EXTRACT(metadata,'$.type')='imagebed' AND status='active'")
    local top = mysql_client.query("SELECT code,long_url,click_count,created_at FROM short_links WHERE JSON_EXTRACT(metadata,'$.type')='imagebed' AND status='active' ORDER BY click_count DESC LIMIT 10")

    local top_images = {}
    if top then
        for _, row in ipairs(top) do
            table.insert(top_images, {code=row.code, long_url=row.long_url, click_count=row.click_count, created_at=row.created_at})
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
