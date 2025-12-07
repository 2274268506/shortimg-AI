# ==========================================
# TC-GO 图床系统 - MySQL 本地测试脚本
# ==========================================
# 此脚本用于在本地直接运行后端，连接到 Docker MySQL

Write-Host "🚀 TC-GO 图床系统 - MySQL 本地测试" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否已经启动了 MySQL 和 Redis 容器
Write-Host "📋 检查 Docker 容器状态..." -ForegroundColor Yellow

$mysqlRunning = docker ps --filter "name=shortimg-mysql-test" --format "{{.Names}}" 2>$null
$redisRunning = docker ps --filter "name=shortimg-redis-test" --format "{{.Names}}" 2>$null

if (-not $mysqlRunning) {
  Write-Host "⚠️  MySQL 容器未运行，正在启动..." -ForegroundColor Yellow
  docker-compose -f ..\docker-compose.mysql-test.yml up -d mysql
  Write-Host "⏳ 等待 MySQL 启动..." -ForegroundColor Yellow
  Start-Sleep -Seconds 15
}
else {
  Write-Host "✅ MySQL 容器已运行" -ForegroundColor Green
}

if (-not $redisRunning) {
  Write-Host "⚠️  Redis 容器未运行，正在启动..." -ForegroundColor Yellow
  docker-compose -f ..\docker-compose.mysql-test.yml up -d redis
  Write-Host "⏳ 等待 Redis 启动..." -ForegroundColor Yellow
  Start-Sleep -Seconds 5
}
else {
  Write-Host "✅ Redis 容器已运行" -ForegroundColor Green
}

Write-Host ""

# 检查 .env 文件
if (Test-Path ".env") {
  Write-Host "⚠️  发现现有 .env 文件" -ForegroundColor Yellow
  $backup = ".env.backup." + (Get-Date -Format "yyyyMMdd-HHmmss")
  Copy-Item ".env" $backup
  Write-Host "📦 已备份到: $backup" -ForegroundColor Cyan
}

# 复制 MySQL 测试配置
Write-Host "📝 应用 MySQL 测试配置..." -ForegroundColor Yellow
Copy-Item ".env.mysql-test" ".env" -Force
Write-Host "✅ 配置已应用" -ForegroundColor Green
Write-Host ""

# 确保必要的目录存在
Write-Host "📁 创建必要的目录..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path ".\data" | Out-Null
New-Item -ItemType Directory -Force -Path ".\uploads" | Out-Null
New-Item -ItemType Directory -Force -Path ".\logs" | Out-Null
Write-Host "✅ 目录已创建" -ForegroundColor Green
Write-Host ""

# 显示配置信息
Write-Host "📊 当前配置:" -ForegroundColor Cyan
Write-Host "  - 数据库类型: MySQL 8.0" -ForegroundColor White
Write-Host "  - 数据库地址: localhost:3307" -ForegroundColor White
Write-Host "  - 数据库名称: imagebed" -ForegroundColor White
Write-Host "  - Redis 地址: localhost:6380" -ForegroundColor White
Write-Host "  - 服务端口: 8080" -ForegroundColor White
Write-Host "  - 默认管理员: admin / admin123" -ForegroundColor White
Write-Host ""

# 询问是否启动服务
$choice = Read-Host "是否启动后端服务? (Y/n)"
if ($choice -eq "" -or $choice -eq "Y" -or $choice -eq "y") {
  Write-Host ""
  Write-Host "🚀 启动后端服务..." -ForegroundColor Green
  Write-Host "======================================" -ForegroundColor Cyan
  Write-Host ""

  # 运行后端
  go run main.go
}
else {
  Write-Host ""
  Write-Host "💡 手动启动命令:" -ForegroundColor Yellow
  Write-Host "   go run main.go" -ForegroundColor White
  Write-Host ""
}

Write-Host ""
Write-Host "📌 有用的命令:" -ForegroundColor Cyan
Write-Host "  查看 MySQL 日志: docker logs shortimg-mysql-test" -ForegroundColor White
Write-Host "  连接 MySQL:     docker exec -it shortimg-mysql-test mysql -u imagebed_user -p" -ForegroundColor White
Write-Host "  停止容器:       docker-compose -f ../docker-compose.mysql-test.yml down" -ForegroundColor White
Write-Host "  清理数据:       docker-compose -f ../docker-compose.mysql-test.yml down -v" -ForegroundColor White
Write-Host ""
