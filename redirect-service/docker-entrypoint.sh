#!/bin/bash
set -e

# 等待 Redis 服务启动
echo "等待 Redis 服务启动..."
REDIS_HOST=${REDIS_HOST:-127.0.0.1}
REDIS_PORT=${REDIS_PORT:-6379}

for i in {1..30}; do
    if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping > /dev/null 2>&1; then
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

if [ "$API_KEY_ENABLED" = "true" ] && [ -n "$API_KEY" ]; then
    echo "开始注册 API Keys..."
    
    IFS=',' read -ra KEYS <<< "$API_KEY"
    CURRENT_TIME=$(date +%s)
    
    for key in "${KEYS[@]}"; do
        key=$(echo "$key" | xargs)
        
        if [ -n "$key" ]; then
            EXISTS=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" EXISTS "api_key:$key")
            
            if [ "$EXISTS" -eq 1 ]; then
                echo "  - API Key 已存在: ${key:0:8}***"
            else
                JSON_DATA="{\"name\":\"auto-registered-key\",\"status\":\"active\",\"expires_at\":0,\"created_at\":$CURRENT_TIME}"
                redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SET "api_key:$key" "$JSON_DATA" > /dev/null
                echo "  ✓ API Key 注册成功: ${key:0:8}***"
            fi
        fi
    done
    
    echo "API Keys 注册完成"
else
    echo "API Key 认证未启用或未配置，跳过注册"
fi

# 启动 OpenResty
echo "启动 OpenResty..."
exec /usr/local/openresty/bin/openresty -g "daemon off;"
