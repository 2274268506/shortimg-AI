# ==========================================
# TC-GO 图床系统 - MySQL 测试快速启动
# ==========================================

Write-Host ""
Write-Host "🚀 TC-GO 图床 - MySQL 测试环境快速启动" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 Docker 是否运行
Write-Host "🔍 检查 Docker 状态..." -ForegroundColor Yellow
try {
  docker version | Out-Null
  Write-Host "✅ Docker 运行正常" -ForegroundColor Green
}
catch {
  Write-Host "❌ Docker 未运行，请先启动 Docker Desktop" -ForegroundColor Red
  exit 1
}

Write-Host ""

# 显示部署选项
Write-Host "请选择部署方式:" -ForegroundColor Cyan
Write-Host "  [1] 完整 Docker 部署 (MySQL + Redis + Backend) - 推荐用于集成测试" -ForegroundColor White
Write-Host "  [2] 本地后端部署 (仅 Docker MySQL/Redis) - 推荐用于开发调试" -ForegroundColor White
Write-Host "  [3] 查看已运行的容器" -ForegroundColor White
Write-Host "  [4] 停止所有测试容器" -ForegroundColor White
Write-Host "  [5] 清理测试环境（包括数据）" -ForegroundColor White
Write-Host ""

$choice = Read-Host "请选择 [1-5]"

switch ($choice) {
  "1" {
    Write-Host ""
    Write-Host "🐳 启动完整 Docker 环境..." -ForegroundColor Green
    Write-Host ""

    docker-compose -f docker-compose.mysql-test.yml up -d

    Write-Host ""
    Write-Host "✅ 服务已启动！" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 服务信息:" -ForegroundColor Cyan
    Write-Host "  - MySQL:   localhost:3307" -ForegroundColor White
    Write-Host "  - Redis:   localhost:6380" -ForegroundColor White
    Write-Host "  - Backend: http://localhost:8081" -ForegroundColor White
    Write-Host "  - Swagger: http://localhost:8081/swagger/index.html" -ForegroundColor White
    Write-Host ""
    Write-Host "🔐 默认账号:" -ForegroundColor Cyan
    Write-Host "  - 用户名: admin" -ForegroundColor White
    Write-Host "  - 密码:   admin123" -ForegroundColor White
    Write-Host ""
    Write-Host "📝 查看日志: docker-compose -f docker-compose.mysql-test.yml logs -f" -ForegroundColor Yellow
    Write-Host ""

    # 等待服务启动
    Write-Host "⏳ 等待服务完全启动..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    # 检查健康状态
    Write-Host "🏥 检查服务健康状态..." -ForegroundColor Yellow
    try {
      $response = Invoke-WebRequest -Uri "http://localhost:8081/api/health" -UseBasicParsing -TimeoutSec 5
      if ($response.StatusCode -eq 200) {
        Write-Host "✅ 后端服务健康检查通过！" -ForegroundColor Green
      }
    }
    catch {
      Write-Host "⚠️  后端服务可能还在启动中，请稍后访问 http://localhost:8081/api/health 检查" -ForegroundColor Yellow
    }
  }

  "2" {
    Write-Host ""
    Write-Host "🔧 启动数据库服务 + 本地后端..." -ForegroundColor Green
    Write-Host ""

    # 只启动 MySQL 和 Redis
    docker-compose -f docker-compose.mysql-test.yml up -d mysql redis

    Write-Host ""
    Write-Host "✅ 数据库服务已启动！" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 服务信息:" -ForegroundColor Cyan
    Write-Host "  - MySQL: localhost:3307" -ForegroundColor White
    Write-Host "  - Redis: localhost:6380" -ForegroundColor White
    Write-Host ""

    Write-Host "⏳ 等待数据库服务完全启动..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15

    Write-Host ""
    Write-Host "📝 下一步操作:" -ForegroundColor Cyan
    Write-Host "  cd backend" -ForegroundColor White
    Write-Host "  .\test-mysql-local.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "或手动运行:" -ForegroundColor Cyan
    Write-Host "  cd backend" -ForegroundColor White
    Write-Host "  cp .env.mysql-test .env" -ForegroundColor White
    Write-Host "  go run main.go" -ForegroundColor White
    Write-Host ""
  }

  "3" {
    Write-Host ""
    Write-Host "📋 当前运行的容器:" -ForegroundColor Cyan
    Write-Host ""
    docker ps --filter "name=shortimg" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    Write-Host ""
  }

  "4" {
    Write-Host ""
    Write-Host "🛑 停止测试容器..." -ForegroundColor Yellow
    docker-compose -f docker-compose.mysql-test.yml down
    Write-Host "✅ 容器已停止" -ForegroundColor Green
    Write-Host ""
  }

  "5" {
    Write-Host ""
    Write-Host "⚠️  警告: 这将删除所有测试数据！" -ForegroundColor Red
    $confirm = Read-Host "确认清理? (yes/no)"
    if ($confirm -eq "yes") {
      Write-Host ""
      Write-Host "🧹 清理测试环境..." -ForegroundColor Yellow
      docker-compose -f docker-compose.mysql-test.yml down -v
      Write-Host "✅ 环境已清理" -ForegroundColor Green
    }
    else {
      Write-Host "❌ 已取消" -ForegroundColor Yellow
    }
    Write-Host ""
  }

  default {
    Write-Host ""
    Write-Host "❌ 无效的选择" -ForegroundColor Red
    Write-Host ""
  }
}
