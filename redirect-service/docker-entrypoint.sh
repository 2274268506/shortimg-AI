#!/bin/bash
set -e

# 等待 Redis 服务启动
echo "等待 Redis 服务启动..."
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_PASSWORD=${REDIS_PASSWORD:-}

# 构造 Redis CLI 命令参数
REDIS_CLI="redis-cli -h $REDIS_HOST -p $REDIS_PORT"
if [ -n "$REDIS_PASSWORD" ]; then
    REDIS_CLI="$REDIS_CLI -a $REDIS_PASSWORD"
fi

for i in {1..30}; do
    if $REDIS_CLI ping > /dev/null 2>&1; then
        echo "✓ Redis 服务已就绪"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ Redis 服务启动超时"
        exit 1
    fi
    sleep 1
done

# 注册 API Keys
API_KEY_ENABLED=${API_KEY_ENABLED:-false}
API_KEY=${API_KEY:-}

# 从后端服务获取API密钥（优先级更高）
IMAGEBED_API_KEY=${IMAGEBED_API_KEY:-}

if [ "$API_KEY_ENABLED" = "true" ] && [ -n "$API_KEY" ]; then
    echo "开始注册 API Keys..."

    IFS=',' read -ra KEYS <<< "$API_KEY"
    CURRENT_TIME=$(date +%s)

    for key in "${KEYS[@]}"; do
        key=$(echo "$key" | xargs)

        if [ -n "$key" ]; then
            EXISTS=$($REDIS_CLI EXISTS "api_key:$key" 2>/dev/null || echo "0")

            if [ "$EXISTS" -eq 1 ]; then
                echo "  - API Key 已存在: ${key:0:8}***"
            else
                JSON_DATA="{\"name\":\"auto-registered-key\",\"status\":\"active\",\"expires_at\":0,\"created_at\":$CURRENT_TIME,\"permissions\":[\"*\"]}"
                echo "$JSON_DATA" | $REDIS_CLI -x SET "api_key:$key" > /dev/null 2>&1
                echo "  ✓ API Key 注册成功: ${key:0:8}***"
            fi
        fi
    done

    echo "API Keys 注册完成"
elif [ -n "$IMAGEBED_API_KEY" ]; then
    echo "注册 Imagebed API Key..."

    key=$(echo "$IMAGEBED_API_KEY" | xargs)
    EXISTS=$($REDIS_CLI EXISTS "api_key:$key" 2>/dev/null || echo "0")

    if [ "$EXISTS" -eq 1 ]; then
        echo "  - API Key 已存在: ${key:0:10}***${key: -5}"
    else
        CURRENT_TIME=$(date +%s)
        JSON_DATA="{\"api_key\":\"$key\",\"name\":\"Imagebed Service\",\"status\":\"active\",\"expires_at\":0,\"created_at\":$CURRENT_TIME,\"permissions\":[\"short_link:read\",\"short_link:write\",\"*\"]}"
        echo "$JSON_DATA" | $REDIS_CLI -x SET "api_key:$key" > /dev/null 2>&1
        echo "  ✓ API Key 注册成功: ${key:0:10}***${key: -5}"
    fi

    echo "Imagebed API Key 注册完成"
else
    echo "API Key 认证未启用或未配置，跳过注册"
fi

# 启动 OpenResty
echo "启动 OpenResty..."
exec /usr/local/openresty/bin/openresty -g "daemon off;"
