# 短链服务测试验证指南

## 📋 测试概述

本文档提供短链服务的完整测试验证方案，包括功能测试、性能测试和集成测试。

## 🚀 快速开始

### 前提条件

1. **服务已启动**
```bash
docker-compose up -d
```

2. **创建 API Key**（如果还没有）
```bash
docker exec -it short-link-openresty \
  lua /usr/local/openresty/nginx/tools/manage_api_keys.lua create "测试用Key" "*" 0
```

保存输出的 API Key，格式类似：`sk_abc123...`

### Linux/Mac 测试

```bash
# 赋予执行权限
chmod +x tests/integration/test_all.sh

# 运行测试（替换为你的 API Key）
export API_KEY="sk_your_api_key_here"
./tests/integration/test_all.sh
```

### Windows 测试

```powershell
# PowerShell 运行测试
.\tests\integration\test_all.ps1 -ApiKey "sk_your_api_key_here"

# 或设置环境变量
$env:API_KEY="sk_your_api_key_here"
.\tests\integration\test_all.ps1
```

### 自定义配置

```bash
# Linux/Mac - 指定服务地址
BASE_URL="http://192.168.1.100" API_KEY="sk_xxx" ./tests/integration/test_all.sh

# Windows
.\tests\integration\test_all.ps1 -BaseUrl "http://192.168.1.100" -ApiKey "sk_xxx"
```

## 📊 测试覆盖范围

### 阶段 1: 健康检查测试 ✅
- ✅ 完整健康检查 (`/health`)
- ✅ 活跃性检查 (`/health/live`)
- ✅ 就绪性检查 (`/health/ready`)

**验证点**：
- 服务基础可用性
- Redis 连接状态
- MySQL 连接状态
- 内存和磁盘状态

---

### 阶段 2: API 认证测试 🔐
- ✅ 无认证访问拒绝（401）
- ✅ 有效 API Key 访问
- ✅ 速率限制验证

**验证点**：
- 未授权请求被拦截
- API Key 正确验证
- 认证用户可访问受保护资源

---

### 阶段 3: 短链管理测试 🔗
- ✅ 创建短链
- ✅ 查询短链
- ✅ 访问短链（重定向验证）
- ✅ 更新短链状态
- ✅ 删除短链

**验证点**：
- CRUD 操作完整性
- 重定向功能正常
- 数据持久化
- 缓存更新

---

### 阶段 4: 批量操作测试 🔄
- ✅ 批量创建（3条记录）
- ✅ 批量查询
- ✅ 批量更新状态
- ✅ 批量删除

**验证点**：
- 批量操作事务性
- 成功/失败报告准确性
- 单次最多100条限制
- 缓存同步

---

### 阶段 5: 统计分析测试 📈
- ✅ 总览统计
- ✅ 仪表板统计
- ✅ 设备类型统计
- ✅ 地理分布统计

**验证点**：
- 统计数据准确性
- 多维度分析
- 时间范围筛选
- 实时统计更新

---

### 阶段 6: 定时任务测试 ⏰
- ✅ 获取任务状态
- ✅ 手动触发任务
- ✅ 任务执行日志

**验证点**：
- 任务调度正常
- 手动触发功能
- 任务执行记录
- 错误处理机制

---

### 阶段 7: 性能测试 ⚡
- ✅ 并发访问测试（10并发）
- ✅ 响应时间测试
- ✅ 负载测试

**验证点**：
- 并发处理能力
- 响应时间 < 1秒
- 系统稳定性

---

## 🧪 手动测试场景

### 1. Web 管理界面测试

```bash
# 访问管理界面
http://localhost/dashboard/

# 测试步骤：
1. 输入 API Key
2. 查看仪表板统计
3. 创建新短链
4. 查看统计分析
5. 测试批量操作
6. 查看定时任务状态
```

### 2. 短链重定向测试

```bash
# 1. 创建测试短链
curl -X POST http://localhost/api/v1/links \
  -H "X-API-Key: sk_xxx" \
  -H "Content-Type: application/json" \
  -d '{
    "short_code": "demo001",
    "targets": [
      {
        "cdn": "north_telecom",
        "path": "/images/demo.jpg"
      }
    ],
    "strategy": "round_robin"
  }'

# 2. 访问短链（应该重定向）
curl -L http://localhost/r/demo001

# 3. 查看访问日志
docker-compose logs openresty | grep "demo001"
```

### 3. 批量操作测试

```bash
# 创建测试数据文件
cat > batch_test.json <<EOF
{
  "links": [
    {
      "short_code": "batch001",
      "targets": [{"cdn": "north_telecom", "path": "/img1.jpg"}],
      "strategy": "round_robin"
    },
    {
      "short_code": "batch002",
      "targets": [{"cdn": "south_unicom", "path": "/img2.jpg"}],
      "strategy": "geo"
    }
  ]
}
EOF

# 批量创建
curl -X POST http://localhost/api/v1/batch/create \
  -H "X-API-Key: sk_xxx" \
  -H "Content-Type: application/json" \
  -d @batch_test.json

# 批量查询
curl -X POST http://localhost/api/v1/batch/query \
  -H "X-API-Key: sk_xxx" \
  -H "Content-Type: application/json" \
  -d '{"short_codes": ["batch001", "batch002"]}'

# 批量删除
curl -X POST http://localhost/api/v1/batch/delete \
  -H "X-API-Key: sk_xxx" \
  -H "Content-Type: application/json" \
  -d '{"short_codes": ["batch001", "batch002"]}'
```

### 4. 统计数据测试

```bash
# 创建测试短链并访问几次
curl -X POST http://localhost/api/v1/links \
  -H "X-API-Key: sk_xxx" \
  -d '{"short_code":"stat_test","targets":[{"cdn":"north_telecom","path":"/test.jpg"}],"strategy":"round_robin"}'

# 访问5次生成统计数据
for i in {1..5}; do
  curl http://localhost/r/stat_test
  sleep 1
done

# 查看统计
curl -H "X-API-Key: sk_xxx" \
  "http://localhost/api/v1/stats/stat_test/dashboard?days=7" | jq

# 导出数据
curl -H "X-API-Key: sk_xxx" \
  "http://localhost/api/v1/stats/stat_test/export?format=csv" \
  -o stats.csv
```

### 5. 定时任务测试

```bash
# 查看任务状态
curl -H "X-API-Key: sk_xxx" \
  http://localhost/api/v1/tasks/status | jq

# 手动触发任务
curl -X POST http://localhost/api/v1/tasks/trigger \
  -H "X-API-Key: sk_xxx" \
  -H "Content-Type: application/json" \
  -d '{"task_name": "clean_expired_links"}'

# 查看执行日志
docker-compose logs openresty | grep "定时任务"
```

## 📈 性能基准测试

### 使用 Apache Bench (ab)

```bash
# 安装 ab（如果未安装）
# Ubuntu/Debian: apt-get install apache2-utils
# Mac: brew install ab
# Windows: 使用 WSL 或下载独立版本

# 1. 健康检查性能
ab -n 1000 -c 10 http://localhost/health

# 2. 短链重定向性能
ab -n 1000 -c 10 http://localhost/r/demo001

# 3. API 查询性能
ab -n 100 -c 5 -H "X-API-Key: sk_xxx" \
  http://localhost/api/v1/stats/overview
```

### 使用 wrk（高级）

```bash
# 安装 wrk
# Ubuntu: apt-get install wrk
# Mac: brew install wrk

# 1. 基础性能测试（30秒，10并发，2线程）
wrk -t2 -c10 -d30s http://localhost/health

# 2. 短链重定向测试
wrk -t2 -c10 -d30s http://localhost/r/demo001

# 3. 带认证的 API 测试
wrk -t2 -c10 -d30s \
  -H "X-API-Key: sk_xxx" \
  http://localhost/api/v1/stats/overview
```

## 🔍 故障排查

### 测试失败常见原因

#### 1. 服务未启动
```bash
# 检查服务状态
docker-compose ps

# 查看日志
docker-compose logs

# 重启服务
docker-compose restart
```

#### 2. API Key 无效
```bash
# 列出所有 API Key
docker exec -it short-link-openresty \
  lua /usr/local/openresty/nginx/tools/manage_api_keys.lua list

# 创建新的 API Key
docker exec -it short-link-openresty \
  lua /usr/local/openresty/nginx/tools/manage_api_keys.lua create "New Key"
```

#### 3. 数据库连接失败
```bash
# 检查 MySQL 状态
docker exec -it short-link-mysql mysqladmin ping

# 检查 Redis 状态
docker exec -it short-link-redis redis-cli ping

# 查看数据库日志
docker-compose logs mysql
docker-compose logs redis
```

#### 4. 端口冲突
```bash
# 检查端口占用
# Linux/Mac
lsof -i :80
netstat -tulpn | grep :80

# Windows
netstat -ano | findstr :80

# 修改端口（docker-compose.yml）
ports:
  - "8080:80"  # 使用 8080 替代 80
```

## 📊 测试报告示例

### 成功运行示例输出

```
========================================
短链服务完整功能测试
========================================

测试配置:
  BASE_URL: http://localhost
  API_KEY: sk_abc123...

========================================
阶段 1: 健康检查测试
========================================

[测试] 1.1 完整健康检查 (/health)
✅ 完整健康检查 (状态码: 200)
[测试] 1.2 活跃性检查 (/health/live)
✅ 活跃性检查 (状态码: 200)
[测试] 1.3 就绪性检查 (/health/ready)
✅ 就绪性检查 (状态码: 200)

========================================
阶段 2: API 认证测试
========================================

[测试] 2.1 无认证访问管理 API（应该返回 401）
✅ 无认证访问被拒绝 (状态码: 401)
[测试] 2.2 有效 API Key 访问
✅ 有效认证访问 (状态码: 200)

... (更多测试输出) ...

========================================
测试结果汇总
========================================

总测试数: 25
通过数: 25
失败数: 0

🎉 所有测试通过！
```

## 🎯 测试检查清单

在生产环境部署前，确保以下所有测试通过：

- [ ] 所有健康检查端点返回 200
- [ ] API 认证正常工作
- [ ] 短链创建、查询、删除功能正常
- [ ] 短链重定向正常（302/301）
- [ ] 批量操作成功率 100%
- [ ] 统计数据准确
- [ ] 定时任务正常执行
- [ ] Web 管理界面可访问
- [ ] 响应时间 < 1秒
- [ ] 10并发测试通过
- [ ] 日志记录正常
- [ ] 数据库连接稳定
- [ ] Redis 缓存工作正常

## 📝 下一步

测试通过后，您可以：

1. **进行压力测试**
   - 使用 wrk 进行长时间压力测试
   - 监控系统资源使用

2. **配置监控**
   - 部署 Prometheus + Grafana
   - 配置告警规则

3. **生产环境部署**
   - 使用 HTTPS
   - 配置域名
   - 设置备份策略

4. **性能优化**
   - 根据测试结果调优
   - 优化数据库索引
   - 调整缓存策略

## 📞 支持

如果测试过程中遇到问题：

1. 查看日志：`docker-compose logs -f`
2. 检查配置：`.env` 文件
3. 验证网络：`docker network ls`
4. 数据库状态：`docker exec -it short-link-mysql mysql -u root -p`

---

**最后更新**: 2025年12月5日
