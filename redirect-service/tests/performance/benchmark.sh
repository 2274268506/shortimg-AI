#!/bin/bash
# 短链服务性能基准测试 - 使用 wrk
# wrk 是一个现代化的 HTTP 基准测试工具，支持 Lua 脚本

BASE_URL=${BASE_URL:-"http://localhost"}
API_KEY=${API_KEY:-"sk_test_12345678901234567890123456789012"}
DURATION=${DURATION:-"30s"}
THREADS=${THREADS:-"12"}
CONNECTIONS=${CONNECTIONS:-"400"}

echo "========================================"
echo "短链服务性能基准测试 (wrk)"
echo "========================================"
echo ""
echo "测试配置:"
echo "  BASE_URL: $BASE_URL"
echo "  持续时间: $DURATION"
echo "  线程数: $THREADS"
echo "  连接数: $CONNECTIONS"
echo ""

# 检查 wrk 是否安装
if ! command -v wrk &> /dev/null; then
    echo "❌ wrk 未安装"
    echo ""
    echo "请安装 wrk:"
    echo "  Ubuntu/Debian: sudo apt-get install wrk"
    echo "  CentOS/RHEL: sudo yum install wrk"
    echo "  macOS: brew install wrk"
    echo "  Windows: 下载预编译版本或使用 WSL"
    echo ""
    exit 1
fi

# 创建测试短链
echo "准备测试数据..."
curl -X POST "$BASE_URL/api/v1/links" \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "short_code": "wrk_test",
    "targets": [{"url": "https://www.example.com", "weight": 100}],
    "strategy": "round_robin"
  }' > /dev/null 2>&1

echo "✅ 测试数据准备完成"
echo ""

# 1. 健康检查性能测试
echo "========================================"
echo "1. 健康检查 API (/health)"
echo "========================================"
wrk -t$THREADS -c$CONNECTIONS -d$DURATION "$BASE_URL/health"

sleep 2

# 2. 短链重定向性能测试
echo ""
echo "========================================"
echo "2. 短链重定向 API (/r/wrk_test)"
echo "========================================"
wrk -t$THREADS -c$CONNECTIONS -d$DURATION "$BASE_URL/r/wrk_test"

sleep 2

# 3. API 查询性能测试
echo ""
echo "========================================"
echo "3. 短链查询 API"
echo "========================================"
wrk -t$THREADS -c$CONNECTIONS -d$DURATION \
  -H "X-API-Key: $API_KEY" \
  "$BASE_URL/api/v1/links/wrk_test"

sleep 2

# 4. 混合场景测试（Lua 脚本）
echo ""
echo "========================================"
echo "4. 混合场景测试"
echo "========================================"

# 创建 wrk Lua 脚本
cat > /tmp/wrk_mixed.lua << 'EOF'
-- 混合场景：70% 重定向, 20% 查询, 10% 创建
wrk.method = "GET"
wrk.headers["X-API-Key"] = "sk_test_12345678901234567890123456789012"

counter = 0

request = function()
    counter = counter + 1
    local rand = counter % 10

    if rand < 7 then
        -- 70% 重定向
        return wrk.format("GET", "/r/wrk_test")
    elseif rand < 9 then
        -- 20% 查询
        return wrk.format("GET", "/api/v1/links/wrk_test", wrk.headers)
    else
        -- 10% 创建（实际会因为重复而失败，但测试写入性能）
        wrk.headers["Content-Type"] = "application/json"
        local body = string.format('{"short_code":"test_%d","targets":[{"url":"https://example.com"}]}', counter)
        return wrk.format("POST", "/api/v1/links", wrk.headers, body)
    end
end
EOF

wrk -t$THREADS -c$CONNECTIONS -d$DURATION -s /tmp/wrk_mixed.lua "$BASE_URL"

# 清理
echo ""
echo "清理测试数据..."
curl -X DELETE "$BASE_URL/api/v1/links/wrk_test" \
  -H "X-API-Key: $API_KEY" > /dev/null 2>&1

rm -f /tmp/wrk_mixed.lua

echo ""
echo "========================================"
echo "性能测试完成"
echo "========================================"
echo ""
echo "性能目标:"
echo "  ✓ 健康检查: 20000+ req/s"
echo "  ✓ 重定向: 10000+ req/s"
echo "  ✓ API查询: 5000+ req/s"
echo "  ✓ 延迟 P99: < 50ms"
echo ""
