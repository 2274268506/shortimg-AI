#!/bin/bash

# ==========================================
# ShortImg-AI Backend 生产环境部署脚本
# ==========================================

set -e

echo "🚀 开始部署 ShortImg-AI Backend 生产环境..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ 请使用 root 用户运行此脚本${NC}"
    exit 1
fi

# 步骤 1: 检查依赖
echo ""
echo "📋 步骤 1/5: 检查系统依赖..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装，请先安装 Docker${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose 未安装，请先安装 Docker Compose${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker 版本: $(docker --version)${NC}"
echo -e "${GREEN}✅ Docker Compose 版本: $(docker-compose --version)${NC}"

# 步骤 2: 创建数据目录
echo ""
echo "📁 步骤 2/5: 创建数据持久化目录..."
DATA_ROOT="/root/docker/shortimg-ai"

mkdir -p $DATA_ROOT/mysql/{data,conf,logs}
mkdir -p $DATA_ROOT/redis/data
mkdir -p $DATA_ROOT/backend/{uploads,logs,data,config}
mkdir -p $DATA_ROOT/backups/{mysql,uploads}

echo -e "${GREEN}✅ 数据目录创建完成: $DATA_ROOT${NC}"

# 步骤 3: 配置环境变量
echo ""
echo "⚙️ 步骤 3/5: 配置环境变量..."
if [ ! -f ".env" ]; then
    if [ -f ".env.prod" ]; then
        cp .env.prod .env
        echo -e "${YELLOW}⚠️  已创建 .env 文件，请编辑并修改以下配置：${NC}"
        echo "   - MYSQL_ROOT_PASSWORD"
        echo "   - MYSQL_PASSWORD"
        echo "   - JWT_SECRET"
        echo "   - CORS_ALLOW_ORIGINS"
        echo "   - SHORT_LINK_BASE_URL"
        echo ""
        read -p "是否现在编辑 .env 文件? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} .env
        else
            echo -e "${YELLOW}⚠️  请手动编辑 .env 文件后再继续部署${NC}"
            exit 0
        fi
    else
        echo -e "${RED}❌ .env.prod 模板文件不存在${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ .env 文件已存在${NC}"
fi

# 步骤 4: 创建 MySQL 配置
echo ""
echo "🗄️ 步骤 4/5: 创建 MySQL 配置文件..."
if [ ! -f "$DATA_ROOT/mysql/conf/my.cnf" ]; then
    cat > $DATA_ROOT/mysql/conf/my.cnf <<EOF
[mysqld]
# 字符集配置
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# 性能优化
max_connections=1000
innodb_buffer_pool_size=2G
innodb_log_file_size=256M
innodb_flush_log_at_trx_commit=2

# 慢查询日志
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow.log
long_query_time=2

# 二进制日志
log_bin=/var/log/mysql/mysql-bin
binlog_format=ROW
expire_logs_days=7

[client]
default-character-set=utf8mb4
EOF
    echo -e "${GREEN}✅ MySQL 配置文件已创建${NC}"
else
    echo -e "${GREEN}✅ MySQL 配置文件已存在${NC}"
fi

# 步骤 5: 启动服务
echo ""
echo "🚀 步骤 5/5: 启动服务..."
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d --build

# 等待服务启动
echo ""
echo "⏳ 等待服务启动..."
sleep 10

# 检查服务状态
echo ""
echo "📊 检查服务状态..."
docker-compose -f docker-compose.prod.yml ps

# 检查健康状态
echo ""
echo "🏥 检查健康状态..."
for i in {1..30}; do
    if curl -f http://localhost:8080/health &> /dev/null; then
        echo -e "${GREEN}✅ 后端服务健康检查通过${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ 后端服务健康检查失败${NC}"
        echo "查看日志: docker-compose -f docker-compose.prod.yml logs backend"
        exit 1
    fi
    sleep 2
done

# 显示访问信息
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 部署成功！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "📝 服务信息："
echo "   - 后端 API: http://localhost:8080"
echo "   - API 文档: http://localhost:8080/swagger/index.html"
echo "   - 健康检查: http://localhost:8080/health"
echo ""
echo "📁 数据目录："
echo "   - 数据根目录: $DATA_ROOT"
echo "   - MySQL 数据: $DATA_ROOT/mysql/data"
echo "   - 上传文件: $DATA_ROOT/backend/uploads"
echo "   - 应用日志: $DATA_ROOT/backend/logs"
echo ""
echo "🔧 常用命令："
echo "   - 查看日志: docker-compose -f docker-compose.prod.yml logs -f"
echo "   - 重启服务: docker-compose -f docker-compose.prod.yml restart"
echo "   - 停止服务: docker-compose -f docker-compose.prod.yml stop"
echo "   - 启动服务: docker-compose -f docker-compose.prod.yml start"
echo ""
echo "📚 更多信息请查看: PRODUCTION_DEPLOY.md"
echo ""
