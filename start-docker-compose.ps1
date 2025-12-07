# 启动 MySQL 测试环境（Docker Compose 完整版）

Write-Host ""
Write-Host "🚀 启动 TC-GO 图床 MySQL 测试环境（完整 Docker 部署）" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# 检查 Docker
Write-Host "🔍 检查 Docker..." -ForegroundColor Yellow
try {
  docker version | Out-Null
  Write-Host "✅ Docker 运行正常" -ForegroundColor Green
}
catch {
  Write-Host "❌ Docker 未运行，请先启动 Docker Desktop" -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "📦 正在构建并启动服务..." -ForegroundColor Yellow
Write-Host "  - MySQL 8.0" -ForegroundColor White
Write-Host "  - Redis 7" -ForegroundColor White
Write-Host "  - 后端 API (Docker 容器)" -ForegroundColor White
Write-Host ""

# 启动服务
docker-compose -f docker-compose.mysql-test.yml up -d --build

if ($LASTEXITCODE -eq 0) {
  Write-Host ""
  Write-Host "✅ 服务启动成功！" -ForegroundColor Green
  Write-Host ""

  # 等待服务启动
  Write-Host "⏳ 等待服务完全启动..." -ForegroundColor Yellow
  Start-Sleep -Seconds 10

  # 显示容器状态
  Write-Host ""
  Write-Host "📊 容器状态:" -ForegroundColor Cyan
  docker-compose -f docker-compose.mysql-test.yml ps

  Write-Host ""
  Write-Host "🌐 访问地址:" -ForegroundColor Cyan
  Write-Host "  - 后端 API: http://localhost:8080" -ForegroundColor White
  Write-Host "  - Swagger 文档: http://localhost:8080/swagger/index.html" -ForegroundColor White
  Write-Host "  - 健康检查: http://localhost:8080/api/health" -ForegroundColor White
  Write-Host ""

  Write-Host "🔐 默认管理员账号:" -ForegroundColor Cyan
  Write-Host "  - 用户名: admin" -ForegroundColor White
  Write-Host "  - 密码: admin123" -ForegroundColor White
  Write-Host ""

  Write-Host "💡 常用命令:" -ForegroundColor Cyan
  Write-Host "  查看日志: docker-compose -f docker-compose.mysql-test.yml logs -f" -ForegroundColor White
  Write-Host "  停止服务: docker-compose -f docker-compose.mysql-test.yml down" -ForegroundColor White
  Write-Host "  重启服务: docker-compose -f docker-compose.mysql-test.yml restart" -ForegroundColor White
  Write-Host ""
}
else {
  Write-Host ""
  Write-Host "❌ 服务启动失败，请查看错误信息" -ForegroundColor Red
  Write-Host ""
}
