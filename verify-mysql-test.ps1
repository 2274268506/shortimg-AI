# MySQL 测试验证脚本

Write-Host "🧪 TC-GO 图床 MySQL 测试验证" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# 检查容器状态
Write-Host "📋 检查容器状态..." -ForegroundColor Yellow
$containers = docker ps --filter "name=shortimg" --format "table {{.Names}}\t{{.Status}}"
Write-Host $containers
Write-Host ""

# 测试 MySQL 连接
Write-Host "🔍 测试 MySQL 连接..." -ForegroundColor Yellow
try {
  $mysqlTest = docker exec -it shortimg-mysql-test mysql -u imagebed_user -ptest_password_123 -e "SELECT 1 AS test;" 2>$null
  if ($mysqlTest) {
    Write-Host "✅ MySQL 连接成功！" -ForegroundColor Green
  }
}
catch {
  Write-Host "❌ MySQL 连接失败" -ForegroundColor Red
}
Write-Host ""

# 查看数据库表
Write-Host "📊 查看数据库表..." -ForegroundColor Yellow
try {
  $tables = docker exec -it shortimg-mysql-test mysql -u imagebed_user -ptest_password_123 imagebed -e "SHOW TABLES;" 2>$null
  Write-Host $tables
}
catch {
  Write-Host "❌ 无法查看表" -ForegroundColor Red
}
Write-Host ""

# 查看用户数据
Write-Host "👤 查看用户数据..." -ForegroundColor Yellow
try {
  $users = docker exec -it shortimg-mysql-test mysql -u imagebed_user -ptest_password_123 imagebed -e "SELECT id, username, email, role, status FROM users;" 2>$null
  Write-Host $users
}
catch {
  Write-Host "❌ 无法查看用户" -ForegroundColor Red
}
Write-Host ""

# 测试 Redis 连接
Write-Host "🔍 测试 Redis 连接..." -ForegroundColor Yellow
try {
  $redisTest = docker exec -it shortimg-redis-test redis-cli ping 2>$null
  if ($redisTest -match "PONG") {
    Write-Host "✅ Redis 连接成功！" -ForegroundColor Green
  }
}
catch {
  Write-Host "❌ Redis 连接失败" -ForegroundColor Red
}
Write-Host ""

Write-Host "📝 后端服务信息:" -ForegroundColor Cyan
Write-Host "  启动后端: cd backend; go run main.go" -ForegroundColor White
Write-Host "  或使用测试脚本: cd backend; .\test-mysql-local.ps1" -ForegroundColor White
Write-Host ""
Write-Host "  健康检查: http://localhost:8080/api/health" -ForegroundColor White
Write-Host "  Swagger: http://localhost:8080/swagger/index.html" -ForegroundColor White
Write-Host ""
Write-Host "🔐 默认管理员账号:" -ForegroundColor Cyan
Write-Host "  用户名: admin" -ForegroundColor White
Write-Host "  密码: admin123" -ForegroundColor White
Write-Host ""
Write-Host "💡 测试登录 API:" -ForegroundColor Cyan
Write-Host '  $body = @{username="admin"; password="admin123"} | ConvertTo-Json' -ForegroundColor White
Write-Host '  Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method Post -Body $body -ContentType "application/json"' -ForegroundColor White
Write-Host ""
