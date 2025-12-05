# 短链服务性能基准测试
# 使用 Apache Bench (ab) 进行压力测试

param(
  [string]$BaseUrl = "http://localhost",
  [string]$ApiKey = "sk_test_12345678901234567890123456789012",
  [int]$Concurrency = 100,
  [int]$Requests = 10000
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "短链服务性能基准测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "测试配置:" -ForegroundColor Yellow
Write-Host "  BASE_URL: $BaseUrl"
Write-Host "  并发数: $Concurrency"
Write-Host "  请求数: $Requests"
Write-Host ""

# 检查是否安装了 ab
$abPath = Get-Command ab -ErrorAction SilentlyContinue
if (-not $abPath) {
  Write-Host "❌ Apache Bench (ab) 未安装" -ForegroundColor Red
  Write-Host ""
  Write-Host "请安装 Apache Bench:" -ForegroundColor Yellow
  Write-Host "  Windows: 下载 Apache HTTP Server 或使用 chocolatey"
  Write-Host "    choco install apache-httpd"
  Write-Host "  Linux: sudo apt-get install apache2-utils"
  Write-Host "  macOS: brew install apr-util"
  Write-Host ""
  Write-Host "或者使用 wrk 作为替代:" -ForegroundColor Yellow
  Write-Host "  https://github.com/wg/wrk"
  exit 1
}

# 1. 健康检查性能测试
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. 健康检查 API (/health)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
ab -n $Requests -c $Concurrency "$BaseUrl/health"

Start-Sleep -Seconds 2

# 2. 短链重定向性能测试（核心功能）
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "2. 短链重定向 API (/r/test)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 先创建一个测试短链
Write-Host "创建测试短链..." -ForegroundColor Yellow
$createBody = @{
  short_code = "perf_test"
  targets    = @(
    @{
      url    = "https://www.example.com"
      weight = 100
    }
  )
  strategy   = "round_robin"
} | ConvertTo-Json

try {
  Invoke-RestMethod -Uri "$BaseUrl/api/v1/links" -Method POST `
    -Headers @{"X-API-Key" = $ApiKey; "Content-Type" = "application/json" } `
    -Body $createBody -ErrorAction SilentlyContinue | Out-Null
  Write-Host "✅ 测试短链创建成功" -ForegroundColor Green
}
catch {
  Write-Host "⚠️  短链可能已存在" -ForegroundColor Yellow
}

Start-Sleep -Seconds 1

# 测试重定向性能
ab -n $Requests -c $Concurrency "$BaseUrl/r/perf_test"

Start-Sleep -Seconds 2

# 3. API 查询性能测试
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "3. 短链查询 API (/api/v1/links/perf_test)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
ab -n $Requests -c $Concurrency -H "X-API-Key: $ApiKey" "$BaseUrl/api/v1/links/perf_test"

# 4. 统计 API 性能测试
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "4. 统计总览 API (/api/v1/stats/overview)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
ab -n 1000 -c 50 -H "X-API-Key: $ApiKey" "$BaseUrl/api/v1/stats/overview"

# 清理测试数据
Write-Host ""
Write-Host "清理测试数据..." -ForegroundColor Yellow
try {
  Invoke-RestMethod -Uri "$BaseUrl/api/v1/links/perf_test" -Method DELETE `
    -Headers @{"X-API-Key" = $ApiKey } -ErrorAction SilentlyContinue | Out-Null
  Write-Host "✅ 测试数据清理完成" -ForegroundColor Green
}
catch {
  Write-Host "⚠️  清理失败（可忽略）" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "性能测试完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "关键指标说明:" -ForegroundColor Yellow
Write-Host "  - Requests per second: 每秒处理请求数（越高越好）"
Write-Host "  - Time per request: 平均响应时间（越低越好）"
Write-Host "  - Transfer rate: 数据传输速率"
Write-Host "  - Failed requests: 失败请求数（应为0）"
Write-Host ""
Write-Host "性能目标:" -ForegroundColor Green
Write-Host "  ✓ 健康检查: 20000+ req/s"
Write-Host "  ✓ 重定向: 10000+ req/s"
Write-Host "  ✓ API查询: 5000+ req/s"
Write-Host "  ✓ P99延迟: < 50ms"
Write-Host ""
