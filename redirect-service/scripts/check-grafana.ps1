# 验证 Grafana 仪表板加载
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  验证 Grafana 仪表板" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Grafana 凭据
$username = "admin"
$password = "admin"
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${password}"))
$headers = @{
  "Authorization" = "Basic $base64Auth"
  "Content-Type"  = "application/json"
}

# 1. 检查 Grafana 健康状态
Write-Host "[1] 检查 Grafana 健康状态..." -ForegroundColor Yellow
try {
  $health = Invoke-RestMethod -Uri "http://localhost:3000/api/health" -Method Get
  Write-Host "  ✓ Grafana 状态: $($health.database)" -ForegroundColor Green
  Write-Host "    版本: $($health.version)" -ForegroundColor Gray
}
catch {
  Write-Host "  ✗ 无法连接到 Grafana" -ForegroundColor Red
  exit 1
}

# 2. 检查数据源
Write-Host "`n[2] 检查数据源..." -ForegroundColor Yellow
try {
  $datasources = Invoke-RestMethod -Uri "http://localhost:3000/api/datasources" -Method Get -Headers $headers
  foreach ($ds in $datasources) {
    $status = if ($ds.isDefault) { "(默认)" } else { "" }
    Write-Host "  ✓ 数据源: $($ds.name) - $($ds.type) $status" -ForegroundColor Green
    Write-Host "    URL: $($ds.url)" -ForegroundColor Gray
  }
}
catch {
  Write-Host "  ✗ 无法获取数据源列表" -ForegroundColor Red
}

# 3. 检查仪表板
Write-Host "`n[3] 检查仪表板..." -ForegroundColor Yellow
try {
  $dashboards = Invoke-RestMethod -Uri "http://localhost:3000/api/search?type=dash-db" -Method Get -Headers $headers
  if ($dashboards.Count -gt 0) {
    Write-Host "  ✓ 找到 $($dashboards.Count) 个仪表板:" -ForegroundColor Green
    foreach ($dash in $dashboards) {
      Write-Host "    - $($dash.title)" -ForegroundColor White
      Write-Host "      UID: $($dash.uid)" -ForegroundColor Gray
      Write-Host "      URL: http://localhost:3000$($dash.url)" -ForegroundColor Gray
    }
  }
  else {
    Write-Host "  ⚠ 未找到任何仪表板" -ForegroundColor Yellow
    Write-Host "    请检查 /etc/grafana/provisioning/dashboards/ 目录" -ForegroundColor Gray
  }
}
catch {
  Write-Host "  ✗ 无法获取仪表板列表: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. 测试数据源连接
Write-Host "`n[4] 测试 Prometheus 数据源连接..." -ForegroundColor Yellow
try {
  $datasources = Invoke-RestMethod -Uri "http://localhost:3000/api/datasources" -Method Get -Headers $headers
  $prometheus = $datasources | Where-Object { $_.type -eq "prometheus" } | Select-Object -First 1

  if ($prometheus) {
    $testResult = Invoke-RestMethod -Uri "http://localhost:3000/api/datasources/$($prometheus.id)/health" -Method Get -Headers $headers
    if ($testResult.status -eq "OK") {
      Write-Host "  ✓ Prometheus 数据源连接成功" -ForegroundColor Green
    }
    else {
      Write-Host "  ✗ Prometheus 数据源连接失败" -ForegroundColor Red
    }
  }
}
catch {
  Write-Host "  ⚠ 无法测试数据源连接" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  访问 Grafana" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  URL: http://localhost:3000" -ForegroundColor White
Write-Host "  用户名: admin" -ForegroundColor White
Write-Host "  密码: admin" -ForegroundColor White
Write-Host "`n  提示: 首次登录后会要求修改密码（可跳过）`n" -ForegroundColor Gray
