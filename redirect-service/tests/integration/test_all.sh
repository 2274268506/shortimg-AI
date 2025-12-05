#!/bin/bash
# 短链服务完整功能测试脚本

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
BASE_URL="${BASE_URL:-http://localhost}"
API_KEY="${API_KEY:-}"

# 测试结果统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 打印函数
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_test() {
    echo -e "${YELLOW}[测试] $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_TESTS++))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_TESTS++))
}

# HTTP 请求函数
http_get() {
    local url=$1
    local headers=${2:-}

    if [ -n "$API_KEY" ]; then
        curl -s -w "\n%{http_code}" -H "X-API-Key: $API_KEY" $headers "$url"
    else
        curl -s -w "\n%{http_code}" $headers "$url"
    fi
}

http_post() {
    local url=$1
    local data=$2
    local headers=${3:-}

    if [ -n "$API_KEY" ]; then
        curl -s -w "\n%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -H "X-API-Key: $API_KEY" \
            $headers \
            -d "$data" \
            "$url"
    else
        curl -s -w "\n%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            $headers \
            -d "$data" \
            "$url"
    fi
}

http_delete() {
    local url=$1

    if [ -n "$API_KEY" ]; then
        curl -s -w "\n%{http_code}" -X DELETE \
            -H "X-API-Key: $API_KEY" \
            "$url"
    else
        curl -s -w "\n%{http_code}" -X DELETE "$url"
    fi
}

# 测试函数
test_response() {
    local response=$1
    local expected_code=$2
    local test_name=$3

    ((TOTAL_TESTS++))

    # 提取状态码（最后一行）
    local status_code=$(echo "$response" | tail -n 1)
    local body=$(echo "$response" | sed '$d')

    if [ "$status_code" -eq "$expected_code" ]; then
        print_success "$test_name (状态码: $status_code)"
        return 0
    else
        print_error "$test_name (期望: $expected_code, 实际: $status_code)"
        echo "响应内容: $body"
        return 1
    fi
}

# ============================================
# 阶段 1: 健康检查测试
# ============================================
test_health_checks() {
    print_header "阶段 1: 健康检查测试"

    # 测试 1.1: 完整健康检查
    print_test "1.1 完整健康检查 (/health)"
    response=$(http_get "$BASE_URL/health")
    test_response "$response" 200 "完整健康检查"

    # 测试 1.2: 活跃性检查
    print_test "1.2 活跃性检查 (/health/live)"
    response=$(http_get "$BASE_URL/health/live")
    test_response "$response" 200 "活跃性检查"

    # 测试 1.3: 就绪性检查
    print_test "1.3 就绪性检查 (/health/ready)"
    response=$(http_get "$BASE_URL/health/ready")
    test_response "$response" 200 "就绪性检查"
}

# ============================================
# 阶段 2: API 认证测试
# ============================================
test_api_authentication() {
    print_header "阶段 2: API 认证测试"

    # 测试 2.1: 无认证访问（应该失败）
    print_test "2.1 无认证访问管理 API（应该返回 401）"
    OLD_API_KEY=$API_KEY
    API_KEY=""
    response=$(http_get "$BASE_URL/api/v1/stats/overview" || true)
    API_KEY=$OLD_API_KEY
    test_response "$response" 401 "无认证访问被拒绝"

    # 测试 2.2: 有效认证访问
    if [ -n "$API_KEY" ]; then
        print_test "2.2 有效 API Key 访问"
        response=$(http_get "$BASE_URL/api/v1/stats/overview")
        test_response "$response" 200 "有效认证访问"
    else
        print_error "未提供 API_KEY，跳过认证测试"
        ((TOTAL_TESTS++))
        ((FAILED_TESTS++))
    fi
}

# ============================================
# 阶段 3: 短链管理测试
# ============================================
test_link_management() {
    print_header "阶段 3: 短链管理测试"

    if [ -z "$API_KEY" ]; then
        print_error "需要 API_KEY 进行测试，跳过短链管理测试"
        return
    fi

    local test_code="test_$(date +%s)"

    # 测试 3.1: 创建短链
    print_test "3.1 创建短链 ($test_code)"
    local create_data='{
        "short_code": "'$test_code'",
        "targets": [
            {
                "cdn": "north_telecom",
                "path": "/test/image.jpg",
                "weight": 5
            }
        ],
        "strategy": "round_robin",
        "security_config": {}
    }'
    response=$(http_post "$BASE_URL/api/v1/links" "$create_data")
    test_response "$response" 200 "创建短链"

    # 测试 3.2: 查询短链
    print_test "3.2 查询短链 ($test_code)"
    response=$(http_get "$BASE_URL/api/v1/links/$test_code")
    test_response "$response" 200 "查询短链"

    # 测试 3.3: 访问短链（重定向）
    print_test "3.3 访问短链重定向 (/r/$test_code)"
    response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/r/$test_code" || echo "000")
    if [ "$response" = "302" ] || [ "$response" = "301" ]; then
        print_success "短链重定向 (状态码: $response)"
        ((TOTAL_TESTS++))
        ((PASSED_TESTS++))
    else
        print_error "短链重定向失败 (状态码: $response)"
        ((TOTAL_TESTS++))
        ((FAILED_TESTS++))
    fi

    # 测试 3.4: 更新短链
    print_test "3.4 更新短链状态"
    local update_data='{
        "status": "inactive"
    }'
    response=$(curl -s -w "\n%{http_code}" -X PUT \
        -H "Content-Type: application/json" \
        -H "X-API-Key: $API_KEY" \
        -d "$update_data" \
        "$BASE_URL/api/v1/links/$test_code")
    test_response "$response" 200 "更新短链状态"

    # 测试 3.5: 删除短链
    print_test "3.5 删除短链"
    response=$(http_delete "$BASE_URL/api/v1/links/$test_code")
    test_response "$response" 200 "删除短链"
}

# ============================================
# 阶段 4: 批量操作测试
# ============================================
test_batch_operations() {
    print_header "阶段 4: 批量操作测试"

    if [ -z "$API_KEY" ]; then
        print_error "需要 API_KEY 进行测试，跳过批量操作测试"
        return
    fi

    local timestamp=$(date +%s)

    # 测试 4.1: 批量创建
    print_test "4.1 批量创建短链（3条）"
    local batch_create_data='{
        "links": [
            {
                "short_code": "batch1_'$timestamp'",
                "targets": [{"cdn": "north_telecom", "path": "/img1.jpg"}],
                "strategy": "round_robin"
            },
            {
                "short_code": "batch2_'$timestamp'",
                "targets": [{"cdn": "south_unicom", "path": "/img2.jpg"}],
                "strategy": "geo"
            },
            {
                "short_code": "batch3_'$timestamp'",
                "targets": [{"cdn": "overseas", "path": "/img3.jpg"}],
                "strategy": "random"
            }
        ]
    }'
    response=$(http_post "$BASE_URL/api/v1/batch/create" "$batch_create_data")
    test_response "$response" 200 "批量创建短链"

    # 测试 4.2: 批量查询
    print_test "4.2 批量查询短链"
    local batch_query_data='{
        "short_codes": ["batch1_'$timestamp'", "batch2_'$timestamp'", "batch3_'$timestamp'"]
    }'
    response=$(http_post "$BASE_URL/api/v1/batch/query" "$batch_query_data")
    test_response "$response" 200 "批量查询短链"

    # 测试 4.3: 批量更新状态
    print_test "4.3 批量更新状态"
    local batch_status_data='{
        "short_codes": ["batch1_'$timestamp'", "batch2_'$timestamp'"],
        "status": "inactive"
    }'
    response=$(http_post "$BASE_URL/api/v1/batch/status" "$batch_status_data")
    test_response "$response" 200 "批量更新状态"

    # 测试 4.4: 批量删除
    print_test "4.4 批量删除短链"
    local batch_delete_data='{
        "short_codes": ["batch1_'$timestamp'", "batch2_'$timestamp'", "batch3_'$timestamp'"]
    }'
    response=$(http_post "$BASE_URL/api/v1/batch/delete" "$batch_delete_data")
    test_response "$response" 200 "批量删除短链"
}

# ============================================
# 阶段 5: 统计分析测试
# ============================================
test_statistics() {
    print_header "阶段 5: 统计分析测试"

    if [ -z "$API_KEY" ]; then
        print_error "需要 API_KEY 进行测试，跳过统计测试"
        return
    fi

    # 测试 5.1: 总览统计
    print_test "5.1 获取总览统计"
    response=$(http_get "$BASE_URL/api/v1/stats/overview")
    test_response "$response" 200 "总览统计"

    # 创建测试短链用于统计
    local stat_test_code="stat_test_$(date +%s)"
    local create_data='{
        "short_code": "'$stat_test_code'",
        "targets": [{"cdn": "north_telecom", "path": "/stat_test.jpg"}],
        "strategy": "round_robin"
    }'
    http_post "$BASE_URL/api/v1/links" "$create_data" > /dev/null

    # 访问几次生成统计数据
    for i in {1..5}; do
        curl -s -o /dev/null "$BASE_URL/r/$stat_test_code" || true
        sleep 0.1
    done

    # 测试 5.2: 仪表板统计
    print_test "5.2 获取仪表板统计"
    response=$(http_get "$BASE_URL/api/v1/stats/$stat_test_code/dashboard?days=7")
    test_response "$response" 200 "仪表板统计"

    # 测试 5.3: 设备统计
    print_test "5.3 获取设备统计"
    response=$(http_get "$BASE_URL/api/v1/stats/$stat_test_code/device")
    test_response "$response" 200 "设备统计"

    # 测试 5.4: 地理分布统计
    print_test "5.4 获取地理分布统计"
    response=$(http_get "$BASE_URL/api/v1/stats/$stat_test_code/geo?limit=10")
    test_response "$response" 200 "地理分布统计"

    # 清理测试数据
    http_delete "$BASE_URL/api/v1/links/$stat_test_code" > /dev/null
}

# ============================================
# 阶段 6: 定时任务测试
# ============================================
test_scheduled_tasks() {
    print_header "阶段 6: 定时任务测试"

    if [ -z "$API_KEY" ]; then
        print_error "需要 API_KEY 进行测试，跳过定时任务测试"
        return
    fi

    # 测试 6.1: 获取任务状态
    print_test "6.1 获取定时任务状态"
    response=$(http_get "$BASE_URL/api/v1/tasks/status")
    test_response "$response" 200 "获取任务状态"

    # 测试 6.2: 手动触发任务
    print_test "6.2 手动触发任务（清理健康检查数据）"
    local trigger_data='{
        "task_name": "clean_health_check_data"
    }'
    response=$(http_post "$BASE_URL/api/v1/tasks/trigger" "$trigger_data")
    test_response "$response" 200 "手动触发任务"
}

# ============================================
# 阶段 7: 性能测试
# ============================================
test_performance() {
    print_header "阶段 7: 性能测试"

    print_test "7.1 并发访问测试（10个并发请求）"

    local start_time=$(date +%s)

    # 并发发送10个请求
    for i in {1..10}; do
        curl -s -o /dev/null "$BASE_URL/health" &
    done
    wait

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ $duration -lt 5 ]; then
        print_success "并发性能测试 (完成时间: ${duration}秒)"
        ((TOTAL_TESTS++))
        ((PASSED_TESTS++))
    else
        print_error "并发性能测试 (完成时间过长: ${duration}秒)"
        ((TOTAL_TESTS++))
        ((FAILED_TESTS++))
    fi

    # 测试 7.2: 响应时间测试
    print_test "7.2 响应时间测试"
    local response_time=$(curl -o /dev/null -s -w '%{time_total}' "$BASE_URL/health")
    local response_ms=$(echo "$response_time * 1000" | bc)

    if (( $(echo "$response_time < 1.0" | bc -l) )); then
        print_success "响应时间测试 (${response_ms}ms)"
        ((TOTAL_TESTS++))
        ((PASSED_TESTS++))
    else
        print_error "响应时间过长 (${response_ms}ms)"
        ((TOTAL_TESTS++))
        ((FAILED_TESTS++))
    fi
}

# ============================================
# 主测试流程
# ============================================
main() {
    print_header "短链服务完整功能测试"

    echo "测试配置:"
    echo "  BASE_URL: $BASE_URL"
    echo "  API_KEY: ${API_KEY:0:10}..."
    echo ""

    # 检查服务是否运行
    if ! curl -s -f "$BASE_URL/health" > /dev/null 2>&1; then
        echo -e "${RED}错误: 无法连接到服务 ($BASE_URL)${NC}"
        echo "请确保服务正在运行"
        exit 1
    fi

    # 执行所有测试
    test_health_checks
    test_api_authentication
    test_link_management
    test_batch_operations
    test_statistics
    test_scheduled_tasks
    test_performance

    # 输出测试结果
    print_header "测试结果汇总"

    echo -e "总测试数: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "通过数: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "失败数: ${RED}$FAILED_TESTS${NC}"

    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "\n${GREEN}🎉 所有测试通过！${NC}\n"
        exit 0
    else
        echo -e "\n${RED}⚠️  有 $FAILED_TESTS 个测试失败${NC}\n"
        exit 1
    fi
}

# 运行主函数
main
