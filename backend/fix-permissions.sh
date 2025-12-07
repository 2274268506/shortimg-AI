#!/bin/bash

# ==========================================
# 修复数据目录权限脚本
# ==========================================

set -e

echo "🔧 修复 ShortImg-AI 数据目录权限..."

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DATA_ROOT="/root/docker/shortimg-ai"

# 检查目录是否存在
if [ ! -d "$DATA_ROOT" ]; then
    echo -e "${YELLOW}⚠️  数据目录不存在，正在创建...${NC}"
    mkdir -p $DATA_ROOT/{mysql/{data,conf,logs},redis/data,backend/{uploads,logs,data,config}}
fi

echo "📁 设置目录权限..."

# MySQL 目录权限（MySQL 容器使用 mysql 用户，UID 通常是 999）
echo "  • MySQL 数据目录..."
chown -R 999:999 $DATA_ROOT/mysql/data 2>/dev/null || true
chmod -R 755 $DATA_ROOT/mysql/data

echo "  • MySQL 日志目录..."
chown -R 999:999 $DATA_ROOT/mysql/logs 2>/dev/null || true
chmod -R 755 $DATA_ROOT/mysql/logs

# Redis 目录权限（Redis 容器使用 redis 用户，UID 通常是 999）
echo "  • Redis 数据目录..."
chown -R 999:999 $DATA_ROOT/redis/data 2>/dev/null || true
chmod -R 755 $DATA_ROOT/redis/data

# Backend 目录权限（使用 UID 1000，与 Dockerfile 中定义的 appuser 一致）
echo "  • Backend 上传目录..."
chown -R 1000:1000 $DATA_ROOT/backend/uploads
chmod -R 755 $DATA_ROOT/backend/uploads

echo "  • Backend 日志目录..."
chown -R 1000:1000 $DATA_ROOT/backend/logs
chmod -R 755 $DATA_ROOT/backend/logs

echo "  • Backend 数据目录..."
chown -R 1000:1000 $DATA_ROOT/backend/data
chmod -R 755 $DATA_ROOT/backend/data

echo "  • Backend 配置目录..."
if [ -d "$DATA_ROOT/backend/config" ]; then
    chown -R 1000:1000 $DATA_ROOT/backend/config
    chmod -R 755 $DATA_ROOT/backend/config
fi

# 备份目录权限
if [ -d "$DATA_ROOT/backups" ]; then
    echo "  • 备份目录..."
    chmod -R 755 $DATA_ROOT/backups
fi

echo ""
echo -e "${GREEN}✅ 权限修复完成！${NC}"
echo ""
echo "📊 目录权限概览："
ls -la $DATA_ROOT/
echo ""
ls -la $DATA_ROOT/backend/
echo ""

echo "💡 提示："
echo "  如果容器仍有权限问题，请尝试："
echo "  1. 停止所有容器: docker-compose -f docker-compose.prod.yml down"
echo "  2. 重新运行此脚本: sudo ./fix-permissions.sh"
echo "  3. 启动容器: docker-compose -f docker-compose.prod.yml up -d"
