-- tools/manage_api_keys.lua
-- API Key 管理工具

local redis = require "resty.redis"
local cjson = require "cjson.safe"
local resty_random = require "resty.random"
local str = require "resty.string"

-- 生成随机 API Key
local function generate_api_key()
    local random_bytes = resty_random.bytes(32)
    if not random_bytes then
        return nil, "生成随机数失败"
    end
    return "sk_" .. str.to_hex(random_bytes)
end

-- 连接 Redis
local function connect_redis()
    local red = redis:new()
    red:set_timeout(1000)

    local ok, err = red:connect(os.getenv("REDIS_HOST") or "127.0.0.1",
                                tonumber(os.getenv("REDIS_PORT")) or 6379)
    if not ok then
        return nil, "连接 Redis 失败: " .. err
    end

    local password = os.getenv("REDIS_PASSWORD")
    if password and password ~= "" then
        local res, err = red:auth(password)
        if not res then
            return nil, "Redis 认证失败: " .. err
        end
    end

    return red
end

-- 创建 API Key
local function create_api_key(name, permissions, expires_in_days)
    local red, err = connect_redis()
    if not red then
        return nil, err
    end

    local api_key = generate_api_key()
    if not api_key then
        return nil, "生成 API Key 失败"
    end

    local expires_at = 0
    if expires_in_days and expires_in_days > 0 then
        expires_at = os.time() + (expires_in_days * 24 * 3600)
    end

    local key_info = {
        api_key = api_key,
        name = name,
        permissions = permissions or {"short_link:read", "short_link:write"},
        status = "active",
        created_at = os.time(),
        expires_at = expires_at
    }

    local ok, err = red:set("api_key:" .. api_key, cjson.encode(key_info))
    if not ok then
        return nil, "保存 API Key 失败: " .. err
    end

    -- 如果设置了过期时间，设置 Redis 过期
    if expires_at > 0 then
        red:expireat("api_key:" .. api_key, expires_at)
    end

    print("✅ API Key 创建成功!")
    print("   Key: " .. api_key)
    print("   Name: " .. name)
    print("   Permissions: " .. table.concat(permissions or {}, ", "))
    print("   Expires: " .. (expires_at > 0 and os.date("%Y-%m-%d %H:%M:%S", expires_at) or "Never"))
    print("")
    print("请妥善保管此 API Key，它将不会再次显示。")

    return key_info
end

-- 列出所有 API Key
local function list_api_keys()
    local red, err = connect_redis()
    if not red then
        return nil, err
    end

    local keys, err = red:keys("api_key:*")
    if not keys then
        return nil, "查询失败: " .. err
    end

    if #keys == 0 then
        print("没有找到 API Key")
        return {}
    end

    print(string.format("%-40s %-20s %-15s %-20s", "API Key", "Name", "Status", "Expires"))
    print(string.rep("-", 95))

    for _, key in ipairs(keys) do
        local info_str, err = red:get(key)
        if info_str and info_str ~= ngx.null then
            local info = cjson.decode(info_str)
            if info then
                local api_key = key:sub(9)  -- 移除 "api_key:" 前缀
                local expires = info.expires_at > 0 and os.date("%Y-%m-%d %H:%M:%S", info.expires_at) or "Never"
                print(string.format("%-40s %-20s %-15s %-20s",
                    api_key:sub(1, 20) .. "...",
                    info.name or "N/A",
                    info.status or "unknown",
                    expires))
            end
        end
    end
end

-- 删除 API Key
local function delete_api_key(api_key)
    local red, err = connect_redis()
    if not red then
        return nil, err
    end

    local ok, err = red:del("api_key:" .. api_key)
    if not ok then
        return nil, "删除失败: " .. err
    end

    print("✅ API Key 已删除: " .. api_key)
    return true
end

-- 禁用 API Key
local function disable_api_key(api_key)
    local red, err = connect_redis()
    if not red then
        return nil, err
    end

    local info_str, err = red:get("api_key:" .. api_key)
    if not info_str or info_str == ngx.null then
        return nil, "API Key 不存在"
    end

    local info = cjson.decode(info_str)
    if not info then
        return nil, "解析 API Key 信息失败"
    end

    info.status = "disabled"

    local ok, err = red:set("api_key:" .. api_key, cjson.encode(info))
    if not ok then
        return nil, "更新失败: " .. err
    end

    print("✅ API Key 已禁用: " .. api_key)
    return true
end

-- 命令行接口
local function main()
    local command = arg[1]

    if command == "create" then
        local name = arg[2] or "Default API Key"
        local permissions_str = arg[3]
        local expires_in_days = tonumber(arg[4])

        local permissions = {"short_link:read", "short_link:write"}
        if permissions_str then
            permissions = {}
            for perm in permissions_str:gmatch("[^,]+") do
                table.insert(permissions, perm:match("^%s*(.-)%s*$"))
            end
        end

        create_api_key(name, permissions, expires_in_days)

    elseif command == "list" then
        list_api_keys()

    elseif command == "delete" then
        local api_key = arg[2]
        if not api_key then
            print("错误: 请提供 API Key")
            return
        end
        delete_api_key(api_key)

    elseif command == "disable" then
        local api_key = arg[2]
        if not api_key then
            print("错误: 请提供 API Key")
            return
        end
        disable_api_key(api_key)

    else
        print("用法:")
        print("  lua manage_api_keys.lua create [name] [permissions] [expires_days]")
        print("  lua manage_api_keys.lua list")
        print("  lua manage_api_keys.lua delete <api_key>")
        print("  lua manage_api_keys.lua disable <api_key>")
        print("")
        print("示例:")
        print("  lua manage_api_keys.lua create 'My App' 'short_link:read,short_link:write' 365")
        print("  lua manage_api_keys.lua create 'Admin Key' '*' 0")
        print("  lua manage_api_keys.lua list")
        print("  lua manage_api_keys.lua delete sk_abc123...")
    end
end

-- 执行
main()
