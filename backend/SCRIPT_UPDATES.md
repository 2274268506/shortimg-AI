# 🔄 部署脚本更新说明

## 📝 更新内容

### ✅ 已优化 `deploy-prod.sh` 脚本

**新增功能：自动修复目录权限**

在启动服务前，脚本会自动设置正确的目录权限，避免权限问题：

#### 步骤 5/6：自动权限修复
- ✅ MySQL 数据和日志目录（UID 999）
- ✅ Redis 数据目录（UID 999）
- ✅ Backend 上传、日志、数据目录（UID 1000）

**好处：**
- 🚀 无需手动运行 `fix-permissions.sh`
- 🎯 一键部署，自动处理权限问题
- 💯 确保每次部署时权限都正确

### ✅ 已优化 `quick-fix.sh` 脚本

**改进：**
- ✅ 内置权限修复逻辑，无需依赖外部脚本
- ✅ 自动检查并创建必要的目录
- ✅ 更智能的健康检查（支持有无 health-check.sh）

## 🚀 使用方式

### 首次部署或完整部署
```bash
sudo ./deploy-prod.sh
```

**脚本会自动：**
1. ✅ 检查依赖
2. ✅ 创建目录
3. ✅ 配置环境变量
4. ✅ 创建 MySQL 配置
5. ✅ **自动修复权限** ⭐ 新增
6. ✅ 启动服务
7. ✅ 健康检查

### 快速修复问题
```bash
sudo ./quick-fix.sh
```

**脚本会自动：**
1. ✅ 停止服务
2. ✅ **修复权限** ⭐ 改进（内置逻辑）
3. ✅ 重启服务
4. ✅ 健康检查

### 手动修复权限（可选）
```bash
sudo ./fix-permissions.sh
```

**何时使用：**
- 仅需要修复权限，不重启服务时

## 📊 对比说明

### 之前的流程
```bash
# 需要多个步骤
sudo ./deploy-prod.sh        # 部署
sudo ./fix-permissions.sh    # 修复权限（如果有问题）
docker-compose ... restart   # 重启服务
```

### 现在的流程
```bash
# 一步到位
sudo ./deploy-prod.sh        # 自动包含权限修复
```

或

```bash
# 遇到问题时
sudo ./quick-fix.sh          # 一键修复所有问题
```

## 🎯 最佳实践

### 1. 首次部署
```bash
cd /path/to/backend
sudo chmod +x *.sh
sudo ./deploy-prod.sh
```

### 2. 日常重启（无需修复权限）
```bash
docker-compose -f docker-compose.prod.yml restart
```

### 3. 遇到权限问题
```bash
sudo ./quick-fix.sh
```

### 4. 配置更新后
```bash
# 修改 .env 后
docker-compose -f docker-compose.prod.yml up -d --force-recreate
```

## 📁 脚本说明

| 脚本 | 用途 | 权限修复 |
|------|------|---------|
| `deploy-prod.sh` | 完整部署 | ✅ 自动 |
| `quick-fix.sh` | 快速修复 | ✅ 自动 |
| `fix-permissions.sh` | 仅修复权限 | ✅ 手动调用 |

## 💡 使用建议

1. **首次部署** → 使用 `deploy-prod.sh`
2. **遇到任何问题** → 使用 `quick-fix.sh`
3. **日常运维** → 使用 `docker-compose` 命令
4. **仅权限问题** → 使用 `fix-permissions.sh`

## 🔍 验证权限是否正确

```bash
# 查看目录权限
ls -la /root/docker/shortimg-ai/

# 查看 backend 目录
ls -la /root/docker/shortimg-ai/backend/

# 查看容器日志，不应有权限错误
docker-compose -f docker-compose.prod.yml logs backend | grep -i permission
```

## ✅ 更新生效

现在运行 `deploy-prod.sh` 会自动处理权限问题，无需额外操作！

```bash
# 更新后的完整部署流程（一步到位）
sudo ./deploy-prod.sh
```

就这么简单！🎉
