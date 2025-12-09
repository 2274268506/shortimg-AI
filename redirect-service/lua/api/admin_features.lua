-- 短链管理扩展 API
-- 文件: lua/api/admin_features.lua
-- 功能: 回收站、高级搜索、批量操作等扩展功能

local cjson = require "cjson"
local mysql_client = require "storage.mysql_client"
local redis_client = require "cache.redis_client"
local logger = require "logger.logger"

local _M = {}

-- 辅助函数
local function respond_success(data, meta)
    ngx.status = ngx.HTTP_OK
    ngx.header.content_type = "application/json"
    
    local response = {
        success = true,
        data = data or {}
    }
    
    if meta then
        response.meta = meta
    end
    
    ngx.say(cjson.encode(response))
    ngx.exit(ngx.HTTP_OK)
end

local function respond_error(message, status)
    ngx.status = status or ngx.HTTP_BAD_REQUEST
    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode({
        success = false,
        error = message
    }))
    ngx.exit(status or ngx.HTTP_BAD_REQUEST)
end

local function read_body()
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    if not body then
        return nil, "请求体为空"
    end
    
    local ok, data = pcall(cjson.decode, body)
    if not ok then
        return nil, "JSON 解析失败"
    end
    
    return data
end

-- ========================================
-- 回收站功能
-- ========================================

-- 获取已删除的短链列表
function _M.list_deleted()
    local args = ngx.req.get_uri_args()
    local page = tonumber(args.page) or 1
    local page_size = tonumber(args.page_size) or 20
    local service_type = args.service_type
    
    -- 构建查询条件
    local where = "status = 'deleted'"
    if service_type then
        where = where .. " AND service_type = '" .. service_type .. "'"
    end
    
    -- 查询总数
    local count_sql = string.format(
        "SELECT COUNT(*) as total FROM short_links WHERE %s",
        where
    )
    local count_result, err = mysql_client.query(count_sql)
    if not count_result then
        return respond_error("查询失败: " .. err, 500)
    end
    
    local total = count_result[1].total
    local total_pages = math.ceil(total / page_size)
    
    -- 查询列表
    local offset = (page - 1) * page_size
    local list_sql = string.format(
        "SELECT short_code, service_type, visit_count, created_at, updated_at, deleted_at " ..
        "FROM short_links WHERE %s " ..
        "ORDER BY deleted_at DESC LIMIT %d OFFSET %d",
        where, page_size, offset
    )
    
    local links, err = mysql_client.query(list_sql)
    if not links then
        return respond_error("查询失败: " .. err, 500)
    end
    
    return respond_success({
        links = links,
        pagination = {
            page = page,
            page_size = page_size,
            total = total,
            total_pages = total_pages
        }
    })
end

-- 恢复已删除的短链
function _M.restore()
    local uri = ngx.var.uri
    local short_code = uri:match("^/api/v2/imagebed/restore/([^/]+)$")
    
    if not short_code then
        return respond_error("缺少 short_code 参数")
    end
    
    -- 检查短链是否存在且已删除
    local check_sql = string.format(
        "SELECT status FROM short_links WHERE short_code = '%s'",
        short_code
    )
    local result, err = mysql_client.query(check_sql)
    if not result or #result == 0 then
        return respond_error("短链不存在", 404)
    end
    
    if result[1].status ~= 'deleted' then
        return respond_error("短链未被删除，无需恢复", 400)
    end
    
    -- 恢复短链
    local restore_sql = string.format(
        "UPDATE short_links SET status = 'active', deleted_at = NULL, " ..
        "updated_at = NOW() WHERE short_code = '%s'",
        short_code
    )
    
    local ok, err = mysql_client.execute(restore_sql)
    if not ok then
        return respond_error("恢复失败: " .. err, 500)
    end
    
    -- 清除缓存
    redis_client.del("short_link:" .. short_code)
    
    logger.info("短链已恢复: " .. short_code)
    return respond_success({
        short_code = short_code,
        message = "恢复成功"
    })
end

-- 永久删除短链
function _M.permanent_delete()
    local uri = ngx.var.uri
    local short_code = uri:match("^/api/v2/imagebed/permanent/([^/]+)$")
    
    if not short_code then
        return respond_error("缺少 short_code 参数")
    end
    
    -- 删除短链记录
    local delete_sql = string.format(
        "DELETE FROM short_links WHERE short_code = '%s'",
        short_code
    )
    
    local ok, err = mysql_client.execute(delete_sql)
    if not ok then
        return respond_error("删除失败: " .. err, 500)
    end
    
    -- 删除访问日志（如果有）
    local delete_logs_sql = string.format(
        "DELETE FROM access_logs WHERE short_code = '%s'",
        short_code
    )
    mysql_client.execute(delete_logs_sql)  -- 忽略错误
    
    -- 清除缓存
    redis_client.del("short_link:" .. short_code)
    
    logger.info("短链已永久删除: " .. short_code)
    return respond_success({
        short_code = short_code,
        message = "永久删除成功"
    })
end

-- ========================================
-- 高级搜索功能
-- ========================================

-- 高级搜索短链
function _M.advanced_search()
    local data, err = read_body()
    if not data then
        return respond_error(err)
    end
    
    local page = data.page or 1
    local page_size = data.page_size or 20
    local where_conditions = {}
    local params = {}
    
    -- 构建查询条件
    if data.short_code then
        table.insert(where_conditions, "short_code LIKE ?")
        table.insert(params, "%" .. data.short_code .. "%")
    end
    
    if data.service_type then
        table.insert(where_conditions, "service_type = ?")
        table.insert(params, data.service_type)
    end
    
    if data.status then
        table.insert(where_conditions, "status = ?")
        table.insert(params, data.status)
    end
    
    if data.date_from then
        table.insert(where_conditions, "created_at >= ?")
        table.insert(params, data.date_from)
    end
    
    if data.date_to then
        table.insert(where_conditions, "created_at <= ?")
        table.insert(params, data.date_to)
    end
    
    if data.visit_count_min then
        table.insert(where_conditions, "visit_count >= ?")
        table.insert(params, data.visit_count_min)
    end
    
    if data.visit_count_max then
        table.insert(where_conditions, "visit_count <= ?")
        table.insert(params, data.visit_count_max)
    end
    
    local where_clause = #where_conditions > 0 
        and ("WHERE " .. table.concat(where_conditions, " AND "))
        or ""
    
    -- 查询总数
    local count_sql = "SELECT COUNT(*) as total FROM short_links " .. where_clause
    local count_result, err = mysql_client.query_with_params(count_sql, params)
    if not count_result then
        return respond_error("查询失败: " .. err, 500)
    end
    
    local total = count_result[1].total
    local total_pages = math.ceil(total / page_size)
    
    -- 查询列表
    local offset = (page - 1) * page_size
    local order_by = data.order_by or "created_at"
    local order_direction = data.order_direction or "DESC"
    
    local list_sql = string.format(
        "SELECT * FROM short_links %s ORDER BY %s %s LIMIT ? OFFSET ?",
        where_clause, order_by, order_direction
    )
    
    table.insert(params, page_size)
    table.insert(params, offset)
    
    local links, err = mysql_client.query_with_params(list_sql, params)
    if not links then
        return respond_error("查询失败: " .. err, 500)
    end
    
    return respond_success({
        links = links,
        pagination = {
            page = page,
            page_size = page_size,
            total = total,
            total_pages = total_pages
        }
    })
end

-- ========================================
-- 批量导出功能
-- ========================================

-- 导出短链数据 (CSV 格式)
function _M.export()
    local args = ngx.req.get_uri_args()
    local format = args.format or "csv"
    local service_type = args.service_type
    local status = args.status
    
    -- 构建查询条件
    local where_conditions = {}
    if service_type then
        table.insert(where_conditions, "service_type = '" .. service_type .. "'")
    end
    if status then
        table.insert(where_conditions, "status = '" .. status .. "'")
    end
    
    local where_clause = #where_conditions > 0 
        and ("WHERE " .. table.concat(where_conditions, " AND "))
        or ""
    
    -- 查询数据
    local sql = "SELECT * FROM short_links " .. where_clause .. " ORDER BY created_at DESC"
    local links, err = mysql_client.query(sql)
    if not links then
        return respond_error("查询失败: " .. err, 500)
    end
    
    if format == "csv" then
        -- 生成 CSV
        local csv_lines = {
            "短链码,服务类型,状态,目标URL,访问量,创建时间,更新时间"
        }
        
        for _, link in ipairs(links) do
            local targets = link.targets
            if type(targets) == "string" then
                -- 简化输出
                targets = targets:gsub('"', '""')  -- 转义引号
            end
            
            local line = string.format(
                '%s,%s,%s,"%s",%d,%s,%s',
                link.short_code,
                link.service_type,
                link.status,
                targets or "",
                link.visit_count or 0,
                link.created_at or "",
                link.updated_at or ""
            )
            table.insert(csv_lines, line)
        end
        
        ngx.header.content_type = "text/csv"
        ngx.header["Content-Disposition"] = 'attachment; filename="shortlinks_' .. os.time() .. '.csv"'
        ngx.say(table.concat(csv_lines, "\n"))
        return
    elseif format == "json" then
        -- JSON 格式
        ngx.header.content_type = "application/json"
        ngx.header["Content-Disposition"] = 'attachment; filename="shortlinks_' .. os.time() .. '.json"'
        ngx.say(cjson.encode({
            success = true,
            data = links,
            exported_at = os.date("%Y-%m-%d %H:%M:%S"),
            total = #links
        }))
        return
    else
        return respond_error("不支持的导出格式: " .. format, 400)
    end
end

-- ========================================
-- 批量导入功能
-- ========================================

-- 导入短链数据
function _M.import()
    local data, err = read_body()
    if not data then
        return respond_error(err)
    end
    
    if not data.links or type(data.links) ~= "table" then
        return respond_error("links 参数必须是数组")
    end
    
    local success_count = 0
    local failed_count = 0
    local results = {}
    
    for i, link_data in ipairs(data.links) do
        -- 验证必需字段
        if not link_data.image_path and not link_data.targets then
            table.insert(results, {
                index = i,
                success = false,
                error = "缺少 image_path 或 targets 参数"
            })
            failed_count = failed_count + 1
        else
            -- 调用创建API
            local create_result, create_err = mysql_client.create_imagebed_link(link_data)
            
            if create_result then
                success_count = success_count + 1
                table.insert(results, {
                    index = i,
                    success = true,
                    short_code = create_result.short_code
                })
            else
                failed_count = failed_count + 1
                table.insert(results, {
                    index = i,
                    success = false,
                    error = create_err or "创建失败"
                })
            end
        end
    end
    
    return respond_success({
        total = #data.links,
        success_count = success_count,
        failed_count = failed_count,
        results = results
    })
end

-- ========================================
-- 下载导入模板
-- ========================================

function _M.template()
    local format = ngx.var.arg_format or "csv"
    
    if format == "csv" then
        local template = [[短链码,服务类型,目标路径,访问策略,过期时间(秒),备注
my-image1,imagebed,/i/abc-123-def,weighted,,我的图片1
my-image2,imagebed,/i/xyz-789-uvw,round_robin,86400,我的图片2(24小时后过期)
my-link1,general,https://example.com,random,,通用短链示例]]
        
        ngx.header.content_type = "text/csv; charset=utf-8"
        ngx.header["Content-Disposition"] = 'attachment; filename="shortlink_import_template.csv"'
        ngx.say(template)
    elseif format == "json" then
        local template = {
            links = {
                {
                    short_code = "my-image1",
                    service_type = "imagebed",
                    image_path = "/i/abc-123-def",
                    strategy = "weighted",
                    note = "我的图片1"
                },
                {
                    short_code = "my-image2",
                    service_type = "imagebed",
                    image_path = "/i/xyz-789-uvw",
                    strategy = "round_robin",
                    expire_time = 86400,
                    note = "我的图片2(24小时后过期)"
                }
            }
        }
        
        ngx.header.content_type = "application/json"
        ngx.header["Content-Disposition"] = 'attachment; filename="shortlink_import_template.json"'
        ngx.say(cjson.encode(template))
    else
        return respond_error("不支持的格式: " .. format, 400)
    end
end

-- ========================================
-- 路由处理
-- ========================================

function _M.handle()
    local method = ngx.var.request_method
    local uri = ngx.var.uri
    
    -- 回收站相关
    if uri == "/api/v2/imagebed/trash" and method == "GET" then
        return _M.list_deleted()
    elseif uri:match("^/api/v2/imagebed/restore/") and method == "POST" then
        return _M.restore()
    elseif uri:match("^/api/v2/imagebed/permanent/") and method == "DELETE" then
        return _M.permanent_delete()
    
    -- 高级搜索
    elseif uri == "/api/v2/imagebed/search" and method == "POST" then
        return _M.advanced_search()
    
    -- 导入导出
    elseif uri == "/api/v2/imagebed/export" and method == "GET" then
        return _M.export()
    elseif uri == "/api/v2/imagebed/import" and method == "POST" then
        return _M.import()
    elseif uri == "/api/v2/imagebed/template" and method == "GET" then
        return _M.template()
    
    else
        return respond_error("API 不存在", 404)
    end
end

return _M
