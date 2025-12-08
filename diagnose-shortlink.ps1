# 短链生成诊断脚本

Write-Host "================================" -ForegroundColor Cyan
Write-Host "短链生成问题诊断" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查后端配置
Write-Host "[1] 检查后端配置" -ForegroundColor Yellow
Write-Host ""

$backendRunning = $false
$backendUrl = "http://localhost:8080"

try {
  $health = Invoke-RestMethod -Uri "$backendUrl/health" -TimeoutSec 3 -ErrorAction Stop
  Write-Host "  ✅ 后端运行中: $backendUrl" -ForegroundColor Green
  $backendRunning = $true
}
catch {
  Write-Host "  ❌ 后端未运行" -ForegroundColor Red
  Write-Host "     请启动后端: cd backend && go run main.go" -ForegroundColor Yellow
}

Write-Host ""

# 2. 检查重定向服务
Write-Host "[2] 检查重定向服务" -ForegroundColor Yellow
Write-Host ""

$redirectServiceUrl = "http://localhost:8081"
$redirectRunning = $false

try {
  $health = Invoke-RestMethod -Uri "$redirectServiceUrl/health" -TimeoutSec 3 -ErrorAction Stop
  Write-Host "  ✅ 重定向服务运行中: $redirectServiceUrl" -ForegroundColor Green
  $redirectRunning = $true
}
catch {
  Write-Host "  ❌ 重定向服务未运行" -ForegroundColor Red
  Write-Host "     请启动服务: cd redirect-service && docker-compose up -d" -ForegroundColor Yellow
}

Write-Host ""

if (-not $backendRunning -or -not $redirectRunning) {
  Write-Host "⚠️  请先启动所有必需的服务" -ForegroundColor Yellow
  exit 1
}

# 3. 测试 V2 API 连通性
Write-Host "[3] 测试 V2 API 连通性" -ForegroundColor Yellow
Write-Host ""

try {
  $testData = @{
    image_path         = "/test/image.jpg"
    enable_geo_routing = $false
  } | ConvertTo-Json

  $response = Invoke-RestMethod `
    -Uri "$redirectServiceUrl/api/v2/imagebed/create" `
    -Method POST `
    -ContentType "application/json" `
    -Body $testData `
    -TimeoutSec 5 `
    -ErrorAction Stop

  if ($response.success) {
    Write-Host "  ✅ V2 API 工作正常" -ForegroundColor Green
    Write-Host "     短链码: $($response.data.code)" -ForegroundColor Gray
    Write-Host "     短链URL: $($response.data.short_url)" -ForegroundColor Gray
  }
  else {
    Write-Host "  ❌ V2 API 返回错误: $($response.error)" -ForegroundColor Red
  }
}
catch {
  Write-Host "  ❌ 无法连接到 V2 API" -ForegroundColor Red
  Write-Host "     错误: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 4. 检查后端配置值
Write-Host "[4] 检查后端配置" -ForegroundColor Yellow
Write-Host ""

Write-Host "  当前配置修改:" -ForegroundColor Cyan
Write-Host "  • SHORT_LINK_ENABLED: true (默认)" -ForegroundColor Green
Write-Host "  • SHORT_LINK_BASE_URL: http://localhost:8081 (默认)" -ForegroundColor Green
Write-Host "  • SHORT_LINK_API_KEY: (空)" -ForegroundColor Gray
Write-Host ""
Write-Host "  如需自定义，可创建 backend/.env 文件:" -ForegroundColor Gray
Write-Host "  SHORT_LINK_BASE_URL=http://localhost:8081" -ForegroundColor Gray
Write-Host "  SHORT_LINK_ENABLED=true" -ForegroundColor Gray
Write-Host ""

# 5. 检查相册短链配置
Write-Host "[5] 相册短链配置检查" -ForegroundColor Yellow
Write-Host ""
Write-Host "  请登录前端检查相册设置:" -ForegroundColor White
Write-Host "  1. 进入「相册管理」" -ForegroundColor Gray
Write-Host "  2. 点击相册的「编辑」按钮" -ForegroundColor Gray
Write-Host "  3. 查看「启用短链」选项是否勾选" -ForegroundColor Gray
Write-Host ""

# 6. 上传测试指南
Write-Host "[6] 批量上传测试步骤" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. 打开前端: http://localhost:5173" -ForegroundColor White
Write-Host "  2. 登录（用户名: admin）" -ForegroundColor White
Write-Host "  3. 点击「上传图片」按钮" -ForegroundColor White
Write-Host "  4. ✅ 勾选「生成短链」选项" -ForegroundColor Green
Write-Host "  5. 选择图片并上传" -ForegroundColor White
Write-Host "  6. 查看上传结果" -ForegroundColor White
Write-Host ""

# 7. 问题排查清单
Write-Host "[7] 问题排查清单" -ForegroundColor Yellow
Write-Host ""
Write-Host "  如果仍然无法生成短链，请检查:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  □ 后端是否重启？(需要重启以加载新配置)" -ForegroundColor White
Write-Host "    → 停止当前后端，重新运行 go run main.go" -ForegroundColor Gray
Write-Host ""
Write-Host "  □ 上传时是否勾选了「生成短链」？" -ForegroundColor White
Write-Host "    → 查看上传对话框中的复选框" -ForegroundColor Gray
Write-Host ""
Write-Host "  □ 相册是否启用了短链？" -ForegroundColor White
Write-Host "    → 编辑相册，检查「启用短链」设置" -ForegroundColor Gray
Write-Host ""
Write-Host "  □ 查看后端控制台输出" -ForegroundColor White
Write-Host "    → 应该看到「批量上传调试」相关日志" -ForegroundColor Gray
Write-Host "    → 检查 generateShortLink 的值" -ForegroundColor Gray
Write-Host ""

# 8. 查看日志命令
Write-Host "[8] 实时查看日志" -ForegroundColor Yellow
Write-Host ""
Write-Host "  在后端运行的终端窗口中观察输出" -ForegroundColor White
Write-Host "  应该看到类似以下日志:" -ForegroundColor Gray
Write-Host @"
  ========== 批量上传调试 ==========
  请求参数 enableShortLink: true
  相册 EnableShortLink: true
  使用请求参数，generateShortLink: true
  准备生成短链: generateShortLink=true, shortLinkImages数量=1
  开始批量生成短链...
  批量生成短链成功，返回结果数量: 1
"@ -ForegroundColor DarkGray

Write-Host ""

Write-Host "================================" -ForegroundColor Cyan
Write-Host "诊断完成" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  重要提示：修改配置后必须重启后端服务！" -ForegroundColor Yellow
Write-Host ""
