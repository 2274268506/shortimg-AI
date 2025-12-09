# 📦 生产环境部署文件说明

## 📁 文件清单

### 配置文件

#### 图床后端 (`backend/`)
- **docker-compose.prod.yml** - 图床后端生产环境Docker Compose配置
- **.env.prod** - 图床后端环境变量模板 (复制为 .env 使用)

#### 短链服务 (`redirect-service/`)
- **docker-compose.prod.yml** - 短链服务生产环境Docker Compose配置
- **.env.prod** - 短链服务环境变量模板 (复制为 .env 使用)

### 脚本工具

- **deploy-prod.sh** - 自动化部署脚本 (生成配置、启动服务)
- **check-config.sh** - 配置检查脚本 (验证API密钥一致性)

### 文档

- **PRODUCTION_DEPLOYMENT_GUIDE.md** - 详细部署指南

---

## 🚀 快速开始

### 方法一: 自动部署 (推荐)

```bash
# 1. 上传项目到服务器
scp -r shortimg-AI root@your-server:/root/

# 2. 登录服务器
ssh root@your-server

# 3. 进入项目目录
cd /root/shortimg-AI

# 4. 添加执行权限
chmod +x deploy-prod.sh check-config.sh

# 5. 运行自动部署脚本
bash deploy-prod.sh

# 按提示输入域名等信息,脚本会自动:
# - 生成强随机密钥
# - 创建目录结构
# - 配置环境变量
# - 启动所有服务
# - 初始化API密钥到Redis
```

### 方法二: 手动部署

#### Step 1: 准备图床后端

```bash
cd /root/shortimg-AI/backend

# 复制配置模板
cp .env.prod .env

# 编辑配置
nano .env

# 修改以下关键配置:
# - MYSQL_PASSWORD (数据库密码)
# - JWT_SECRET (JWT密钥,至少32字符)
# - SHORT_LINK_BASE_URL (短链服务地址,如 http://192.168.9.5:8081)
# - SHORT_LINK_PUBLIC_URL (短链公开地址,如 https://s.yourdomain.com)
# - SHORT_LINK_API_KEY (API密钥,与短链服务一致)
# - CORS_ALLOW_ORIGINS (允许的前端域名)

# 启动服务
docker-compose -f docker-compose.prod.yml up -d

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f
```

#### Step 2: 准备短链服务

```bash
cd /root/shortimg-AI/redirect-service

# 复制配置模板
cp .env.prod .env

# 编辑配置
nano .env

# 修改以下关键配置:
# - MYSQL_PASSWORD (数据库密码)
# - REDIRECT_DOMAIN (短链域名,如 s.yourdomain.com)
# - TC_GO_PRIMARY_DOMAIN (图床域名,如 img.yourdomain.com)
# - DASHBOARD_API_KEY (必须与图床的 SHORT_LINK_API_KEY 一致!)
# - ADMIN_PASSWORD (管理员密码)

# 启动服务
docker-compose -f docker-compose.prod.yml up -d

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f
```

#### Step 3: 初始化API密钥到Redis

```bash
# 进入Redis容器
docker exec -it shortlink-redis-prod redis-cli

# 设置API密钥 (使用你在.env中配置的DASHBOARD_API_KEY)
SET api_key:your_api_key_here '{"name":"backend","status":"active","created_at":"2025-12-09","permissions":["read","write"]}'

# 验证
GET api_key:your_api_key_here

# 退出
exit
```

#### Step 4: 验证配置

```bash
# 运行配置检查脚本
cd /root/shortimg-AI
bash check-config.sh

# 如果所有检查通过,说明配置正确
```

---

## 🔑 API密钥配置 (重要!)

### 关键原则

**必须确保以下两个配置完全一致:**

1. **图床后端** (`backend/.env`):
   ```bash
   SHORT_LINK_API_KEY=your_api_key_here
   ```

2. **短链服务** (`redirect-service/.env`):
   ```bash
   DASHBOARD_API_KEY=your_api_key_here
   ```

### 生成强密钥

```bash
# 生成32字节(64字符)的随机密钥
openssl rand -hex 32

# 示例输出:
# e5f8a7b3c2d1e9f4a6b8c3d7e2f1a9b4c5d6e8f3a7b2c9d4e6f1a8b3c5d7e9f2
```

### 配置示例

#### backend/.env
```bash
SHORT_LINK_API_KEY=e5f8a7b3c2d1e9f4a6b8c3d7e2f1a9b4c5d6e8f3a7b2c9d4e6f1a8b3c5d7e9f2
```

#### redirect-service/.env
```bash
DASHBOARD_API_KEY=e5f8a7b3c2d1e9f4a6b8c3d7e2f1a9b4c5d6e8f3a7b2c9d4e6f1a8b3c5d7e9f2
```

---

## 🌐 网络配置

### 同一服务器部署

#### 选项1: 使用宿主机IP (推荐)

```bash
# backend/.env
SHORT_LINK_BASE_URL=http://192.168.9.5:8081
# 或
SHORT_LINK_BASE_URL=http://127.0.0.1:8081
```

#### 选项2: 创建共享Docker网络

```bash
# 创建共享网络
docker network create shortimg-shared-network

# 修改两个 docker-compose.prod.yml,添加:
networks:
  shortimg-shared-network:
    external: true

# backend/.env
SHORT_LINK_BASE_URL=http://shortlink-openresty-prod
```

### 不同服务器部署

```bash
# 服务器A (图床): 192.168.1.10
# backend/.env
SHORT_LINK_BASE_URL=http://192.168.1.20:8081

# 服务器B (短链): 192.168.1.20
# redirect-service/.env
REDIRECT_PORT=8081

# 确保网络互通
ping 192.168.1.20

# 配置防火墙
firewall-cmd --permanent --add-port=8081/tcp
firewall-cmd --reload
```

---

## 🏥 健康检查

### 检查服务状态

```bash
# 查看所有容器
docker ps -a

# 检查图床后端
curl http://localhost:8080/health
# 预期: {"status":"ok"}

# 检查短链服务
curl http://localhost:8081/health
# 预期: {"status":"ok"}

# 检查短链API (需要API密钥)
curl -H "X-API-Key: your_api_key_here" http://localhost:8081/api/v2/imagebed
```

### 检查数据库

```bash
# MySQL (图床)
docker exec shortimg-mysql-prod mysqladmin ping -uroot -p

# MySQL (短链)
docker exec shortlink-mysql-prod mysqladmin ping -uroot -p

# Redis (图床)
docker exec shortimg-redis-prod redis-cli ping

# Redis (短链)
docker exec shortlink-redis-prod redis-cli ping
```

### 查看日志

```bash
# 图床后端
docker logs -f shortimg-backend-prod

# 短链服务
docker logs -f shortlink-openresty-prod

# 所有服务
cd /root/shortimg-AI/backend
docker-compose -f docker-compose.prod.yml logs -f

cd /root/shortimg-AI/redirect-service
docker-compose -f docker-compose.prod.yml logs -f
```

---

## 🔍 故障排查

### 问题: 图片上传后没有生成短链

**原因**: API密钥不匹配或网络不通

**解决方法**:

```bash
# 1. 运行配置检查脚本
bash /root/shortimg-AI/check-config.sh

# 2. 检查网络连接
docker exec shortimg-backend-prod curl -v http://192.168.9.5:8081/health

# 3. 查看后端日志
docker logs shortimg-backend-prod | grep "短链"

# 4. 更新Redis中的API密钥
docker exec -it shortlink-redis-prod redis-cli
SET api_key:your_api_key_here '{"name":"backend","status":"active","created_at":"2025-12-09","permissions":["read","write"]}'
exit

# 5. 重启服务
cd /root/shortimg-AI/backend
docker-compose -f docker-compose.prod.yml restart backend
```

### 问题: 短链服务返回401错误

**原因**: Redis中没有API密钥

**解决方法**:

```bash
# 检查Redis
docker exec -it shortlink-redis-prod redis-cli
GET api_key:your_api_key_here

# 如果为空,创建密钥
SET api_key:your_api_key_here '{"name":"backend","status":"active","created_at":"2025-12-09","permissions":["read","write"]}'

# 验证
GET api_key:your_api_key_here

# 退出并重启
exit
cd /root/shortimg-AI/redirect-service
docker-compose -f docker-compose.prod.yml restart openresty
```

---

## 📊 服务管理

### 启动服务

```bash
# 启动图床后端
cd /root/shortimg-AI/backend
docker-compose -f docker-compose.prod.yml up -d

# 启动短链服务
cd /root/shortimg-AI/redirect-service
docker-compose -f docker-compose.prod.yml up -d
```

### 停止服务

```bash
# 停止图床后端
cd /root/shortimg-AI/backend
docker-compose -f docker-compose.prod.yml stop

# 停止短链服务
cd /root/shortimg-AI/redirect-service
docker-compose -f docker-compose.prod.yml stop
```

### 重启服务

```bash
# 重启图床后端
cd /root/shortimg-AI/backend
docker-compose -f docker-compose.prod.yml restart

# 重启短链服务
cd /root/shortimg-AI/redirect-service
docker-compose -f docker-compose.prod.yml restart
```

### 更新服务

```bash
# 拉取最新镜像
docker-compose -f docker-compose.prod.yml pull

# 重新创建容器
docker-compose -f docker-compose.prod.yml up -d --force-recreate
```

---

## 🔒 安全建议

1. **修改所有默认密码**
   - MySQL root密码
   - 管理员密码
   - API密钥

2. **使用强密钥**
   ```bash
   openssl rand -hex 32  # API密钥
   openssl rand -base64 24  # 数据库密码
   ```

3. **限制端口访问**
   ```bash
   # 只允许本地访问数据库
   firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="127.0.0.1" port port="3306" protocol="tcp" accept'
   ```

4. **启用HTTPS**
   - 使用Let's Encrypt免费证书
   - 配置Nginx反向代理

5. **定期备份**
   - 数据库数据
   - 上传文件
   - 配置文件

---

## 📞 获取帮助

- **详细文档**: [PRODUCTION_DEPLOYMENT_GUIDE.md](./PRODUCTION_DEPLOYMENT_GUIDE.md)
- **配置检查**: `bash check-config.sh`
- **自动部署**: `bash deploy-prod.sh`

---

## ✅ 部署检查清单

- [ ] 已生成强随机API密钥
- [ ] backend/.env 和 redirect-service/.env 的API密钥一致
- [ ] 已修改所有默认密码
- [ ] 已配置正确的域名
- [ ] 已配置网络连接 (SHORT_LINK_BASE_URL)
- [ ] 已启动所有服务
- [ ] 已初始化Redis API密钥
- [ ] 健康检查通过
- [ ] 已配置Nginx反向代理 (可选)
- [ ] 已配置SSL证书 (生产环境必需)
- [ ] 已设置定时备份

---

**祝部署顺利! 🎉**
