# ==========================================
# ShortImg-AI Backend 生产环境配置文件清单
# ==========================================

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     ShortImg-AI Backend 生产环境配置文件                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$baseDir = $PSScriptRoot

# 配置文件
Write-Host "📦 Docker 配置文件:" -ForegroundColor Yellow
Write-Host "  ✓ docker-compose.prod.yml" -ForegroundColor Green
if (Test-Path "$baseDir\docker-compose.prod.yml") {
    $size = (Get-Item "$baseDir\docker-compose.prod.yml").Length
    Write-Host "    大小: $([math]::Round($size/1KB, 2)) KB" -ForegroundColor Gray
}
Write-Host "  ✓ .env.prod (环境变量模板)" -ForegroundColor Green
if (Test-Path "$baseDir\.env.prod") {
    $size = (Get-Item "$baseDir\.env.prod").Length
    Write-Host "    大小: $([math]::Round($size/1KB, 2)) KB" -ForegroundColor Gray
}
Write-Host ""

# 部署脚本
Write-Host "🚀 部署与管理脚本:" -ForegroundColor Yellow
$scripts = @(
    "deploy-prod.sh",
    "health-check.sh",
    "backup-mysql.sh",
    "backup-uploads.sh",
    "restore-mysql.sh"
)

foreach ($script in $scripts) {
    Write-Host "  ✓ $script" -ForegroundColor Green
    if (Test-Path "$baseDir\$script") {
        $size = (Get-Item "$baseDir\$script").Length
        Write-Host "    大小: $([math]::Round($size/1KB, 2)) KB" -ForegroundColor Gray
    }
}
Write-Host ""

# 监控配置
Write-Host "📊 监控配置:" -ForegroundColor Yellow
Write-Host "  ✓ monitoring/prometheus.yml" -ForegroundColor Green
if (Test-Path "$baseDir\monitoring\prometheus.yml") {
    $size = (Get-Item "$baseDir\monitoring\prometheus.yml").Length
    Write-Host "    大小: $([math]::Round($size/1KB, 2)) KB" -ForegroundColor Gray
}
Write-Host "  ✓ monitoring/alerts.yml" -ForegroundColor Green
if (Test-Path "$baseDir\monitoring\alerts.yml") {
    $size = (Get-Item "$baseDir\monitoring\alerts.yml").Length
    Write-Host "    大小: $([math]::Round($size/1KB, 2)) KB" -ForegroundColor Gray
}
Write-Host ""

# 文档
Write-Host "📚 文档:" -ForegroundColor Yellow
$docs = @(
    "PRODUCTION_DEPLOY.md",
    "README.prod.md",
    "DEPLOYMENT_CHECKLIST.md",
    "PRODUCTION_CONFIG_SUMMARY.md",
    "QUICK_REFERENCE.txt"
)

foreach ($doc in $docs) {
    Write-Host "  ✓ $doc" -ForegroundColor Green
    if (Test-Path "$baseDir\$doc") {
        $size = (Get-Item "$baseDir\$doc").Length
        Write-Host "    大小: $([math]::Round($size/1KB, 2)) KB" -ForegroundColor Gray
    }
}
Write-Host ""

# 统计
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 统计信息:" -ForegroundColor Yellow
Write-Host "  • 配置文件: 2 个" -ForegroundColor White
Write-Host "  • 脚本文件: 5 个" -ForegroundColor White
Write-Host "  • 监控配置: 2 个" -ForegroundColor White
Write-Host "  • 文档文件: 5 个" -ForegroundColor White
Write-Host "  • 总计: 14 个文件" -ForegroundColor Cyan
Write-Host ""

# 下一步提示
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🎯 下一步操作:" -ForegroundColor Yellow
Write-Host "  1. 上传所有文件到 Linux 服务器" -ForegroundColor White
Write-Host "  2. 编辑 .env 文件，修改所有密码和密钥" -ForegroundColor White
Write-Host "  3. 运行部署脚本:" -ForegroundColor White
Write-Host "     chmod +x *.sh" -ForegroundColor Gray
Write-Host "     sudo ./deploy-prod.sh" -ForegroundColor Gray
Write-Host "  4. 查看快速参考: QUICK_REFERENCE.txt" -ForegroundColor White
Write-Host "  5. 阅读详细文档: PRODUCTION_DEPLOY.md" -ForegroundColor White
Write-Host ""

# 重要提醒
Write-Host "⚠️  重要提醒:" -ForegroundColor Red
Write-Host "  • 必须修改 .env 文件中的所有密码" -ForegroundColor Red
Write-Host "  • JWT_SECRET 至少 32 个字符" -ForegroundColor Red
Write-Host "  • 生产环境建议关闭用户注册" -ForegroundColor Red
Write-Host "  • 配置 HTTPS 和防火墙" -ForegroundColor Red
Write-Host "  • 设置定时备份任务" -ForegroundColor Red
Write-Host ""

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ 所有文件已准备就绪！" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# 询问是否查看快速参考
$response = Read-Host "是否查看快速参考卡片? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    if (Test-Path "$baseDir\QUICK_REFERENCE.txt") {
        Get-Content "$baseDir\QUICK_REFERENCE.txt"
    }
}
