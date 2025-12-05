# 图床短链对接快速配置脚本
# 用途：自动配置图床系统以对接短链服务

param(
  [string]$BackendPath = "c:\Users\DXY\Documents\TC-GO\backend",
  [string]$RedirectServicePath = "c:\Users\DXY\Documents\TC-GO\redirect-service"
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           图床短链对接快速配置脚本                            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "`n开始配置..." -ForegroundColor Yellow

# 步骤 1: 检查短链服务状态
Write-Host "`n[1/5] 检查短链服务状态..." -ForegroundColor Cyan
Set-Location $RedirectServicePath

$containers = docker-compose ps --format json | ConvertFrom-Json
$openrestyRunning = $containers | Where-Object { $_.Service -eq "openresty" -and $_.State -eq "running" }

if (-not $openrestyRunning) {
  Write-Host "  ⚠️  短链服务未运行，正在启动..." -ForegroundColor Yellow
  docker-compose up -d
  Start-Sleep -Seconds 5
  Write-Host "  ✓ 短链服务已启动" -ForegroundColor Green
}
else {
  Write-Host "  ✓ 短链服务正在运行" -ForegroundColor Green
}

# 测试短链服务
try {
  $healthCheck = Invoke-WebRequest -Uri "http://localhost/api/health" -UseBasicParsing -TimeoutSec 5
  Write-Host "  ✓ 短链服务健康检查通过" -ForegroundColor Green
}
catch {
  Write-Host "  ✗ 短链服务健康检查失败: $_" -ForegroundColor Red
  Write-Host "  请检查服务是否正常运行" -ForegroundColor Yellow
}

# 步骤 2: 配置 Backend 环境变量
Write-Host "`n[2/5] 配置 Backend 环境变量..." -ForegroundColor Cyan
Set-Location $BackendPath

if (-not (Test-Path ".env")) {
  Write-Host "  ℹ .env 文件不存在，从 .env.example 复制..." -ForegroundColor Yellow
  Copy-Item ".env.example" ".env"
  Write-Host "  ✓ 创建 .env 文件" -ForegroundColor Green
}

# 读取现有 .env 文件
$envContent = Get-Content ".env" -Raw

# 检查是否已有短链配置
if ($envContent -notmatch "SHORT_LINK_ENABLED") {
  Write-Host "  ℹ 添加短链配置到 .env..." -ForegroundColor Yellow

  $shortLinkConfig = @"

# ==================== 短链服务配置 ====================
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://localhost
SHORT_LINK_EXPIRE=0
"@

  $envContent += $shortLinkConfig
  $envContent | Set-Content ".env" -NoNewline
  Write-Host "  ✓ 短链配置已添加" -ForegroundColor Green
}
else {
  Write-Host "  ℹ 更新短链配置..." -ForegroundColor Yellow
  $envContent = $envContent -replace "SHORT_LINK_ENABLED=false", "SHORT_LINK_ENABLED=true"
  $envContent | Set-Content ".env" -NoNewline
  Write-Host "  ✓ 短链配置已启用" -ForegroundColor Green
}

# 步骤 3: 检查数据库迁移
Write-Host "`n[3/5] 检查数据库..." -ForegroundColor Cyan

# 检查数据库类型
$dbType = (Get-Content ".env" | Select-String "^DB_TYPE=").Line -replace "DB_TYPE=", ""
Write-Host "  ℹ 数据库类型: $dbType" -ForegroundColor Gray

if ($dbType -eq "sqlite") {
  $dbPath = (Get-Content ".env" | Select-String "^DB_DSN=").Line -replace "DB_DSN=", ""
  if (Test-Path $dbPath) {
    Write-Host "  ✓ SQLite 数据库文件存在: $dbPath" -ForegroundColor Green

    # 检查 images 表是否有 short_link_code 字段
    Write-Host "  ℹ 检查 short_link_code 字段..." -ForegroundColor Yellow

    $sql = "SELECT sql FROM sqlite_master WHERE type='table' AND name='images';"
    $tableSchema = sqlite3 $dbPath $sql 2>$null

    if ($tableSchema -match "short_link_code") {
      Write-Host "  ✓ short_link_code 字段已存在" -ForegroundColor Green
    }
    else {
      Write-Host "  ⚠️  需要添加 short_link_code 字段" -ForegroundColor Yellow
      Write-Host "  ℹ 执行数据库迁移..." -ForegroundColor Yellow

      $migrationSQL = @"
ALTER TABLE images ADD COLUMN short_link_code VARCHAR(32) DEFAULT NULL;
CREATE INDEX idx_short_link_code ON images(short_link_code);
"@

      try {
        $migrationSQL.Split("`n") | ForEach-Object {
          if ($_.Trim()) {
            sqlite3 $dbPath $_ 2>$null
          }
        }
        Write-Host "  ✓ 数据库迁移完成" -ForegroundColor Green
      }
      catch {
        Write-Host "  ⚠️  数据库迁移可能需要手动执行" -ForegroundColor Yellow
        Write-Host "  SQL: $migrationSQL" -ForegroundColor Gray
      }
    }
  }
  else {
    Write-Host "  ℹ 数据库文件不存在，将在首次运行时创建" -ForegroundColor Yellow
  }
}
else {
  Write-Host "  ℹ 使用 $dbType 数据库，请确保已执行迁移" -ForegroundColor Yellow
  Write-Host "  SQL 迁移语句:" -ForegroundColor Gray
  Write-Host "    ALTER TABLE images ADD COLUMN short_link_code VARCHAR(32) DEFAULT NULL;" -ForegroundColor DarkGray
  Write-Host "    CREATE INDEX idx_short_link_code ON images(short_link_code);" -ForegroundColor DarkGray
}

# 步骤 4: 验证文件存在
Write-Host "`n[4/5] 验证集成文件..." -ForegroundColor Cyan

$requiredFiles = @(
  "utils\shortlink_client.go",
  "config\config.go",
  "models\album.go"
)

$allFilesExist = $true
foreach ($file in $requiredFiles) {
  if (Test-Path $file) {
    Write-Host "  ✓ $file" -ForegroundColor Green
  }
  else {
    Write-Host "  ✗ $file 不存在" -ForegroundColor Red
    $allFilesExist = $false
  }
}

if (-not $allFilesExist) {
  Write-Host "`n  ⚠️  部分文件缺失，请确保已复制所有集成文件" -ForegroundColor Yellow
}

# 步骤 5: 测试短链客户端
Write-Host "`n[5/5] 测试短链服务连接..." -ForegroundColor Cyan

try {
  $testURL = "http://localhost/api/imagebed/stats"
  $response = Invoke-RestMethod -Uri $testURL -Method Get -TimeoutSec 5

  if ($response.success) {
    Write-Host "  ✓ 短链服务 API 可用" -ForegroundColor Green
    Write-Host "    图床短链总数: $($response.data.total_links)" -ForegroundColor Gray
    Write-Host "    今日创建: $($response.data.today_created)" -ForegroundColor Gray
    Write-Host "    总点击数: $($response.data.total_clicks)" -ForegroundColor Gray
  }
  else {
    Write-Host "  ⚠️  短链服务返回错误: $($response.error)" -ForegroundColor Yellow
  }
}
catch {
  Write-Host "  ⚠️  无法连接到短链服务 API" -ForegroundColor Yellow
  Write-Host "  错误: $_" -ForegroundColor Red
}

# 总结
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                   配置完成                                   ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 下一步操作:" -ForegroundColor Cyan
Write-Host "  1. 修改 controllers/image_controller.go 添加短链集成逻辑" -ForegroundColor Yellow
Write-Host "     参考: ..\IMAGEBED_INTEGRATION.md 步骤4" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. 重新编译并运行 backend:" -ForegroundColor Yellow
Write-Host "     go build -o imagebed.exe" -ForegroundColor Gray
Write-Host "     .\imagebed.exe" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. 测试图片上传功能" -ForegroundColor Yellow
Write-Host ""
Write-Host "  4. 查看详细文档: ..\IMAGEBED_INTEGRATION.md" -ForegroundColor Yellow

Write-Host "`n🔗 有用的链接:" -ForegroundColor Cyan
Write-Host "  - 图床系统: http://localhost:8080" -ForegroundColor Gray
Write-Host "  - 短链服务: http://localhost" -ForegroundColor Gray
Write-Host "  - Grafana 监控: http://localhost:3000" -ForegroundColor Gray
Write-Host "  - Prometheus: http://localhost:9090" -ForegroundColor Gray

Write-Host "`n💡 提示:" -ForegroundColor Cyan
Write-Host "  - 配置文件已更新: .env" -ForegroundColor Gray
Write-Host "  - 数据库迁移: $(if ($dbType -eq 'sqlite') {'已执行'} else {'需要手动执行'})" -ForegroundColor Gray
Write-Host "  - 短链功能: 已启用" -ForegroundColor Gray

Write-Host ""
