-- sync_api_keys_to_redis.lua
-- 同步 API Keys 到 Redis

local mysql_client = require "storage.mysql_client"
local redis_client = require "storage.redis_client"
local cjson = require "cjson"

-- 从MySQL获取API Keys
local query = "SELECT api_key, name, allowed_domains, max_requests_per_day, is_active FROM api_keys WHERE is_active = 1"
local results, err = mysql_client.query(query)

if err then
    ngx.log(ngx.ERR, "查询API Keys失败: ", err)
    ngx.say("ERROR: ", err)
    return
end

if not results or #results == 0 then
    ngx.say("No active API keys found")
    return
end

-- 同步到Redis
local synced = 0
for _, key_info in ipairs(results) do
    local redis_key = "api_key:" .. key_info.api_key
    local redis_value = cjson.encode({
        name = key_info.name,
        allowed_domains = key_info.allowed_domains or "*",
        max_requests = key_info.max_requests_per_day or 0,
        status = (key_info.is_active == 1) and "active" or "disabled",
        api_key = key_info.api_key
    })

    local ok, err = redis_client.set(redis_key, redis_value, 0) --  TTL (0 = 不过期)
    if ok then
        synced = synced + 1
        ngx.log(ngx.INFO, "已同步 API Key: ", key_info.api_key)
    else
        ngx.log(ngx.ERR, "同步失败: ", key_info.api_key, " - ", err)
    end
end

ngx.say("✅ 成功同步 ", synced, " 个 API Keys 到 Redis")
