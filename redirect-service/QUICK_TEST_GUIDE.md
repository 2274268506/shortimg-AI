# 🚀 快速测试新路由架构

## 第一步：启动服务

```powershell
# 进入项目根目录
cd c:\Users\DXY\Documents\shortimg-AI

# 启动所有服务
docker-compose up -d

# 等待服务启动（约10秒）
Start-Sleep -Seconds 10

# 检查服务状态
docker ps
```

## 第二步：验证服务运行

```powershell
# 测试健康检查
Invoke-RestMethod -Uri "http://localhost:8081/health"

# 预期响应:
# {
#   "status": "healthy",
#   "timestamp": "2024-12-08T..."
# }
```

## 第三步：测试 V1 API（已迁移）

### 测试 3.1: 创建 GeoIP 路由短链（推荐）

```powershell
$response = Invoke-RestMethod `
    -Uri "http://localhost:8081/api/imagebed/create" `
    -Method POST `
    -ContentType "application/json" `
    -Body (@{
        image_path = "/uploads/2024/demo-geo.jpg"
        enable_geo_routing = $true
    } | ConvertTo-Json)

# 查看响应
$response | ConvertTo-Json -Depth 5

# 保存短链代码
$code = $response.data.code
Write-Host "短链代码: $code"
Write-Host "短链地址: http://localhost:8081/$code"
```

**预期响应：**
```json
{
  "success": true,
  "data": {
    "code": "img-abc123def456",
    "short_url": "http://localhost:8081/img-abc123def456",
    "long_url": "/uploads/2024/demo-geo.jpg",
    "strategy": "geo+weight",           // ✅ 地理位置+权重策略
    "geo_routing_enabled": true,        // ✅ 已启用 GeoIP
    "targets_count": 4,                 // ✅ 4 个 CDN 目标
    "expire_at": null,
    "created_at": 1733616000
  }
}
```

### 测试 3.2: 创建简单路由短链

```powershell
$response = Invoke-RestMethod `
    -Uri "http://localhost:8081/api/imagebed/create" `
    -Method POST `
    -ContentType "application/json" `
    -Body (@{
        image_path = "/uploads/2024/demo-simple.jpg"
        enable_geo_routing = $false
    } | ConvertTo-Json)

$response | ConvertTo-Json -Depth 5
```

**预期响应：**
```json
{
  "success": true,
  "data": {
    "code": "img-xyz789uvw012",
    "strategy": "weight",               // ✅ 简单权重策略
    "geo_routing_enabled": false,       // ✅ 未启用 GeoIP
    "targets_count": 1                  // ✅ 1 个 CDN 目标
  }
}
```

### 测试 3.3: 批量创建

```powershell
$response = Invoke-RestMethod `
    -Uri "http://localhost:8081/api/imagebed/batch" `
    -Method POST `
    -ContentType "application/json" `
    -Body (@{
        enable_geo_routing = $true
        images = @(
            @{ image_path = "/uploads/2024/batch-1.jpg" }
            @{ image_path = "/uploads/2024/batch-2.jpg" }
            @{ image_path = "/uploads/2024/batch-3.jpg" }
        )
    } | ConvertTo-Json -Depth 10)

$response.data | ConvertTo-Json -Depth 5
```

**预期响应：**
```json
{
  "total": 3,
  "success": 3,
  "failed": 0,
  "results": [
    {
      "success": true,
      "code": "img-...",
      "strategy": "geo+weight",
      "targets_count": 4
    },
    ...
  ]
}
```

## 第四步：测试路由功能

### 测试 4.1: 访问短链（使用上面创建的 $code）

```powershell
# 模拟北京电信用户
$redirectResponse = Invoke-WebRequest `
    -Uri "http://localhost:8081/$code" `
    -Headers @{
        "X-Forwarded-For" = "123.45.67.89"  # 模拟北京电信 IP
    } `
    -MaximumRedirection 0 `
    -ErrorAction SilentlyContinue

# 查看重定向地址
$redirectLocation = $redirectResponse.Headers.Location
Write-Host "重定向到: $redirectLocation" -ForegroundColor Green

# 查看状态码
Write-Host "状态码: $($redirectResponse.StatusCode)" -ForegroundColor Cyan
```

**预期结果：**
- 状态码: `302` (Found) 或 `301` (Moved Permanently)
- Location: `https://img.oxvxo.link/uploads/2024/demo-geo.jpg` 或其他 CDN URL
- 如果配置了多个 CDN，会根据 GeoIP 路由到最近的 CDN

### 测试 4.2: 查看日志（验证路由策略）

```powershell
# 查看最近的日志
docker logs shortlink-openresty-1 --tail 20

# 实时跟踪日志
docker logs shortlink-openresty-1 -f
```

**预期日志内容：**
```
[INFO] 创建图床短链(新架构): img-abc123 -> /uploads/2024/demo-geo.jpg, 策略=geo+weight, 目标数=4, GeoIP=true
[INFO] Using routing strategy: geo+weight
[INFO] GeoIP: IP=123.45.67.89, Country=CN, Province=北京, ISP=China Telecom
[INFO] Selected target: https://img.oxvxo.link/uploads/2024/demo-geo.jpg
```

## 第五步：测试 V2 API（新架构）

### 测试 5.1: 创建图床短链

```powershell
$response = Invoke-RestMethod `
    -Uri "http://localhost:8081/api/v2/imagebed/create" `
    -Method POST `
    -ContentType "application/json" `
    -Body (@{
        image_path = "/uploads/2024/v2-demo.jpg"
        enable_geo_routing = $true
        expire_time = 86400  # 24小时后过期
    } | ConvertTo-Json)

$response | ConvertTo-Json -Depth 5
```

### 测试 5.2: 创建通用短链

```powershell
$response = Invoke-RestMethod `
    -Uri "http://localhost:8081/api/v2/generic/create" `
    -Method POST `
    -ContentType "application/json" `
    -Body (@{
        url = "https://github.com/openresty/openresty"
        custom_code = "openresty-github"
    } | ConvertTo-Json)

$response | ConvertTo-Json -Depth 5

# 访问短链
Start-Process "http://localhost:8081/openresty-github"
```

## 第六步：运行完整测试套件

```powershell
cd c:\Users\DXY\Documents\shortimg-AI\redirect-service
powershell -ExecutionPolicy Bypass -File test-new-routing.ps1
```

## 🔧 故障排查

### 问题 1: 连接被拒绝

```powershell
# 检查服务是否启动
docker ps | findstr openresty

# 如果没有运行，启动服务
docker-compose up -d

# 查看容器日志
docker logs shortlink-openresty-1
```

### 问题 2: 创建短链失败

```powershell
# 检查 MySQL 是否运行
docker ps | findstr mysql

# 检查 Redis 是否运行
docker ps | findstr redis

# 查看详细错误日志
docker logs shortlink-openresty-1 --tail 50
```

### 问题 3: 路由不正确

```powershell
# 检查 config.lua 中的 CDN 配置
Get-Content c:\Users\DXY\Documents\shortimg-AI\redirect-service\conf\config.lua

# 查看数据库中的 targets 数据
docker exec -it shortlink-mysql-1 mysql -u root -p shortlink_db -e "SELECT short_code, targets, strategy FROM short_links ORDER BY created_at DESC LIMIT 5;"
```

## 📊 验证检查清单

完成以下检查确保迁移成功：

- [ ] V1 API 创建 GeoIP 路由短链成功（`strategy: "geo+weight"`）
- [ ] V1 API 创建简单路由短链成功（`strategy: "weight"`）
- [ ] V1 API 批量创建成功
- [ ] V2 API 创建图床短链成功
- [ ] V2 API 创建通用短链成功
- [ ] 访问短链返回 302 重定向
- [ ] 日志显示正确的路由策略
- [ ] 查询短链信息成功

## 🎯 下一步

1. **配置真实 CDN** - 在 `conf/config.lua` 中添加实际的 CDN 服务器地址
2. **生产环境测试** - 使用 `docker-compose.prod.yml` 部署测试
3. **监控配置** - 确保 Prometheus 正确采集指标
4. **负载测试** - 使用 `ab` 或 `wrk` 进行压力测试

## 📚 相关文档

- `V1_MIGRATION_COMPLETE.md` - V1 API 迁移完成报告
- `ADVANCED_ROUTING_GUIDE.md` - 高级路由引擎使用指南
- `test-new-routing.ps1` - 自动化测试脚本

---

**提示：** 以上所有命令都可以直接在 PowerShell 中运行。如果遇到问题，请查看日志或参考故障排查部分。
