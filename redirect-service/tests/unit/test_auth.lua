-- tests/unit/test_auth.lua
-- 认证中间件单元测试

describe("Auth Middleware", function()
    local auth
    local redis_client

    before_each(function()
        auth = require "middleware.auth"
        redis_client = require "storage.redis_client"
    end)

    describe("verify_api_key", function()
        it("应该接受有效的 API Key", function()
            -- 模拟 Redis 返回有效的 API Key
            stub(redis_client, "get", function(key)
                if key:match("^api_key:") then
                    return '{"status":"active","expires_at":0,"permissions":["*"]}'
                end
            end)

            local result = auth.verify_api_key("valid_api_key")

            assert.is_true(result)
        end)

        it("应该拒绝无效的 API Key", function()
            stub(redis_client, "get", function(key)
                return nil, "key不存在"
            end)

            local result = auth.verify_api_key("invalid_api_key")

            assert.is_false(result)
        end)

        it("应该拒绝已过期的 API Key", function()
            stub(redis_client, "get", function(key)
                return '{"status":"active","expires_at":' .. (os.time() - 3600) .. '}'
            end)

            local result = auth.verify_api_key("expired_api_key")

            assert.is_false(result)
        end)
    end)

    describe("rate_limit", function()
        it("应该允许限制内的请求", function()
            stub(redis_client, "incr", function() return 5 end)

            local result = auth.rate_limit(10, 60)

            assert.is_true(result)
        end)

        it("应该拒绝超过限制的请求", function()
            stub(redis_client, "incr", function() return 11 end)

            local result = auth.rate_limit(10, 60)

            assert.is_false(result)
        end)
    end)
end)
