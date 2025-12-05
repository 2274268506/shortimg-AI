-- tests/unit/test_router.lua
-- 路由模块单元测试

describe("Router Module", function()
    local router

    before_each(function()
        router = require "core.router"
    end)

    describe("select_target", function()
        it("应该根据地理位置选择正确的目标", function()
            local targets = {
                {
                    cdn = "north_telecom",
                    path = "/image.jpg",
                    region = "cn-north",
                    isp = "telecom",
                    weight = 5
                },
                {
                    cdn = "south_unicom",
                    path = "/image.jpg",
                    region = "cn-south",
                    isp = "unicom",
                    weight = 3
                }
            }

            local geo_info = {
                country_code = "CN",
                province = "北京",
                isp = "电信"
            }

            local target = router.select_target(targets, "geo", geo_info)

            assert.is_not_nil(target)
            assert.equals("north_telecom", target.cdn)
        end)

        it("应该在健康检查失败时选择备用目标", function()
            local targets = {
                {
                    cdn = "primary",
                    path = "/image.jpg",
                    health_check = true
                },
                {
                    cdn = "fallback",
                    path = "/image.jpg",
                    health_check = true
                }
            }

            -- 模拟健康检查失败
            stub(router, "check_health", function() return false end)

            local target = router.select_target(targets, "round_robin", nil)

            assert.is_not_nil(target)
            assert.equals("fallback", target.cdn)
        end)
    end)

    describe("validate_referer", function()
        it("应该验证允许的 Referer", function()
            local allowed_referers = {"https://example.com", "https://test.com"}

            local result = router.validate_referer("https://example.com/page", allowed_referers)

            assert.is_true(result)
        end)

        it("应该拒绝不允许的 Referer", function()
            local allowed_referers = {"https://example.com"}

            local result = router.validate_referer("https://malicious.com", allowed_referers)

            assert.is_false(result)
        end)
    end)
end)
