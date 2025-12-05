-- tests/unit/test_health.lua
-- 健康检查单元测试

describe("Health Check API", function()
    local health
    local redis_client
    local mysql_client

    before_each(function()
        health = require "api.health"
        redis_client = require "storage.redis_client"
        mysql_client = require "storage.mysql_client"
    end)

    describe("check_redis", function()
        it("应该在 Redis 正常时返回 healthy", function()
            stub(redis_client, "get", function() return "OK" end)

            local status = health.check_redis()

            assert.equals("healthy", status)
        end)

        it("应该在 Redis 异常时返回 unhealthy", function()
            stub(redis_client, "get", function() return nil, "connection failed" end)

            local status = health.check_redis()

            assert.equals("unhealthy", status)
        end)
    end)

    describe("check_mysql", function()
        it("应该在 MySQL 正常时返回 healthy", function()
            stub(mysql_client, "get_link", function() return {} end)

            local status = health.check_mysql()

            assert.equals("healthy", status)
        end)

        it("应该在 MySQL 异常时返回 unhealthy", function()
            stub(mysql_client, "get_link", function() return nil, "connection failed" end)

            local status = health.check_mysql()

            assert.equals("unhealthy", status)
        end)
    end)

    describe("overall_health", function()
        it("应该在所有服务健康时返回 200", function()
            stub(redis_client, "get", function() return "OK" end)
            stub(mysql_client, "get_link", function() return {} end)

            local status_code = health.check()

            assert.equals(200, status_code)
        end)

        it("应该在任一服务异常时返回 503", function()
            stub(redis_client, "get", function() return nil, "error" end)
            stub(mysql_client, "get_link", function() return {} end)

            local status_code = health.check()

            assert.equals(503, status_code)
        end)
    end)
end)
