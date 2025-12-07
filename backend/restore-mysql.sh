#!/bin/bash

# ==========================================
# MySQL 数据库恢复脚本
# ==========================================

set -e

# 配置
BACKUP_DIR="/root/docker/shortimg-ai/backups/mysql"
CONTAINER="shortimg-mysql-prod"

# 加载环境变量
if [ -f "$(dirname $0)/.env" ]; then
    source $(dirname $0)/.env
else
    echo "❌ .env 文件不存在"
    exit 1
fi

# 检查容器是否运行
if ! docker ps | grep -q $CONTAINER; then
    echo "❌ MySQL 容器未运行"
    exit 1
fi

# 列出可用的备份文件
echo "📋 可用的备份文件："
echo ""
ls -lh $BACKUP_DIR/*.sql.gz | awk '{print NR")", $9, "("$5")"}'
echo ""

# 选择备份文件
read -p "请输入要恢复的备份文件编号: " FILE_NUM

BACKUP_FILE=$(ls $BACKUP_DIR/*.sql.gz | sed -n "${FILE_NUM}p")

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ 无效的备份文件编号"
    exit 1
fi

echo ""
echo "⚠️  警告：此操作将覆盖当前数据库！"
echo "备份文件: $BACKUP_FILE"
echo ""
read -p "确认恢复? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ 已取消恢复操作"
    exit 0
fi

echo ""
echo "开始恢复数据库..."

# 解压并恢复
gunzip -c $BACKUP_FILE | docker exec -i $CONTAINER mysql \
    -uroot \
    -p${MYSQL_ROOT_PASSWORD} \
    ${MYSQL_DATABASE}

if [ $? -eq 0 ]; then
    echo "✅ 数据库恢复完成"
else
    echo "❌ 数据库恢复失败"
    exit 1
fi
