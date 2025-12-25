# 测试 GeoIP 分流功能
Write-Host "=== 测试短链服务 GeoIP 分流功能 ===" -ForegroundColor Cyan

# 1. 检查服务状态
Write-Host "`n1. 检查服务状态..." -ForegroundColor Yellow
$containers = @("short-link-openresty", "short-link-redis", "short-link-mysql")
foreach ($container in $containers) {
  $status = docker ps --filter "name=$container" --format "{{.Status}}"
  if ($status) {
    Write-Host "   ✓ $container : $status" -ForegroundColor Green
  }
  else {
    Write-Host "   ✗ $container : 未运行" -ForegroundColor Red
  }
}

# 2. 测试健康检查
Write-Host "`n2. 测试服务健康状态..." -ForegroundColor Yellow
try {
  $health = Invoke-WebRequest -Uri "http://localhost/health" -UseBasicParsing -TimeoutSec 5
  Write-Host "   ✓ 健康检查通过 (状态码: $($health.StatusCode))" -ForegroundColor Green
}
catch {
  Write-Host "   ✗ 健康检查失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. 测试 GeoIP 管理 API
Write-Host "`n3. 测试 GeoIP 管理 API..." -ForegroundColor Yellow

# 3.1 查看所有可用数据库
Write-Host "`n   3.1 查看所有可用的 GeoIP 数据库:" -ForegroundColor Cyan
try {
  $response = Invoke-RestMethod -Uri "http://localhost/admin/geoip/databases" -Method Get -TimeoutSec 5
  if ($response.success) {
    Write-Host "      ✓ API 响应成功" -ForegroundColor Green
    Write-Host "      总计: $($response.data.total) 个数据库" -ForegroundColor White
    foreach ($db in $response.data.databases) {
      $statusIcon = if ($db.exists) { "✓" } else { "✗" }
      $statusColor = if ($db.exists) { "Green" } else { "Red" }
      Write-Host "      $statusIcon $($db.name) ($($db.id))" -ForegroundColor $statusColor
      Write-Host "         优先级: $($db.priority) | 类型: $($db.type)" -ForegroundColor Gray
    }
  }
}
catch {
  Write-Host "      ✗ API 调用失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 3.2 查看当前选中的数据库
Write-Host "`n   3.2 查看当前选中的数据库:" -ForegroundColor Cyan
try {
  $response = Invoke-RestMethod -Uri "http://localhost/admin/geoip/selected" -Method Get -TimeoutSec 5
  if ($response.success) {
    Write-Host "      ✓ 当前使用 $($response.data.total) 个数据库" -ForegroundColor Green
    foreach ($db in $response.data.selected) {
      Write-Host "      → $($db.name) (得分: $($db.score))" -ForegroundColor White
      Write-Host "         类型: $($db.type) | ID: $($db.id)" -ForegroundColor Gray
    }
  }
}
catch {
  Write-Host "      ✗ API 调用失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 3.3 验证数据库文件
Write-Host "`n   3.3 验证数据库文件:" -ForegroundColor Cyan
try {
  $response = Invoke-RestMethod -Uri "http://localhost/admin/geoip/validate" -Method Get -TimeoutSec 5
  if ($response.success) {
    Write-Host "      ✓ 验证完成" -ForegroundColor Green
    foreach ($val in $response.data.validation) {
      $statusIcon = if ($val.readable) { "✓" } else { "✗" }
      $statusColor = if ($val.readable) { "Green" } else { "Red" }
      $sizeMB = [math]::Round($val.size / 1MB, 2)
      Write-Host "      $statusIcon $($val.name) - $sizeMB MB" -ForegroundColor $statusColor
    }
  }
}
catch {
  Write-Host "      ✗ API 调用失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 3.4 获取推荐配置
Write-Host "`n   3.4 获取数据库推荐:" -ForegroundColor Cyan
try {
  $response = Invoke-RestMethod -Uri "http://localhost/admin/geoip/recommendations" -Method Get -TimeoutSec 5
  if ($response.success) {
    Write-Host "      ✓ 推荐生成成功" -ForegroundColor Green
    Write-Host "`n$($response.data.summary)" -ForegroundColor White
  }
}
catch {
  Write-Host "      ✗ API 调用失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. 测试 IP 查询
Write-Host "`n4. 测试 IP 地理位置查询..." -ForegroundColor Yellow

$testIPs = @(
  @{ip = "1.2.3.4"; desc = "中国电信" },
  @{ip = "8.8.8.8"; desc = "美国 Google" },
  @{ip = "114.114.114.114"; desc = "中国南京" },
  @{ip = "202.106.0.20"; desc = "中国北京联通" },
  @{ip = "103.235.46.39"; desc = "香港" },
  @{ip = "220.181.38.148"; desc = "中国百度" }
)

foreach ($test in $testIPs) {
  Write-Host "`n   测试 IP: $($test.ip) ($($test.desc))" -ForegroundColor Cyan
  try {
    $body = @{ip = $test.ip } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "http://localhost/admin/geoip/query" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 5

    if ($response.success) {
      $data = $response.data
      Write-Host "      国家: $($data.country) ($($data.country_code))" -ForegroundColor White
      Write-Host "      省份: $($data.province)" -ForegroundColor White
      Write-Host "      城市: $($data.city)" -ForegroundColor White
      Write-Host "      运营商: $($data.isp)" -ForegroundColor White
      if ($data.asn) {
        Write-Host "      ASN: $($data.asn)" -ForegroundColor White
      }
      Write-Host "      数据源: $($data.sources -join ', ')" -ForegroundColor Gray
    }
  }
  catch {
    Write-Host "      ✗ 查询失败: $($_.Exception.Message)" -ForegroundColor Red
  }
}

# 5. 测试路由分流
Write-Host "`n5. 测试路由分流规则..." -ForegroundColor Yellow
Write-Host "   (路由分流需要实际的短链请求来测试)" -ForegroundColor Gray

# 6. 查看容器日志
Write-Host "`n6. 查看最近的服务日志..." -ForegroundColor Yellow
Write-Host "   OpenResty 最近日志:" -ForegroundColor Cyan
docker logs short-link-openresty --tail 20 2>&1 | Select-String -Pattern "GeoIP|RoutingEngine|error" | ForEach-Object {
  if ($_ -match "error|Error|ERROR") {
    Write-Host "      $_" -ForegroundColor Red
  }
  elseif ($_ -match "warn|Warn|WARN") {
    Write-Host "      $_" -ForegroundColor Yellow
  }
  else {
    Write-Host "      $_" -ForegroundColor White
  }
}

# 总结
Write-Host "`n=== 测试总结 ===" -ForegroundColor Cyan
Write-Host @"

✓ 服务运行状态检查
✓ GeoIP API 接口测试
✓ IP 地理位置查询测试
✓ 数据库验证

下一步操作:
1. 如果看到 GeoIP 错误，重新加载配置:
   docker-compose restart openresty

2. 查看完整日志:
   docker logs short-link-openresty

3. 测试实际的短链分流:
   - 创建一个测试短链
   - 从不同地区/运营商访问
   - 查看路由日志验证分流效果

4. 监控面板:
   - Grafana: http://localhost:3000 (admin/admin)
   - Prometheus: http://localhost:9090

"@ -ForegroundColor White

Write-Host "测试完成！" -ForegroundColor Green
