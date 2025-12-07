# MySQL 测试部署指南

本指南说明如何使用 MySQL 数据库部署和测试 TC-GO 图床系统后端。

## 📋 前置要求

- Docker 和 Docker Compose
- Go 1.24+ (用于本地运行)
- 端口可用: 3307 (MySQL), 6380 (Redis), 8081 (后端)

## 🚀 快速开始

### 方式一: Docker Compose 完整部署

使用 Docker Compose 同时启动 MySQL、Redis 和后端服务：

```powershell
# 启动所有服务
docker-compose -f docker-compose.mysql-test.yml up -d

# 查看日志
docker-compose -f docker-compose.mysql-test.yml logs -f

# 访问测试
# 后端 API: http://localhost:8081
# Swagger 文档: http://localhost:8081/swagger/index.html
```

### 方式二: 本地后端 + Docker 数据库

仅使用 Docker 运行数据库，本地运行后端（便于调试）：

```powershell
# 进入后端目录
cd backend

# 运行测试脚本（会自动配置并启动）
.\test-mysql-local.ps1

# 或手动操作：
# 1. 启动 MySQL 和 Redis
docker-compose -f ../docker-compose.mysql-test.yml up -d mysql redis

# 2. 复制测试配置
cp .env.mysql-test .env

# 3. 运行后端
go run main.go
```

## 📊 服务信息

### Docker Compose 部署

| 服务 | 端口 | 说明 |
|------|------|------|
| MySQL | 3307:3306 | 数据库服务 |
| Redis | 6380:6379 | 缓存服务 |
| Backend | 8081:8080 | 后端 API |

### 本地后端部署

| 服务 | 端口 | 说明 |
|------|------|------|
| MySQL | 3307 | Docker 容器 |
| Redis | 6380 | Docker 容器 |
| Backend | 8080 | 本地进程 |

## 🔐 默认账号

### 应用管理员

- **用户名**: `admin`
- **密码**: `admin123`
- **角色**: 管理员

### MySQL 数据库

- **Root 密码**: `test_root_password_123`
- **数据库名**: `imagebed`
- **用户名**: `imagebed_user`
- **密码**: `test_password_123`

## 🔧 配置说明

测试环境使用的配置文件：
- `.env.mysql-test` - 本地运行配置
- `docker-compose.mysql-test.yml` - Docker 部署配置

主要配置项：

```bash
# 数据库配置
DB_TYPE=mysql
DB_DSN=imagebed_user:test_password_123@tcp(localhost:3307)/imagebed?charset=utf8mb4&parseTime=True&loc=Local

# Redis 配置
REDIS_ENABLED=true
REDIS_ADDR=localhost:6380

# JWT 密钥
JWT_SECRET=test-jwt-secret-key-for-mysql-testing-32chars-minimum-length
```

## 🧪 测试步骤

### 1. 健康检查

```powershell
# 检查后端健康状态
curl http://localhost:8081/api/health

# 或本地部署
curl http://localhost:8080/api/health
```

### 2. 用户登录

```powershell
# 登录获取 Token
curl -X POST http://localhost:8081/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{\"username\":\"admin\",\"password\":\"admin123\"}'
```

### 3. 查看 Swagger 文档

访问 API 文档: http://localhost:8081/swagger/index.html (Docker 部署)
或: http://localhost:8080/swagger/index.html (本地部署)

### 4. 数据库连接测试

```powershell
# 连接到 MySQL 容器
docker exec -it shortimg-mysql-test mysql -u imagebed_user -ptest_password_123

# 在 MySQL 中执行
USE imagebed;
SHOW TABLES;
SELECT * FROM users;
```

### 5. Redis 测试

```powershell
# 连接到 Redis 容器
docker exec -it shortimg-redis-test redis-cli

# 在 Redis 中执行
PING
KEYS *
```

## 📝 日志查看

### Docker 部署

```powershell
# 查看所有服务日志
docker-compose -f docker-compose.mysql-test.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.mysql-test.yml logs -f backend
docker-compose -f docker-compose.mysql-test.yml logs -f mysql
docker-compose -f docker-compose.mysql-test.yml logs -f redis
```

### 本地部署

```powershell
# 后端日志在终端输出
# 也可查看日志文件
Get-Content .\logs\app.log -Tail 50 -Wait

# MySQL 日志
docker logs shortimg-mysql-test -f

# Redis 日志
docker logs shortimg-redis-test -f
```

## 🛠️ 常用命令

### 容器管理

```powershell
# 启动服务
docker-compose -f docker-compose.mysql-test.yml up -d

# 停止服务
docker-compose -f docker-compose.mysql-test.yml down

# 重启服务
docker-compose -f docker-compose.mysql-test.yml restart

# 查看状态
docker-compose -f docker-compose.mysql-test.yml ps
```

### 数据管理

```powershell
# 备份 MySQL 数据
docker exec shortimg-mysql-test mysqldump -u root -ptest_root_password_123 imagebed > backup.sql

# 恢复 MySQL 数据
docker exec -i shortimg-mysql-test mysql -u root -ptest_root_password_123 imagebed < backup.sql

# 清理所有数据（包括 volumes）
docker-compose -f docker-compose.mysql-test.yml down -v
```

### 进入容器

```powershell
# 进入 MySQL 容器
docker exec -it shortimg-mysql-test bash

# 进入 Redis 容器
docker exec -it shortimg-redis-test sh

# 进入后端容器（仅 Docker 部署）
docker exec -it shortimg-backend-test sh
```

## 🐛 故障排查

### MySQL 连接失败

1. 检查容器是否运行：
```powershell
docker ps | findstr mysql
```

2. 查看 MySQL 日志：
```powershell
docker logs shortimg-mysql-test
```

3. 验证连接参数：
```powershell
docker exec -it shortimg-mysql-test mysql -u imagebed_user -ptest_password_123 -e "SELECT 1"
```

### Redis 连接失败

1. 检查 Redis 容器：
```powershell
docker ps | findstr redis
```

2. 测试连接：
```powershell
docker exec -it shortimg-redis-test redis-cli ping
```

### 后端启动失败

1. 查看后端日志：
```powershell
docker logs shortimg-backend-test
# 或本地运行时的终端输出
```

2. 检查配置文件：
```powershell
cat .env
```

3. 验证端口占用：
```powershell
netstat -ano | findstr :8080
netstat -ano | findstr :8081
```

## 🔄 从 SQLite 迁移数据

如果您之前使用 SQLite，可以迁移数据到 MySQL：

```powershell
# 1. 导出 SQLite 数据（使用工具如 sqlite3 或 DB Browser）
# 2. 启动 MySQL 测试环境
docker-compose -f docker-compose.mysql-test.yml up -d mysql

# 3. 使用迁移工具或手动导入数据
# 注意：需要调整 SQL 语法差异（如自增ID、数据类型等）
```

## 📈 性能测试

```powershell
# 使用 Apache Bench 进行简单压测
ab -n 1000 -c 10 http://localhost:8081/api/health

# 或使用其他工具如 wrk, k6 等
```

## 🔒 安全建议

⚠️ **此配置仅用于测试环境，生产环境请注意：**

1. 更改所有默认密码
2. 使用强随机 JWT 密钥
3. 配置防火墙规则
4. 启用 HTTPS
5. 定期备份数据
6. 使用持久化 volumes
7. 配置日志轮转
8. 监控系统资源

## 🧹 清理环境

```powershell
# 停止并删除容器
docker-compose -f docker-compose.mysql-test.yml down

# 删除 volumes（会清除所有数据）
docker-compose -f docker-compose.mysql-test.yml down -v

# 删除镜像
docker rmi mysql:8.0 redis:7-alpine

# 清理本地文件
rm .env
rm -r uploads
rm -r logs
```

## 📚 相关文档

- [后端部署文档](./backend/PRODUCTION_FEATURES.md)
- [Docker 部署指南](./deploy/README.md)
- [性能优化文档](./docs/性能优化与监控.md)
- [监控配置](./docs/monitoring.md)

## 💡 提示

- 本地开发建议使用**方式二**（本地后端 + Docker 数据库），便于调试
- 集成测试建议使用**方式一**（完整 Docker 部署），模拟生产环境
- 测试完成后记得清理环境，避免占用资源
- 可以同时运行多套测试环境（修改端口映射）

## 🆘 获取帮助

如遇问题，请查看：
1. 容器日志
2. 应用日志文件
3. 配置文件语法
4. 网络连接状态
5. 端口占用情况

---

最后更新: 2025-12-07
