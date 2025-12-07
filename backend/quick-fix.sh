#!/bin/bash

# ==========================================
# 快速修复所有问题脚本
# ==========================================

set -e

echo "🔧 ShortImg-AI 快速修复工具"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ 请使用 root 用户运行此脚本${NC}"
    exit 1
fi

DATA_ROOT="/root/docker/shortimg-ai"

# 1. 停止所有服务
echo "1️⃣ 停止所有服务..."
docker-compose -f docker-compose.prod.yml down
echo -e "${GREEN}✅ 服务已停止${NC}"
echo ""

# 2. 修复权限
echo "2️⃣ 修复目录权限..."

# 确保目录存在
mkdir -p $DATA_ROOT/{mysql/{data,conf,logs},redis/data,backend/{uploads,logs,data,config}}

# MySQL 权限
echo "  • MySQL 权限..."
chown -R 999:999 $DATA_ROOT/mysql/data 2>/dev/null || true
chown -R 999:999 $DATA_ROOT/mysql/logs 2>/dev/null || true
chmod -R 755 $DATA_ROOT/mysql/data
chmod -R 755 $DATA_ROOT/mysql/logs

# Redis 权限
echo "  • Redis 权限..."
chown -R 999:999 $DATA_ROOT/redis/data 2>/dev/null || true
chmod -R 755 $DATA_ROOT/redis/data

# Backend 权限
echo "  • Backend 权限..."
chown -R 1000:1000 $DATA_ROOT/backend/uploads
chown -R 1000:1000 $DATA_ROOT/backend/logs
chown -R 1000:1000 $DATA_ROOT/backend/data
chmod -R 755 $DATA_ROOT/backend/uploads
chmod -R 755 $DATA_ROOT/backend/logs
chmod -R 755 $DATA_ROOT/backend/data

if [ -d "$DATA_ROOT/backend/config" ]; then
    chown -R 1000:1000 $DATA_ROOT/backend/config
    chmod -R 755 $DATA_ROOT/backend/config
fi

echo -e "${GREEN}✅ 权限修复完成${NC}"
echo ""

# 3. 重新启动服务
echo "3️⃣ 重新启动服务..."
docker-compose -f docker-compose.prod.yml up -d
echo -e "${GREEN}✅ 服务已启动${NC}"
echo ""

# 4. 等待服务启动
echo "4️⃣ 等待服务启动（30秒）..."
sleep 30
echo ""

# 5. 运行健康检查
echo "5️⃣ 运行健康检查..."
if [ -f "./health-check.sh" ]; then
    chmod +x ./health-check.sh
    ./health-check.sh
else
    # 简单的健康检查
    echo "测试后端健康..."
    if curl -f http://localhost:8080/health &> /dev/null; then
        echo -e "${GREEN}✅ 后端服务正常${NC}"
    else
        echo -e "${RED}❌ 后端服务异常${NC}"
    fi
fi
echo ""

echo "=========================================="
echo -e "${GREEN}🎉 修复完成！${NC}"
echo ""
echo "💡 如果仍有问题，请查看："
echo "   • 详细日志: docker-compose -f docker-compose.prod.yml logs -f"
echo "   • 故障排查: TROUBLESHOOTING.md"
