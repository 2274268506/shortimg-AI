#!/bin/bash

# ==========================================
# MySQL 数据库备份脚本
# ==========================================

set -e

# 配置
BACKUP_DIR="/root/docker/shortimg-ai/backups/mysql"
CONTAINER="shortimg-mysql-prod"
DATE=$(date +%Y%m%d_%H%M%S)
KEEP_DAYS=30

# 加载环境变量
if [ -f "$(dirname $0)/.env" ]; then
    source $(dirname $0)/.env
else
    echo "❌ .env 文件不存在"
    exit 1
fi

# 创建备份目录
mkdir -p $BACKUP_DIR

echo "开始备份 MySQL 数据库..."

# 检查容器是否运行
if ! docker ps | grep -q $CONTAINER; then
    echo "❌ MySQL 容器未运行"
    exit 1
fi

# 备份数据库
docker exec $CONTAINER mysqldump \
    -uroot \
    -p${MYSQL_ROOT_PASSWORD} \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    ${MYSQL_DATABASE} > $BACKUP_DIR/${MYSQL_DATABASE}_$DATE.sql

# 检查备份是否成功
if [ $? -eq 0 ]; then
    # 压缩备份文件
    gzip $BACKUP_DIR/${MYSQL_DATABASE}_$DATE.sql
    
    # 计算文件大小
    SIZE=$(du -h $BACKUP_DIR/${MYSQL_DATABASE}_$DATE.sql.gz | cut -f1)
    
    echo "✅ 数据库备份完成"
    echo "   文件: ${MYSQL_DATABASE}_$DATE.sql.gz"
    echo "   大小: $SIZE"
    echo "   路径: $BACKUP_DIR"
    
    # 删除旧备份
    find $BACKUP_DIR -name "*.sql.gz" -mtime +$KEEP_DAYS -delete
    echo "   已删除 ${KEEP_DAYS} 天前的备份文件"
else
    echo "❌ 数据库备份失败"
    exit 1
fi
