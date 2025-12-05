# 测试环境准备脚本

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "短链服务测试环境准备" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 1. 检查 Docker Desktop
Write-Host "[1/6] 检查 Docker Desktop..." -ForegroundColor Yellow
$dockerRunning = $false
try {
  $null = docker ps 2>$null
  $dockerRunning = $true
  Write-Host "✅ Docker Desktop 正在运行" -ForegroundColor Green
}
catch {
  Write-Host "❌ Docker Desktop 未运行" -ForegroundColor Red
  Write-Host "请先启动 Docker Desktop，然后重新运行此脚本" -ForegroundColor Yellow
  Write-Host "启动后等待 Docker 图标显示为绿色" -ForegroundColor Yellow
  exit 1
}

# 2. 检查 .env 文件
Write-Host "`n[2/6] 检查环境变量文件..." -ForegroundColor Yellow
if (-not (Test-Path ".env")) {
  if (Test-Path ".env.example") {
    Copy-Item ".env.example" ".env"
    Write-Host "✅ 已从模板创建 .env 文件" -ForegroundColor Green
  }
  else {
    Write-Host "❌ 未找到 .env.example 文件" -ForegroundColor Red
    exit 1
  }
}
else {
  Write-Host "✅ .env 文件已存在" -ForegroundColor Green
}

# 3. 检查必要文件
Write-Host "`n[3/6] 检查必要文件..." -ForegroundColor Yellow
$requiredFiles = @(
  "docker-compose.yml",
  "conf/nginx.conf",
  "sql/schema.sql"
)

$allFilesExist = $true
foreach ($file in $requiredFiles) {
  if (Test-Path $file) {
    Write-Host "  ✓ $file" -ForegroundColor Gray
  }
  else {
    Write-Host "  ✗ $file 缺失" -ForegroundColor Red
    $allFilesExist = $false
  }
}

if ($allFilesExist) {
  Write-Host "✅ 所有必要文件完整" -ForegroundColor Green
}
else {
  Write-Host "❌ 缺少必要文件" -ForegroundColor Red
  exit 1
}

# 4. 启动服务
Write-Host "`n[4/6] 启动 Docker 服务..." -ForegroundColor Yellow
Write-Host "这可能需要几分钟时间..." -ForegroundColor Gray

try {
  docker-compose up -d 2>&1 | Out-Null
  Write-Host "✅ Docker 服务已启动" -ForegroundColor Green
}
catch {
  Write-Host "❌ 服务启动失败: $_" -ForegroundColor Red
  exit 1
}

# 5. 等待服务就绪
Write-Host "`n[5/6] 等待服务就绪..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$serviceReady = $false

while ($attempt -lt $maxAttempts -and -not $serviceReady) {
  $attempt++
  Write-Host "  尝试 $attempt/$maxAttempts..." -ForegroundColor Gray

  try {
    $response = Invoke-WebRequest -Uri "http://localhost/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200) {
      $serviceReady = $true
      Write-Host "✅ 服务已就绪" -ForegroundColor Green
    }
  }
  catch {
    Start-Sleep -Seconds 2
  }
}

if (-not $serviceReady) {
  Write-Host "❌ 服务启动超时" -ForegroundColor Red
  Write-Host "请运行以下命令查看日志：" -ForegroundColor Yellow
  Write-Host "  docker-compose logs" -ForegroundColor Cyan
  exit 1
}

# 6. 创建测试用 API Key
Write-Host "`n[6/6] 创建测试用 API Key..." -ForegroundColor Yellow

# 等待 OpenResty 容器完全启动
Start-Sleep -Seconds 5

try {
  $apiKeyOutput = docker exec short-link-openresty lua /usr/local/openresty/nginx/tools/manage_api_keys.lua create "测试用Key" "*" 0 2>&1

  # 提取 API Key
  $apiKey = $apiKeyOutput | Select-String -Pattern "Key: (sk_[a-f0-9]+)" | ForEach-Object { $_.Matches.Groups[1].Value }

  if ($apiKey) {
    Write-Host "✅ API Key 创建成功" -ForegroundColor Green
    Write-Host "`n" + "="*50 -ForegroundColor Cyan
    Write-Host "API Key: $apiKey" -ForegroundColor Yellow
    Write-Host "="*50 -ForegroundColor Cyan

    # 保存到环境变量
    $env:API_KEY = $apiKey

    # 保存到文件供后续使用
    $apiKey | Out-File -FilePath ".api_key" -Encoding UTF8

    Write-Host "`n请妥善保管此 API Key，已保存到 .api_key 文件" -ForegroundColor Gray
  }
  else {
    Write-Host "⚠️  API Key 创建可能失败，请手动创建" -ForegroundColor Yellow
    Write-Host "命令: docker exec -it short-link-openresty lua /usr/local/openresty/nginx/tools/manage_api_keys.lua create 'Test'" -ForegroundColor Cyan
  }
}
catch {
  Write-Host "⚠️  无法自动创建 API Key: $_" -ForegroundColor Yellow
  Write-Host "请手动创建 API Key" -ForegroundColor Yellow
}

# 完成
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "环境准备完成！" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "下一步操作：" -ForegroundColor Cyan
Write-Host "1. 运行完整测试：" -ForegroundColor White
Write-Host "   .\tests\integration\test_all.ps1 -ApiKey `"$apiKey`"`n" -ForegroundColor Gray

Write-Host "2. 访问 Web 管理界面：" -ForegroundColor White
Write-Host "   http://localhost/dashboard/`n" -ForegroundColor Gray

Write-Host "3. 查看服务日志：" -ForegroundColor White
Write-Host "   docker-compose logs -f`n" -ForegroundColor Gray

Write-Host "4. 停止服务：" -ForegroundColor White
Write-Host "   docker-compose down`n" -ForegroundColor Gray
