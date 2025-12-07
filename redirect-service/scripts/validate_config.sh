#!/bin/bash
# 短链服务配置验证脚本

set -e

echo "========================================"
echo "🔍 短链服务配置验证工具"
echo "========================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 加载 .env 文件
if [ ! -f .env ]; then
    echo -e "${RED}❌ 错误: .env 文件不存在${NC}"
    echo "   请先复制 .env.example 并配置"
    exit 1
fi

source .env

SUCCESS_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0

# 检查函数
check_config() {
    local name=$1
    local value=$2
    local required=$3
    local type=$4

    if [ -z "$value" ]; then
        if [ "$required" == "true" ]; then
            echo -e "${RED}❌ $name: 未配置（必需）${NC}"
            ((ERROR_COUNT++))
        else
            echo -e "${YELLOW}⚠️  $name: 未配置（可选）${NC}"
            ((WARNING_COUNT++))
        fi
    else
        echo -e "${GREEN}✅ $name: $value${NC}"
        ((SUCCESS_COUNT++))
    fi
}

# 检查文件存在
check_file() {
    local name=$1
    local path=$2
    local required=$3

    if [ -z "$path" ]; then
        if [ "$required" == "true" ]; then
            echo -e "${RED}❌ $name: 路径未配置${NC}"
            ((ERROR_COUNT++))
        fi
        return
    fi

    if [ -f "$path" ]; then
        echo -e "${GREEN}✅ $name: $path (文件存在)${NC}"
        ((SUCCESS_COUNT++))
    else
        if [ "$required" == "true" ]; then
            echo -e "${RED}❌ $name: $path (文件不存在)${NC}"
            ((ERROR_COUNT++))
        else
            echo -e "${YELLOW}⚠️  $name: $path (文件不存在)${NC}"
            ((WARNING_COUNT++))
        fi
    fi
}

# 测试网络连接
test_connection() {
    local name=$1
    local host=$2
    local port=$3

    if [ -z "$host" ]; then
        return
    fi

    echo -n "   测试连接 $host:$port ... "
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "${GREEN}成功${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}失败${NC}"
        ((ERROR_COUNT++))
    fi
}

echo "========================================"
echo "📋 第一步：基础配置检查"
echo "========================================"
check_config "短链域名" "$REDIRECT_DOMAIN" "true"
check_config "短链协议" "$REDIRECT_PROTOCOL" "true"
check_config "CDN路由模式" "$CDN_ROUTING_MODE" "true"

echo ""
echo "========================================"
echo "🌐 第二步：CDN配置检查"
echo "========================================"

if [ "$CDN_ROUTING_MODE" == "private" ] || [ "$CDN_ROUTING_MODE" == "auto" ]; then
    check_config "私有CDN域名" "$CDN_PRIVATE_DOMAIN" "true"
    check_config "私有CDN协议" "$CDN_PRIVATE_PROTOCOL" "true"
fi

if [ "$CDN_ROUTING_MODE" == "public" ] || [ "$CDN_ROUTING_MODE" == "auto" ]; then
    check_config "公网CDN域名" "$CDN_PUBLIC_DOMAIN" "true"
    check_config "公网CDN协议" "$CDN_PUBLIC_PROTOCOL" "true"
fi

if [ "$CDN_ROUTING_MODE" == "auto" ]; then
    echo ""
    echo -e "${BLUE}🎯 智能路由模式 - 可选CDN节点:${NC}"
    check_config "北方电信CDN" "$CDN_NORTH_TELECOM_DOMAIN" "false"
    check_config "南方联通CDN" "$CDN_SOUTH_UNICOM_DOMAIN" "false"
    check_config "海外CDN" "$CDN_OVERSEAS_DOMAIN" "false"
fi

echo ""
echo "========================================"
echo "💾 第三步：数据库配置检查"
echo "========================================"
echo -e "${BLUE}Redis配置:${NC}"
check_config "Redis主机" "$REDIS_HOST" "true"
check_config "Redis端口" "$REDIS_PORT" "true"
check_config "Redis密码" "$REDIS_PASSWORD" "false"
check_config "Redis数据库" "$REDIS_DATABASE" "true"
test_connection "Redis" "$REDIS_HOST" "$REDIS_PORT"

echo ""
echo -e "${BLUE}MySQL配置:${NC}"
check_config "MySQL主机" "$MYSQL_HOST" "true"
check_config "MySQL端口" "$MYSQL_PORT" "true"
check_config "MySQL数据库" "$MYSQL_DATABASE" "true"
check_config "MySQL用户" "$MYSQL_USER" "true"
check_config "MySQL密码" "$MYSQL_PASSWORD" "true"
test_connection "MySQL" "$MYSQL_HOST" "$MYSQL_PORT"

echo ""
echo "========================================"
echo "🌍 第四步：GeoIP配置检查"
echo "========================================"
if [ "$CDN_ROUTING_MODE" == "auto" ]; then
    echo -e "${BLUE}GeoIP数据库（auto模式必需）:${NC}"
    check_file "国家数据库" "$GEOIP_COUNTRY_DB" "true"
    check_file "城市数据库" "$GEOIP_CITY_DB" "false"
    check_file "ASN数据库" "$GEOIP_ASN_DB" "false"
else
    echo -e "${YELLOW}⚠️  当前模式($CDN_ROUTING_MODE)不需要GeoIP${NC}"
fi

echo ""
echo "========================================"
echo "🔐 第五步：安全配置检查"
echo "========================================"
check_config "Token密钥" "$DEFAULT_TOKEN_SECRET" "true"

if [ "$DEFAULT_TOKEN_SECRET" == "change-me-in-production-use-strong-random-string" ]; then
    echo -e "${RED}⚠️  警告: 使用默认密钥，生产环境请修改！${NC}"
    ((WARNING_COUNT++))
fi

check_config "Token过期时间" "$TOKEN_EXPIRE" "true"
check_config "访问限流" "$RATE_LIMIT_MAX" "true"

echo ""
echo -e "${BLUE}API KEY配置:${NC}"
check_config "API KEY启用状态" "$API_KEY_ENABLED" "true"

if [ "$API_KEY_ENABLED" == "true" ]; then
    check_config "API KEY" "$API_KEY" "true"

    if [ -z "$API_KEY" ]; then
        echo -e "${RED}⚠️  错误: API_KEY_ENABLED=true 但未配置API_KEY！${NC}"
        ((ERROR_COUNT++))
    else
        # 统计API KEY数量
        IFS=',' read -ra KEYS <<< "$API_KEY"
        key_count=${#KEYS[@]}
        echo -e "   ${GREEN}✓${NC} 已配置 $key_count 个API KEY"

        # 检查每个KEY的长度
        for key in "${KEYS[@]}"; do
            key=$(echo "$key" | xargs)  # 去除空格
            key_length=${#key}
            if [ $key_length -lt 16 ]; then
                echo -e "   ${YELLOW}⚠️  警告: API KEY长度($key_length)过短，建议至少32字符${NC}"
                ((WARNING_COUNT++))
            fi
        done
    fi

    check_config "API限流上限" "$API_RATE_LIMIT_MAX" "true"
    check_config "API限流窗口" "$API_RATE_LIMIT_WINDOW" "true"
else
    echo -e "   ${YELLOW}⚠️  API KEY认证已禁用${NC}"
fi

echo ""
echo -e "${BLUE}管理后台:${NC}"
check_config "后台认证" "$ADMIN_AUTH_ENABLED" "true"
check_config "管理员用户名" "$ADMIN_USERNAME" "true"
check_config "管理员密码" "$ADMIN_PASSWORD" "true"

if [ "$ADMIN_PASSWORD" == "admin123" ]; then
    echo -e "${RED}⚠️  警告: 使用默认密码，生产环境请修改！${NC}"
    ((WARNING_COUNT++))
fi

echo ""
echo "========================================"
echo "⚡ 第六步：性能配置检查"
echo "========================================"
check_config "本地缓存TTL" "$CACHE_LOCAL_TTL" "true"
check_config "Redis缓存TTL" "$CACHE_REDIS_TTL" "true"
check_config "日志级别" "$LOG_LEVEL" "true"

echo ""
echo "========================================"
echo "📊 检查结果汇总"
echo "========================================"
echo -e "${GREEN}✅ 通过: $SUCCESS_COUNT${NC}"
echo -e "${YELLOW}⚠️  警告: $WARNING_COUNT${NC}"
echo -e "${RED}❌ 错误: $ERROR_COUNT${NC}"

echo ""
if [ $ERROR_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 配置验证通过！${NC}"
    echo ""
    echo "建议的下一步操作:"
    echo "  1. 启动服务: docker-compose up -d"
    echo "  2. 查看日志: docker-compose logs -f redirect-service"
    echo "  3. 测试短链: curl http://$REDIRECT_DOMAIN/test"
    exit 0
else
    echo -e "${RED}❌ 配置验证失败，请修复错误后重试${NC}"
    echo ""
    echo "常见问题排查:"
    echo "  1. 检查 .env 文件中的必填项"
    echo "  2. 确保数据库服务正在运行"
    echo "  3. 检查GeoIP数据库文件路径"
    echo "  4. 参考文档: CONFIG_WIZARD.md"
    exit 1
fi
