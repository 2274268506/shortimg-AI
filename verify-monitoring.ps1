#!/usr/bin/env pwsh
# 监控系统集成验证脚本

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "监控系统集成验证" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 检查短链服务是否运行
Write-Host "[1/6] 检查短链服务状态..." -ForegroundColor Yellow
$shortlinkContainer = docker ps --filter "name=shortlink-openresty" --format "{{.Names}}"
if ($shortlinkContainer) {
  Write-Host "✓ 短链服务运行中: $shortlinkContainer" -ForegroundColor Green
}
else {
  Write-Host "✗ 短链服务未运行" -ForegroundColor Red
  Write-Host "  请先启动短链服务: cd redirect-service && docker-compose -f docker-compose.prod.yml up -d" -ForegroundColor Yellow
  exit 1
}

# 步骤 2: 检查短链服务的监控端点
Write-Host ""
Write-Host "[2/6] 检查短链服务监控端点..." -ForegroundColor Yellow
try {
  $response = Invoke-WebRequest -Uri "http://localhost:8081/metrics" -TimeoutSec 5
  if ($response.StatusCode -eq 200) {
    Write-Host "✓ 监控端点正常: http://localhost:8081/metrics" -ForegroundColor Green

    # 检查关键指标
    $content = $response.Content
    if ($content -match "shortlink_redirects_total") {
      Write-Host "  ✓ 发现指标: shortlink_redirects_total" -ForegroundColor Green
    }
    if ($content -match "shortlink_cache_hits") {
      Write-Host "  ✓ 发现指标: shortlink_cache_hits" -ForegroundColor Green
    }
  }
}
catch {
  Write-Host "✗ 无法访问监控端点" -ForegroundColor Red
  Write-Host "  错误: $_" -ForegroundColor Yellow
  Write-Host "  提示: 确认 ENABLE_METRICS=true 在 .env 文件中" -ForegroundColor Yellow
}

# 步骤 3: 检查 Prometheus 是否运行
Write-Host ""
Write-Host "[3/6] 检查 Prometheus 服务..." -ForegroundColor Yellow
$prometheusContainer = docker ps --filter "name=tc-go-prometheus" --format "{{.Names}}"
if ($prometheusContainer) {
  Write-Host "✓ Prometheus 运行中: $prometheusContainer" -ForegroundColor Green
}
else {
  Write-Host "✗ Prometheus 未运行" -ForegroundColor Red
  Write-Host "  启动命令: docker-compose -f docker-compose.monitoring.yml up -d" -ForegroundColor Yellow
  exit 1
}

# 步骤 4: 验证 Prometheus 配置
Write-Host ""
Write-Host "[4/6] 验证 Prometheus 配置..." -ForegroundColor Yellow
if (Test-Path "prometheus.yml") {
  $prometheusConfig = Get-Content "prometheus.yml" -Raw
  if ($prometheusConfig -match "shortlink-service") {
    Write-Host "✓ Prometheus 配置包含短链服务" -ForegroundColor Green
  }
  else {
    Write-Host "✗ Prometheus 配置缺少短链服务" -ForegroundColor Red
    Write-Host "  请检查 prometheus.yml 文件" -ForegroundColor Yellow
  }
}
else {
  Write-Host "✗ 找不到 prometheus.yml 文件" -ForegroundColor Red
}

# 步骤 5: 检查 Prometheus Targets
Write-Host ""
Write-Host "[5/6] 检查 Prometheus 抓取目标..." -ForegroundColor Yellow
try {
  $apiResponse = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -TimeoutSec 5
  $shortlinkTarget = $apiResponse.data.activeTargets | Where-Object { $_.labels.job -eq "shortlink-service" }

  if ($shortlinkTarget) {
    $health = $shortlinkTarget.health
    $lastScrape = $shortlinkTarget.lastScrape

    if ($health -eq "up") {
      Write-Host "✓ 短链服务监控目标状态: UP" -ForegroundColor Green
      Write-Host "  最后抓取: $lastScrape" -ForegroundColor Gray
    }
    else {
      Write-Host "✗ 短链服务监控目标状态: $health" -ForegroundColor Red
      Write-Host "  最后错误: $($shortlinkTarget.lastError)" -ForegroundColor Yellow
    }
  }
  else {
    Write-Host "✗ 未找到短链服务监控目标" -ForegroundColor Red
    Write-Host "  请重启 Prometheus: docker-compose -f docker-compose.monitoring.yml restart prometheus" -ForegroundColor Yellow
  }
}
catch {
  Write-Host "✗ 无法访问 Prometheus API" -ForegroundColor Red
  Write-Host "  错误: $_" -ForegroundColor Yellow
}

# 步骤 6: 查询短链服务指标
Write-Host ""
Write-Host "[6/6] 查询短链服务指标..." -ForegroundColor Yellow
try {
  $query = "up{job='shortlink-service'}"
  $queryUrl = "http://localhost:9090/api/v1/query?query=$([System.Web.HttpUtility]::UrlEncode($query))"
  $queryResponse = Invoke-RestMethod -Uri $queryUrl -TimeoutSec 5

  if ($queryResponse.data.result.Count -gt 0) {
    $value = $queryResponse.data.result[0].value[1]
    if ($value -eq "1") {
      Write-Host "✓ 短链服务在线: up{job='shortlink-service'} = 1" -ForegroundColor Green
    }
    else {
      Write-Host "✗ 短链服务离线: up{job='shortlink-service'} = 0" -ForegroundColor Red
    }
  }
  else {
    Write-Host "✗ 查询无结果" -ForegroundColor Red
    Write-Host "  可能需要等待 Prometheus 完成首次抓取（10-30秒）" -ForegroundColor Yellow
  }
}
catch {
  Write-Host "✗ 查询失败" -ForegroundColor Red
  Write-Host "  错误: $_" -ForegroundColor Yellow
}

# 总结
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "验证完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "访问地址:" -ForegroundColor Cyan
Write-Host "  Prometheus: http://localhost:9090" -ForegroundColor White
Write-Host "  Grafana:    http://localhost:3001 (admin/admin)" -ForegroundColor White
Write-Host "  短链监控:   http://localhost:8081/metrics" -ForegroundColor White
Write-Host ""
Write-Host "推荐操作:" -ForegroundColor Cyan
Write-Host "  1. 访问 Prometheus Targets: http://localhost:9090/targets" -ForegroundColor White
Write-Host "  2. 查看短链服务指标: http://localhost:9090/graph?g0.expr=up%7Bjob%3D%22shortlink-service%22%7D" -ForegroundColor White
Write-Host "  3. 在 Grafana 中创建仪表板" -ForegroundColor White
Write-Host ""
