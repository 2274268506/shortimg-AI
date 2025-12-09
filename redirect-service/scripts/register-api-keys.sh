#!/bin/bash
# 自动注册 API Keys 到 Redis

# 从环境变量读取配置
API_KEY_ENABLED=${API_KEY_ENABLED:-false}
API_KEY=${API_KEY:-}

if [ "$API_KEY_ENABLED" != "true" ]; then
    echo "API Key 认证未启用，跳过注册"
    exit 0
fi

if [ -z "$API_KEY" ]; then
    echo "未配置 API_KEY 环境变量，跳过注册"
    exit 0
fi

# Redis 连接配置
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}

# 等待 Redis 启动
echo "等待 Redis 服务启动..."
for i in {1..30}; do
    if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping > /dev/null 2>&1; then
        echo "Redis 服务已就绪"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Redis 服务启动超时"
        exit 1
    fi
    sleep 1
done

# 注册每个 API Key
echo "开始注册 API Keys..."
IFS=',' read -ra KEYS <<< "$API_KEY"
CURRENT_TIME=$(date +%s)

for key in "${KEYS[@]}"; do
    # 去除空格
    key=$(echo "$key" | xargs)
    
    if [ -n "$key" ]; then
        # 检查是否已存在
        EXISTS=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" EXISTS "api_key:$key")
        
        if [ "$EXISTS" -eq 1 ]; then
            echo "API Key 已存在，跳过: ${key:0:8}***"
        else
            # 创建 JSON 数据
            JSON_DATA=$(cat <<EOF
{
  "name": "auto-registered-key",
  "status": "active",
  "expires_at": 0,
  "created_at": $CURRENT_TIME
}
EOF
)
            
            # 注册到 Redis（永久存储）
            redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SET "api_key:$key" "$JSON_DATA"
            
            echo "✓ API Key 注册成功: ${key:0:8}***"
        fi
    fi
done

echo "API Keys 注册完成"
