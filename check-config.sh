#!/bin/bash

# ==========================================
# ShortImg-AI 配置检查脚本
# ==========================================
# 用于验证 API 密钥是否一致
# ==========================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ShortImg-AI 配置检查${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

BASE_DIR="/root/docker/shortimg-AI"

# 检查目录是否存在
if [ ! -d "$BASE_DIR/backend" ]; then
    echo -e "${RED}✗ 图床后端目录不存在: $BASE_DIR/backend${NC}"
    exit 1
fi

if [ ! -d "$BASE_DIR/redirect-service" ]; then
    echo -e "${RED}✗ 短链服务目录不存在: $BASE_DIR/redirect-service${NC}"
    exit 1
fi

# 检查配置文件
echo -e "${YELLOW}检查配置文件...${NC}"

if [ ! -f "$BASE_DIR/backend/.env" ]; then
    echo -e "${RED}✗ 图床后端 .env 文件不存在${NC}"
    echo -e "${YELLOW}  提示: cp $BASE_DIR/backend/.env.prod $BASE_DIR/backend/.env${NC}"
    exit 1
else
    echo -e "${GREEN}✓ 图床后端 .env 文件存在${NC}"
fi

if [ ! -f "$BASE_DIR/redirect-service/.env" ]; then
    echo -e "${RED}✗ 短链服务 .env 文件不存在${NC}"
    echo -e "${YELLOW}  提示: cp $BASE_DIR/redirect-service/.env.prod $BASE_DIR/redirect-service/.env${NC}"
    exit 1
else
    echo -e "${GREEN}✓ 短链服务 .env 文件存在${NC}"
fi

echo ""

# 提取 API 密钥
echo -e "${YELLOW}检查 API 密钥一致性...${NC}"

BACKEND_API_KEY=$(grep "^SHORT_LINK_API_KEY=" $BASE_DIR/backend/.env | cut -d'=' -f2)
REDIRECT_API_KEY=$(grep "^DASHBOARD_API_KEY=" $BASE_DIR/redirect-service/.env | cut -d'=' -f2)

if [ -z "$BACKEND_API_KEY" ]; then
    echo -e "${RED}✗ 图床后端未配置 SHORT_LINK_API_KEY${NC}"
    exit 1
fi

if [ -z "$REDIRECT_API_KEY" ]; then
    echo -e "${RED}✗ 短链服务未配置 DASHBOARD_API_KEY${NC}"
    exit 1
fi

echo -e "${BLUE}图床后端 SHORT_LINK_API_KEY:${NC}"
echo "  $BACKEND_API_KEY"
echo ""
echo -e "${BLUE}短链服务 DASHBOARD_API_KEY:${NC}"
echo "  $REDIRECT_API_KEY"
echo ""

if [ "$BACKEND_API_KEY" = "$REDIRECT_API_KEY" ]; then
    echo -e "${GREEN}✓ API 密钥一致!${NC}"
else
    echo -e "${RED}✗ API 密钥不一致!${NC}"
    echo -e "${YELLOW}  请确保以下两个配置完全一致:${NC}"
    echo -e "${YELLOW}  - $BASE_DIR/backend/.env 的 SHORT_LINK_API_KEY${NC}"
    echo -e "${YELLOW}  - $BASE_DIR/redirect-service/.env 的 DASHBOARD_API_KEY${NC}"
    exit 1
fi

echo ""

# 检查其他关键配置
echo -e "${YELLOW}检查其他配置...${NC}"

# 图床配置
BACKEND_SHORT_LINK_ENABLED=$(grep "^SHORT_LINK_ENABLED=" $BASE_DIR/backend/.env | cut -d'=' -f2)
BACKEND_SHORT_LINK_BASE_URL=$(grep "^SHORT_LINK_BASE_URL=" $BASE_DIR/backend/.env | cut -d'=' -f2)
BACKEND_SHORT_LINK_PUBLIC_URL=$(grep "^SHORT_LINK_PUBLIC_URL=" $BASE_DIR/backend/.env | cut -d'=' -f2)

# 短链配置
REDIRECT_DOMAIN=$(grep "^REDIRECT_DOMAIN=" $BASE_DIR/redirect-service/.env | cut -d'=' -f2)
REDIRECT_PROTOCOL=$(grep "^REDIRECT_PROTOCOL=" $BASE_DIR/redirect-service/.env | cut -d'=' -f2)

echo ""
echo -e "${BLUE}图床后端配置:${NC}"
echo "  SHORT_LINK_ENABLED: $BACKEND_SHORT_LINK_ENABLED"
echo "  SHORT_LINK_BASE_URL: $BACKEND_SHORT_LINK_BASE_URL"
echo "  SHORT_LINK_PUBLIC_URL: $BACKEND_SHORT_LINK_PUBLIC_URL"

echo ""
echo -e "${BLUE}短链服务配置:${NC}"
echo "  REDIRECT_DOMAIN: $REDIRECT_DOMAIN"
echo "  REDIRECT_PROTOCOL: $REDIRECT_PROTOCOL"

echo ""

# 验证配置合理性
WARNINGS=0

if [ "$BACKEND_SHORT_LINK_ENABLED" != "true" ]; then
    echo -e "${YELLOW}⚠ 图床后端未启用短链功能${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if [[ "$BACKEND_SHORT_LINK_BASE_URL" == *"your-domain.com"* ]] || [[ "$BACKEND_SHORT_LINK_BASE_URL" == *"yourdomain.com"* ]]; then
    echo -e "${YELLOW}⚠ SHORT_LINK_BASE_URL 包含默认域名,请修改为实际地址${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if [[ "$BACKEND_SHORT_LINK_PUBLIC_URL" == *"your-domain.com"* ]] || [[ "$BACKEND_SHORT_LINK_PUBLIC_URL" == *"yourdomain.com"* ]]; then
    echo -e "${YELLOW}⚠ SHORT_LINK_PUBLIC_URL 包含默认域名,请修改为实际地址${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if [[ "$REDIRECT_DOMAIN" == *"your-domain.com"* ]] || [[ "$REDIRECT_DOMAIN" == *"yourdomain.com"* ]]; then
    echo -e "${YELLOW}⚠ REDIRECT_DOMAIN 包含默认域名,请修改为实际域名${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 检查Docker服务
echo ""
echo -e "${YELLOW}检查 Docker 服务状态...${NC}"

if docker ps | grep -q "shortimg-backend-prod"; then
    echo -e "${GREEN}✓ 图床后端容器运行中${NC}"

    # 检查健康状态
    HEALTH=$(docker inspect shortimg-backend-prod --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    if [ "$HEALTH" = "healthy" ]; then
        echo -e "${GREEN}  健康状态: healthy${NC}"
    elif [ "$HEALTH" = "unknown" ]; then
        echo -e "${YELLOW}  健康状态: 未配置健康检查${NC}"
    else
        echo -e "${RED}  健康状态: $HEALTH${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 图床后端容器未运行${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if docker ps | grep -q "shortlink-openresty-prod"; then
    echo -e "${GREEN}✓ 短链服务容器运行中${NC}"

    # 检查健康状态
    HEALTH=$(docker inspect shortlink-openresty-prod --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    if [ "$HEALTH" = "healthy" ]; then
        echo -e "${GREEN}  健康状态: healthy${NC}"
    elif [ "$HEALTH" = "unknown" ]; then
        echo -e "${YELLOW}  健康状态: 未配置健康检查${NC}"
    else
        echo -e "${RED}  健康状态: $HEALTH${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 短链服务容器未运行${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 检查Redis中的API Key
echo ""
echo -e "${YELLOW}检查 Redis 中的 API 密钥...${NC}"

if docker ps | grep -q "shortlink-redis-prod"; then
    REDIS_KEY=$(docker exec shortlink-redis-prod redis-cli GET "api_key:$REDIRECT_API_KEY" 2>/dev/null || echo "")

    if [ -z "$REDIS_KEY" ]; then
        echo -e "${RED}✗ Redis 中未找到 API 密钥${NC}"
        echo -e "${YELLOW}  请执行以下命令初始化:${NC}"
        echo -e "${BLUE}  docker exec -it shortlink-redis-prod redis-cli${NC}"
        echo -e "${BLUE}  SET api_key:$REDIRECT_API_KEY '{\"name\":\"backend\",\"status\":\"active\",\"created_at\":\"$(date +%Y-%m-%d)\",\"permissions\":[\"read\",\"write\"]}'${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}✓ Redis 中存在 API 密钥${NC}"
        echo "  $REDIS_KEY"
    fi
else
    echo -e "${YELLOW}⚠ Redis 容器未运行,无法检查${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 总结
echo ""
echo -e "${BLUE}========================================${NC}"
if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ 配置检查通过!${NC}"
    echo -e "${GREEN}  所有配置正确,服务可以正常运行${NC}"
else
    echo -e "${YELLOW}⚠ 发现 $WARNINGS 个警告${NC}"
    echo -e "${YELLOW}  请根据上述提示修复问题${NC}"
fi
echo -e "${BLUE}========================================${NC}"
echo ""

# 提供测试命令
if [ $WARNINGS -eq 0 ]; then
    echo -e "${YELLOW}测试命令:${NC}"
    echo ""
    echo "1. 测试图床后端健康检查:"
    echo "   curl http://localhost:8080/health"
    echo ""
    echo "2. 测试短链服务健康检查:"
    echo "   curl http://localhost:8081/health"
    echo ""
    echo "3. 测试短链API (需要API密钥):"
    echo "   curl -H \"X-API-Key: $REDIRECT_API_KEY\" http://localhost:8081/api/v2/imagebed"
    echo ""
    echo "4. 查看服务日志:"
    echo "   docker logs -f shortimg-backend-prod"
    echo "   docker logs -f shortlink-openresty-prod"
    echo ""
fi

exit $WARNINGS
