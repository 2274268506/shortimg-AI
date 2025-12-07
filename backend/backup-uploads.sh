#!/bin/bash

# ==========================================
# 上传文件备份脚本
# ==========================================

set -e

# 配置
BACKUP_DIR="/root/docker/shortimg-ai/backups/uploads"
SOURCE_DIR="/root/docker/shortimg-ai/backend/uploads"
DATE=$(date +%Y%m%d_%H%M%S)
KEEP_DAYS=30

echo "开始备份上传文件..."

# 创建备份目录
mkdir -p $BACKUP_DIR/latest

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ 源目录不存在: $SOURCE_DIR"
    exit 1
fi

# 使用 rsync 增量备份
rsync -av --delete $SOURCE_DIR/ $BACKUP_DIR/latest/

# 创建每日快照（硬链接，节省空间）
if [ -d "$BACKUP_DIR/latest" ]; then
    cp -al $BACKUP_DIR/latest/ $BACKUP_DIR/snapshot_$DATE/
    
    # 计算目录大小
    SIZE=$(du -sh $BACKUP_DIR/snapshot_$DATE | cut -f1)
    
    echo "✅ 文件备份完成"
    echo "   快照: snapshot_$DATE"
    echo "   大小: $SIZE"
    echo "   路径: $BACKUP_DIR"
    
    # 删除旧快照
    find $BACKUP_DIR -name "snapshot_*" -type d -mtime +$KEEP_DAYS -exec rm -rf {} \; 2>/dev/null || true
    echo "   已删除 ${KEEP_DAYS} 天前的快照"
else
    echo "❌ 备份失败"
    exit 1
fi
