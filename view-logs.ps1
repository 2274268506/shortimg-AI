# 查看 Docker Compose 服务日志

param(
  [string]$Service = "all"
)

Write-Host ""
Write-Host "📋 查看服务日志" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
Write-Host ""

if ($Service -eq "all") {
  Write-Host "显示所有服务日志..." -ForegroundColor Yellow
  docker-compose -f docker-compose.mysql-test.yml logs -f
}
elseif ($Service -eq "backend") {
  Write-Host "显示后端服务日志..." -ForegroundColor Yellow
  docker-compose -f docker-compose.mysql-test.yml logs -f backend
}
elseif ($Service -eq "mysql") {
  Write-Host "显示 MySQL 服务日志..." -ForegroundColor Yellow
  docker-compose -f docker-compose.mysql-test.yml logs -f mysql
}
elseif ($Service -eq "redis") {
  Write-Host "显示 Redis 服务日志..." -ForegroundColor Yellow
  docker-compose -f docker-compose.mysql-test.yml logs -f redis
}
else {
  Write-Host "用法:" -ForegroundColor Cyan
  Write-Host "  .\view-logs.ps1              # 查看所有服务日志" -ForegroundColor White
  Write-Host "  .\view-logs.ps1 backend      # 仅查看后端日志" -ForegroundColor White
  Write-Host "  .\view-logs.ps1 mysql        # 仅查看 MySQL 日志" -ForegroundColor White
  Write-Host "  .\view-logs.ps1 redis        # 仅查看 Redis 日志" -ForegroundColor White
  Write-Host ""
}
