# 监控系统验证脚本
# 用于验证 Prometheus、Grafana 和各个 Exporter 的运行状态

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  监控系统状态检查" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. 检查 Docker 服务状态
Write-Host "[1] 检查 Docker 服务状态..." -ForegroundColor Yellow
$services = @(
  @{Name = "short-link-openresty"; Port = 80 },
  @{Name = "short-link-prometheus"; Port = 9090 },
  @{Name = "short-link-grafana"; Port = 3000 },
  @{Name = "short-link-redis-exporter"; Port = 9121 },
  @{Name = "short-link-mysql-exporter"; Port = 9104 },
  @{Name = "short-link-redis"; Port = 6379 },
  @{Name = "short-link-mysql"; Port = 3306 }
)

$allRunning = $true
foreach ($service in $services) {
  $status = docker ps --filter "name=$($service.Name)" --format "{{.Status}}"
  if ($status -match "Up") {
    Write-Host "  ✓ $($service.Name) - 运行中 (端口: $($service.Port))" -ForegroundColor Green
  }
  else {
    Write-Host "  ✗ $($service.Name) - 未运行" -ForegroundColor Red
    $allRunning = $false
  }
}

if (!$allRunning) {
  Write-Host "`n部分服务未运行，请先启动所有服务：docker-compose up -d" -ForegroundColor Red
  exit 1
}

# 2. 检查短链服务健康状态
Write-Host "`n[2] 检查短链服务健康状态..." -ForegroundColor Yellow
try {
  $health = Invoke-RestMethod -Uri "http://localhost/health" -Method Get
  if ($health.status -eq "healthy") {
    Write-Host "  ✓ 服务状态: $($health.status)" -ForegroundColor Green
    Write-Host "    - Redis: $($health.checks.redis)" -ForegroundColor Gray
    Write-Host "    - MySQL: $($health.checks.mysql)" -ForegroundColor Gray
  }
  else {
    Write-Host "  ✗ 服务状态: $($health.status)" -ForegroundColor Red
  }
}
catch {
  Write-Host "  ✗ 无法访问健康检查端点" -ForegroundColor Red
}

# 3. 检查 Prometheus 指标
Write-Host "`n[3] 检查 Prometheus 指标..." -ForegroundColor Yellow
try {
  $metrics = Invoke-WebRequest -Uri "http://localhost/metrics" -Method Get
  $metricsText = $metrics.Content
  $metricCount = ($metricsText -split "`n" | Where-Object { $_ -match "^short_link_" -and $_ -notmatch "^#" }).Count
  Write-Host "  ✓ 指标端点可访问" -ForegroundColor Green
  Write-Host "    - 指标数量: $metricCount" -ForegroundColor Gray
  Write-Host "    - 示例指标:" -ForegroundColor Gray
  ($metricsText -split "`n" | Where-Object { $_ -match "^# HELP short_link_" } | Select-Object -First 5) | ForEach-Object {
    Write-Host "      $_" -ForegroundColor DarkGray
  }
}
catch {
  Write-Host "  ✗ 无法访问指标端点" -ForegroundColor Red
}

# 4. 检查 Prometheus 抓取目标
Write-Host "`n[4] 检查 Prometheus 抓取目标..." -ForegroundColor Yellow
try {
  $targets = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -Method Get
  $activeTargets = $targets.data.activeTargets
  foreach ($target in $activeTargets) {
    $status = if ($target.health -eq "up") { "✓" } else { "✗" }
    $color = if ($target.health -eq "up") { "Green" } else { "Red" }
    Write-Host "  $status $($target.scrapePool): $($target.health)" -ForegroundColor $color
  }
}
catch {
  Write-Host "  ✗ 无法访问 Prometheus API" -ForegroundColor Red
}

# 5. 检查 Grafana 状态
Write-Host "`n[5] 检查 Grafana 状态..." -ForegroundColor Yellow
try {
  $grafana = Invoke-RestMethod -Uri "http://localhost:3000/api/health" -Method Get
  Write-Host "  ✓ Grafana: $($grafana.database)" -ForegroundColor Green
  Write-Host "    - 版本: $($grafana.version)" -ForegroundColor Gray
}
catch {
  Write-Host "  ✗ 无法访问 Grafana" -ForegroundColor Red
}

# 6. 检查 Redis Exporter
Write-Host "`n[6] 检查 Redis Exporter..." -ForegroundColor Yellow
try {
  $redis = Invoke-WebRequest -Uri "http://localhost:9121/metrics" -Method Get
  $redisUp = $redis.Content -match "redis_up 1"
  if ($redisUp) {
    Write-Host "  ✓ Redis Exporter 正常，Redis 连接成功" -ForegroundColor Green
  }
  else {
    Write-Host "  ✗ Redis Exporter 无法连接到 Redis" -ForegroundColor Red
  }
}
catch {
  Write-Host "  ✗ 无法访问 Redis Exporter" -ForegroundColor Red
}

# 7. 检查 MySQL Exporter
Write-Host "`n[7] 检查 MySQL Exporter..." -ForegroundColor Yellow
try {
  $mysql = Invoke-WebRequest -Uri "http://localhost:9104/metrics" -Method Get
  $mysqlUp = $mysql.Content -match "mysql_up 1"
  if ($mysqlUp) {
    Write-Host "  ✓ MySQL Exporter 正常，MySQL 连接成功" -ForegroundColor Green
  }
  else {
    Write-Host "  ✗ MySQL Exporter 无法连接到 MySQL" -ForegroundColor Red
  }
}
catch {
  Write-Host "  ✗ 无法访问 MySQL Exporter" -ForegroundColor Red
}

# 8. 访问链接总结
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  访问链接" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  短链服务:         http://localhost" -ForegroundColor White
Write-Host "  健康检查:         http://localhost/health" -ForegroundColor White
Write-Host "  Prometheus:       http://localhost:9090" -ForegroundColor White
Write-Host "  Grafana:          http://localhost:3000" -ForegroundColor White
Write-Host "    - 默认账号: admin / admin" -ForegroundColor Gray
Write-Host "  Redis Exporter:   http://localhost:9121/metrics" -ForegroundColor White
Write-Host "  MySQL Exporter:   http://localhost:9104/metrics" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  监控检查完成！" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
