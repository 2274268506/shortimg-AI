# 短链功能快速测试脚本

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "  短链功能快速测试" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 检查配置
Write-Host "📋 检查配置文件..." -ForegroundColor Yellow
Write-Host ""

$envFile = "backend\.env"
if (Test-Path $envFile) {
  $shortLinkEnabled = Select-String -Path $envFile -Pattern "SHORT_LINK_ENABLED=(.+)" | ForEach-Object { $_.Matches.Groups[1].Value }
  $shortLinkBaseURL = Select-String -Path $envFile -Pattern "SHORT_LINK_BASE_URL=(.+)" | ForEach-Object { $_.Matches.Groups[1].Value }

  Write-Host "  SHORT_LINK_ENABLED: " -NoNewline
  if ($shortLinkEnabled -eq "true") {
    Write-Host $shortLinkEnabled -ForegroundColor Green
  }
  else {
    Write-Host $shortLinkEnabled -ForegroundColor Red
  }

  Write-Host "  SHORT_LINK_BASE_URL: " -NoNewline
  if ($shortLinkBaseURL -eq "http://localhost:8081") {
    Write-Host $shortLinkBaseURL -ForegroundColor Green
  }
  elseif ($shortLinkBaseURL) {
    Write-Host $shortLinkBaseURL -ForegroundColor Yellow
  }
  else {
    Write-Host "(未配置)" -ForegroundColor Red
  }
}
else {
  Write-Host "  ❌ .env 文件不存在" -ForegroundColor Red
}

Write-Host ""

# 检查服务状态
Write-Host "🔍 检查服务状态..." -ForegroundColor Yellow
Write-Host ""

$backendRunning = $false
try {
  $null = Invoke-RestMethod -Uri "http://localhost:8080/health" -TimeoutSec 2 -ErrorAction Stop
  Write-Host "  ✅ 后端服务运行中 (http://localhost:8080)" -ForegroundColor Green
  $backendRunning = $true
}
catch {
  Write-Host "  ❌ 后端服务未运行" -ForegroundColor Red
  Write-Host "     → 请运行: cd backend && go run main.go" -ForegroundColor Yellow
}

$redirectRunning = $false
try {
  $null = Invoke-RestMethod -Uri "http://localhost:8081/health" -TimeoutSec 2 -ErrorAction Stop
  Write-Host "  ✅ 重定向服务运行中 (http://localhost:8081)" -ForegroundColor Green
  $redirectRunning = $true
}
catch {
  Write-Host "  ❌ 重定向服务未运行" -ForegroundColor Red
  Write-Host "     → 请运行: cd redirect-service && docker-compose up -d" -ForegroundColor Yellow
}

Write-Host ""

if (-not $backendRunning -or -not $redirectRunning) {
  Write-Host "⚠️  请启动所有必需的服务后再测试" -ForegroundColor Yellow
  Write-Host ""
  exit 1
}

# 测试 V2 API
Write-Host "🧪 测试 V2 短链 API..." -ForegroundColor Yellow
Write-Host ""

try {
  $testData = @{
    image_path         = "/uploads/test.jpg"
    enable_geo_routing = $false
  } | ConvertTo-Json

  $response = Invoke-RestMethod `
    -Uri "http://localhost:8081/api/v2/imagebed/create" `
    -Method POST `
    -ContentType "application/json" `
    -Body $testData `
    -TimeoutSec 5

  if ($response.success) {
    Write-Host "  ✅ V2 API 工作正常" -ForegroundColor Green
    Write-Host "     短链码: $($response.data.code)" -ForegroundColor White
    Write-Host "     短链URL: $($response.data.short_url)" -ForegroundColor White
    Write-Host "     CDN节点: $($response.data.targets_count) 个" -ForegroundColor White
  }
  else {
    Write-Host "  ❌ API 返回错误: $($response.error)" -ForegroundColor Red
  }
}
catch {
  Write-Host "  ❌ 调用失败: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  重要提示:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. 配置已修改，请重启后端服务！" -ForegroundColor White
Write-Host "     → 在后端终端按 Ctrl+C" -ForegroundColor Gray
Write-Host "     → 重新运行: go run main.go" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. 上传测试步骤:" -ForegroundColor White
Write-Host "     → 打开前端: http://localhost:5173" -ForegroundColor Gray
Write-Host "     → 登录系统" -ForegroundColor Gray
Write-Host "     → 点击「上传图片」" -ForegroundColor Gray
Write-Host "     → ✅ 勾选「生成短链」" -ForegroundColor Green
Write-Host "     → 上传图片" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. 验证结果:" -ForegroundColor White
Write-Host "     → 查看图片是否有短链图标" -ForegroundColor Gray
Write-Host "     → 短链URL应为: http://localhost:8081/..." -ForegroundColor Gray
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
