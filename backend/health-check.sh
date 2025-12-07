#!/bin/bash

# ==========================================
# 服务健康检查脚本
# ==========================================

set -e

echo "🏥 开始健康检查..."
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0

# 检查 Docker 服务
echo "1️⃣ 检查 Docker 服务..."
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✅ Docker 服务运行正常${NC}"
else
    echo -e "${RED}❌ Docker 服务未运行${NC}"
    FAILED=1
fi
echo ""

# 检查容器状态
echo "2️⃣ 检查容器状态..."
CONTAINERS=("shortimg-mysql-prod" "shortimg-redis-prod" "shortimg-backend-prod")

for container in "${CONTAINERS[@]}"; do
    if docker ps | grep -q $container; then
        STATUS=$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null || echo "none")
        if [ "$STATUS" == "healthy" ] || [ "$STATUS" == "none" ]; then
            echo -e "${GREEN}✅ $container 运行正常${NC}"
        else
            echo -e "${YELLOW}⚠️  $container 状态: $STATUS${NC}"
            FAILED=1
        fi
    else
        echo -e "${RED}❌ $container 未运行${NC}"
        FAILED=1
    fi
done
echo ""

# 检查 MySQL 连接
echo "3️⃣ 检查 MySQL 连接..."
if docker exec shortimg-mysql-prod mysqladmin ping -h localhost --silent &>/dev/null; then
    echo -e "${GREEN}✅ MySQL 连接正常${NC}"
    
    # 检查慢查询
    SLOW_QUERIES=$(docker exec shortimg-mysql-prod mysql -uroot -p${MYSQL_ROOT_PASSWORD} -e "SHOW GLOBAL STATUS LIKE 'Slow_queries';" 2>/dev/null | tail -1 | awk '{print $2}')
    if [ ! -z "$SLOW_QUERIES" ]; then
        echo "   慢查询数量: $SLOW_QUERIES"
    fi
else
    echo -e "${RED}❌ MySQL 连接失败${NC}"
    FAILED=1
fi
echo ""

# 检查 Redis 连接
echo "4️⃣ 检查 Redis 连接..."
if docker exec shortimg-redis-prod redis-cli ping &>/dev/null; then
    echo -e "${GREEN}✅ Redis 连接正常${NC}"
    
    # 检查内存使用
    USED_MEMORY=$(docker exec shortimg-redis-prod redis-cli info memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
    if [ ! -z "$USED_MEMORY" ]; then
        echo "   内存使用: $USED_MEMORY"
    fi
else
    echo -e "${RED}❌ Redis 连接失败${NC}"
    FAILED=1
fi
echo ""

# 检查后端 API
echo "5️⃣ 检查后端 API..."
HEALTH_URL="http://localhost:8080/health"
if curl -f -s $HEALTH_URL &>/dev/null; then
    echo -e "${GREEN}✅ 后端 API 正常${NC}"
    RESPONSE=$(curl -s $HEALTH_URL)
    echo "   响应: $RESPONSE"
else
    echo -e "${RED}❌ 后端 API 无响应${NC}"
    FAILED=1
fi
echo ""

# 检查磁盘空间
echo "6️⃣ 检查磁盘空间..."
DISK_USAGE=$(df -h /root/docker/shortimg-ai | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✅ 磁盘空间充足 (已使用 ${DISK_USAGE}%)${NC}"
elif [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "${YELLOW}⚠️  磁盘空间不足 (已使用 ${DISK_USAGE}%)${NC}"
else
    echo -e "${RED}❌ 磁盘空间严重不足 (已使用 ${DISK_USAGE}%)${NC}"
    FAILED=1
fi
echo ""

# 检查内存使用
echo "7️⃣ 检查内存使用..."
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ "$MEMORY_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✅ 内存使用正常 (已使用 ${MEMORY_USAGE}%)${NC}"
elif [ "$MEMORY_USAGE" -lt 90 ]; then
    echo -e "${YELLOW}⚠️  内存使用较高 (已使用 ${MEMORY_USAGE}%)${NC}"
else
    echo -e "${RED}❌ 内存使用过高 (已使用 ${MEMORY_USAGE}%)${NC}"
    FAILED=1
fi
echo ""

# 检查 CPU 负载
echo "8️⃣ 检查 CPU 负载..."
LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
CPU_CORES=$(nproc)
echo "   当前负载: $LOAD (CPU 核心数: $CPU_CORES)"
echo ""

# 总结
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 所有检查通过！系统运行正常${NC}"
    exit 0
else
    echo -e "${RED}⚠️  发现问题，请检查日志${NC}"
    echo ""
    echo "查看日志命令："
    echo "  docker-compose -f docker-compose.prod.yml logs -f"
    exit 1
fi
