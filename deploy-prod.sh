#!/bin/bash

# ==========================================
# ShortImg-AI 生产环境快速部署脚本
# ==========================================
# 使用方法: bash deploy.sh
# ==========================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ShortImg-AI 生产环境部署脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
   echo -e "${RED}请使用 root 用户运行此脚本${NC}"
   exit 1
fi

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker 未安装,请先安装 Docker${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose 未安装,请先安装 Docker Compose${NC}"
    exit 1
fi

# 生成随机密钥
generate_key() {
    openssl rand -hex 32
}

generate_password() {
    openssl rand -base64 24 | tr -d "=+/" | cut -c1-24
}

echo -e "${YELLOW}开始生成密钥...${NC}"

# 生成共享API密钥
SHARED_API_KEY=$(generate_key)
echo -e "${GREEN}✓ 共享API密钥: $SHARED_API_KEY${NC}"

# 生成其他密钥
JWT_SECRET=$(generate_key)
BACKEND_MYSQL_PASSWORD=$(generate_password)
REDIRECT_MYSQL_PASSWORD=$(generate_password)
ADMIN_PASSWORD=$(generate_password)

echo -e "${GREEN}✓ JWT密钥: $JWT_SECRET${NC}"
echo -e "${GREEN}✓ 图床MySQL密码: $BACKEND_MYSQL_PASSWORD${NC}"
echo -e "${GREEN}✓ 短链MySQL密码: $REDIRECT_MYSQL_PASSWORD${NC}"
echo -e "${GREEN}✓ 管理员密码: $ADMIN_PASSWORD${NC}"

# 获取用户输入
echo ""
echo -e "${YELLOW}请输入配置信息:${NC}"

read -p "图床域名 (如 img.yourdomain.com): " IMG_DOMAIN
read -p "短链域名 (如 s.yourdomain.com): " SHORT_DOMAIN
read -p "服务器IP地址 (默认 192.168.9.5): " SERVER_IP
SERVER_IP=${SERVER_IP:-192.168.9.5}

# 创建目录结构
echo ""
echo -e "${YELLOW}创建目录结构...${NC}"

BASE_DIR="/root/docker/shortimg-ai"

mkdir -p $BASE_DIR/backend/{uploads,logs,mysql/data,mysql/conf,mysql/logs}
mkdir -p $BASE_DIR/redirect-service/{logs,mysql/data,mysql/conf,mysql/logs,redis,geoip,ssl}

echo -e "${GREEN}✓ 目录创建完成${NC}"

# 配置图床后端
echo ""
echo -e "${YELLOW}配置图床后端...${NC}"

cd $BASE_DIR/backend

# 创建 .env 文件
cat > .env <<EOF
# 自动生成的生产环境配置
# 生成时间: $(date)

# MySQL 配置
MYSQL_ROOT_PASSWORD=$BACKEND_MYSQL_PASSWORD
MYSQL_DATABASE=imagebed
MYSQL_USER=imagebed_user
MYSQL_PASSWORD=$BACKEND_MYSQL_PASSWORD
MYSQL_PORT=3306

# Redis 配置
REDIS_PASSWORD=
REDIS_PORT=6379

# 服务器配置
BACKEND_PORT=8080

# JWT 配置
JWT_SECRET=$JWT_SECRET

# 用户管理
ALLOW_REGISTRATION=false
DEFAULT_ADMIN_USERNAME=admin
DEFAULT_ADMIN_PASSWORD=$ADMIN_PASSWORD
DEFAULT_ADMIN_EMAIL=admin@$IMG_DOMAIN

# 文件上传
MAX_FILE_SIZE=100

# 存储配置
STORAGE_TYPE=local
STORAGE_BASE_URL=/api/files

# 短链服务配置 (重要!)
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://$SERVER_IP:8081
SHORT_LINK_PUBLIC_URL=https://$SHORT_DOMAIN
SHORT_LINK_API_KEY=$SHARED_API_KEY
SHORT_LINK_EXPIRE=0

# CORS 配置
CORS_ALLOW_ORIGINS=https://$IMG_DOMAIN,https://www.$IMG_DOMAIN
EOF

echo -e "${GREEN}✓ 图床后端配置完成${NC}"

# 配置短链服务
echo ""
echo -e "${YELLOW}配置短链服务...${NC}"

cd $BASE_DIR/redirect-service

# 创建 .env 文件
cat > .env <<EOF
# 自动生成的生产环境配置
# 生成时间: $(date)

# MySQL 配置
MYSQL_ROOT_PASSWORD=$REDIRECT_MYSQL_PASSWORD
MYSQL_DATABASE=short_links
MYSQL_USER=short_link
MYSQL_PASSWORD=$REDIRECT_MYSQL_PASSWORD
MYSQL_EXTERNAL_PORT=3307

# Redis 配置
REDIS_HOST=shortlink-redis-prod
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=1
REDIS_EXTERNAL_PORT=6380

# 短链服务配置
REDIRECT_PORT=8081
REDIRECT_SSL_PORT=8444
REDIRECT_DOMAIN=$SHORT_DOMAIN
REDIRECT_PROTOCOL=https

# 图床服务配置
TC_GO_PRIMARY_DOMAIN=$IMG_DOMAIN
TC_GO_PRIMARY_PROTOCOL=https
TC_GO_BACKUP_DOMAIN=
TC_GO_BACKUP_PROTOCOL=https

# CDN 配置
CDN_ROUTING_MODE=direct
CDN_PRIVATE_DOMAIN=localhost
CDN_PRIVATE_PROTOCOL=http
CDN_PRIVATE_PORT=
CDN_PUBLIC_DOMAIN=$IMG_DOMAIN
CDN_PUBLIC_PROTOCOL=https
CDN_PUBLIC_PORT=
CDN_FALLBACK_DOMAIN=$IMG_DOMAIN
CDN_FALLBACK_PROTOCOL=https

# 缓存配置
CACHE_LOCAL_TTL=300
CACHE_TTL=3600

# 性能配置
RATE_LIMIT=100
RATE_LIMIT_WINDOW=60

# 日志配置
LOG_LEVEL=info

# API密钥配置 (与图床后端一致)
DASHBOARD_API_KEY=$SHARED_API_KEY
API_KEY=

# 管理员配置
ADMIN_AUTH_ENABLED=true
ADMIN_USERNAME=admin
ADMIN_PASSWORD=$ADMIN_PASSWORD

# 监控配置
ENABLE_METRICS=true
METRICS_PORT=9145

# GeoIP 配置
ENABLE_GEOIP=false
GEOIP_CITY_DB=/usr/local/openresty/nginx/geoip/GeoLite2-City.mmdb
GEOIP_ASN_DB=/usr/local/openresty/nginx/geoip/GeoLite2-ASN.mmdb
EOF

echo -e "${GREEN}✓ 短链服务配置完成${NC}"

# 保存密钥到文件
echo ""
echo -e "${YELLOW}保存密钥信息...${NC}"

cat > $BASE_DIR/CREDENTIALS.txt <<EOF
==========================================
ShortImg-AI 生产环境凭证
生成时间: $(date)
==========================================

服务器信息:
- IP地址: $SERVER_IP
- 图床域名: https://$IMG_DOMAIN
- 短链域名: https://$SHORT_DOMAIN

管理员账户:
- 用户名: admin
- 密码: $ADMIN_PASSWORD

API密钥 (图床和短链共享):
$SHARED_API_KEY

JWT密钥:
$JWT_SECRET

数据库凭证:
- 图床MySQL密码: $BACKEND_MYSQL_PASSWORD
- 短链MySQL密码: $REDIRECT_MYSQL_PASSWORD

端口映射:
- 图床后端: 8080
- 短链服务: 8081
- 图床MySQL: 3306
- 短链MySQL: 3307
- 图床Redis: 6379
- 短链Redis: 6380

==========================================
⚠️ 重要: 请妥善保管此文件,不要泄露!
==========================================
EOF

chmod 600 $BASE_DIR/CREDENTIALS.txt

echo -e "${GREEN}✓ 凭证已保存到: $BASE_DIR/CREDENTIALS.txt${NC}"

# 启动服务
echo ""
echo -e "${YELLOW}是否立即启动服务? (y/n)${NC}"
read -p "> " START_NOW

if [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
    echo ""
    echo -e "${YELLOW}启动图床后端服务...${NC}"
    cd $BASE_DIR/backend
    docker-compose -f docker-compose.prod.yml up -d

    echo ""
    echo -e "${YELLOW}等待图床服务启动 (30秒)...${NC}"
    sleep 30

    echo ""
    echo -e "${YELLOW}启动短链服务...${NC}"
    cd $BASE_DIR/redirect-service
    docker-compose -f docker-compose.prod.yml up -d

    echo ""
    echo -e "${YELLOW}等待短链服务启动 (30秒)...${NC}"
    sleep 30

    # 初始化Redis API Key
    echo ""
    echo -e "${YELLOW}初始化Redis API密钥...${NC}"
    docker exec shortlink-redis-prod redis-cli SET "api_key:$SHARED_API_KEY" '{"name":"backend","status":"active","created_at":"'$(date +%Y-%m-%d)'","permissions":["read","write"]}' > /dev/null 2>&1

    echo -e "${GREEN}✓ API密钥已初始化${NC}"

    # 健康检查
    echo ""
    echo -e "${YELLOW}执行健康检查...${NC}"

    sleep 5

    BACKEND_HEALTH=$(curl -s http://localhost:8080/health | grep -o "ok" || echo "failed")
    REDIRECT_HEALTH=$(curl -s http://localhost:8081/health | grep -o "ok" || echo "failed")

    echo ""
    if [ "$BACKEND_HEALTH" = "ok" ]; then
        echo -e "${GREEN}✓ 图床后端服务: 健康${NC}"
    else
        echo -e "${RED}✗ 图床后端服务: 异常${NC}"
    fi

    if [ "$REDIRECT_HEALTH" = "ok" ]; then
        echo -e "${GREEN}✓ 短链服务: 健康${NC}"
    else
        echo -e "${RED}✗ 短链服务: 异常${NC}"
    fi
fi

# 输出摘要
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}部署完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}下一步操作:${NC}"
echo ""
echo "1. 配置Nginx反向代理 (如果需要):"
echo "   - 图床: https://$IMG_DOMAIN -> http://localhost:8080"
echo "   - 短链: https://$SHORT_DOMAIN -> http://localhost:8081"
echo ""
echo "2. 配置SSL证书:"
echo "   certbot certonly --nginx -d $IMG_DOMAIN -d $SHORT_DOMAIN"
echo ""
echo "3. 查看服务状态:"
echo "   cd $BASE_DIR/backend && docker-compose -f docker-compose.prod.yml ps"
echo "   cd $BASE_DIR/redirect-service && docker-compose -f docker-compose.prod.yml ps"
echo ""
echo "4. 查看日志:"
echo "   docker logs -f shortimg-backend-prod"
echo "   docker logs -f shortlink-openresty-prod"
echo ""
echo "5. 访问管理后台:"
echo "   https://$SHORT_DOMAIN/dashboard/"
echo "   用户名: admin"
echo "   密码: (查看 $BASE_DIR/CREDENTIALS.txt)"
echo ""
echo -e "${YELLOW}重要文件:${NC}"
echo "- 凭证信息: $BASE_DIR/CREDENTIALS.txt"
echo "- 图床配置: $BASE_DIR/backend/.env"
echo "- 短链配置: $BASE_DIR/redirect-service/.env"
echo ""
echo -e "${RED}⚠️ 请立即修改默认密码并备份CREDENTIALS.txt文件!${NC}"
echo ""
