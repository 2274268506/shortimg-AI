# 简单性能测试脚本（使用 PowerShell）
# 不依赖外部工具，适用于快速测试

param(
  [string]$BaseUrl = "http://localhost",
  [string]$ApiKey = "sk_test_12345678901234567890123456789012",
  [int]$Requests = 1000,
  [int]$Threads = 10
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "短链服务性能快速测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "测试配置:" -ForegroundColor Yellow
Write-Host "  BASE_URL: $BaseUrl"
Write-Host "  请求数: $Requests"
Write-Host "  并发线程: $Threads"
Write-Host ""

# 创建测试短链
Write-Host "准备测试数据..." -ForegroundColor Yellow
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
  Write-Host "✅ 测试短链准备完成" -ForegroundColor Green
}
catch {
  Write-Host "⚠️  短链可能已存在" -ForegroundColor Yellow
}

Write-Host ""

# 性能测试函数
function Test-Performance {
  param(
    [string]$Url,
    [int]$Count,
    [hashtable]$Headers = @{}
  )

  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  $errors = 0
  $responseTimes = @()

  # 使用 Runspace Pool 实现并发
  $runspacePool = [runspacefactory]::CreateRunspacePool(1, $Threads)
  $runspacePool.Open()
  $jobs = @()

  for ($i = 0; $i -lt $Count; $i++) {
    $powershell = [powershell]::Create().AddScript({
        param($url, $headers)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
          $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -ErrorAction Stop
          $sw.Stop()
          return @{
            Success    = $true
            Duration   = $sw.ElapsedMilliseconds
            StatusCode = $response.StatusCode
          }
        }
        catch {
          $sw.Stop()
          return @{
            Success  = $false
            Duration = $sw.ElapsedMilliseconds
            Error    = $_.Exception.Message
          }
        }
      }).AddArgument($Url).AddArgument($Headers)

    $powershell.RunspacePool = $runspacePool
    $jobs += @{
      Pipe   = $powershell
      Handle = $powershell.BeginInvoke()
    }
  }

  # 等待所有请求完成
  $results = @()
  foreach ($job in $jobs) {
    $result = $job.Pipe.EndInvoke($job.Handle)
    $results += $result
    $job.Pipe.Dispose()

    if (-not $result.Success) {
      $errors++
    }
    if ($result.Duration) {
      $responseTimes += $result.Duration
    }
  }

  $runspacePool.Close()
  $runspacePool.Dispose()

  $stopwatch.Stop()
  $totalTime = $stopwatch.Elapsed.TotalSeconds

  # 计算统计数据
  $qps = [math]::Round($Count / $totalTime, 2)
  $avgTime = if ($responseTimes.Count -gt 0) {
    [math]::Round(($responseTimes | Measure-Object -Average).Average, 2)
  }
  else { 0 }

  $sorted = $responseTimes | Sort-Object
  $p50 = if ($sorted.Count -gt 0) { $sorted[[math]::Floor($sorted.Count * 0.5)] } else { 0 }
  $p95 = if ($sorted.Count -gt 0) { $sorted[[math]::Floor($sorted.Count * 0.95)] } else { 0 }
  $p99 = if ($sorted.Count -gt 0) { $sorted[[math]::Floor($sorted.Count * 0.99)] } else { 0 }

  return @{
    TotalRequests = $Count
    TotalTime     = [math]::Round($totalTime, 2)
    QPS           = $qps
    AvgTime       = $avgTime
    P50           = $p50
    P95           = $p95
    P99           = $p99
    Errors        = $errors
    ErrorRate     = [math]::Round(($errors / $Count) * 100, 2)
  }
}

# 1. 健康检查测试
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. 健康检查 API (/health)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$result = Test-Performance -Url "$BaseUrl/health" -Count $Requests
Write-Host "总请求数: $($result.TotalRequests)" -ForegroundColor White
Write-Host "总耗时: $($result.TotalTime) 秒" -ForegroundColor White
Write-Host "QPS: $($result.QPS) req/s" -ForegroundColor $(if ($result.QPS -gt 500) { "Green" } else { "Yellow" })
Write-Host "平均响应时间: $($result.AvgTime) ms" -ForegroundColor White
Write-Host "P50: $($result.P50) ms | P95: $($result.P95) ms | P99: $($result.P99) ms" -ForegroundColor White
Write-Host "错误数: $($result.Errors) ($($result.ErrorRate)%)" -ForegroundColor $(if ($result.Errors -eq 0) { "Green" } else { "Red" })
Write-Host ""

Start-Sleep -Seconds 2

# 2. 短链重定向测试
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "2. 短链重定向 API (/r/perf_test)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$result = Test-Performance -Url "$BaseUrl/r/perf_test" -Count $Requests
Write-Host "总请求数: $($result.TotalRequests)" -ForegroundColor White
Write-Host "总耗时: $($result.TotalTime) 秒" -ForegroundColor White
Write-Host "QPS: $($result.QPS) req/s" -ForegroundColor $(if ($result.QPS -gt 300) { "Green" } else { "Yellow" })
Write-Host "平均响应时间: $($result.AvgTime) ms" -ForegroundColor White
Write-Host "P50: $($result.P50) ms | P95: $($result.P95) ms | P99: $($result.P99) ms" -ForegroundColor White
Write-Host "错误数: $($result.Errors) ($($result.ErrorRate)%)" -ForegroundColor $(if ($result.Errors -eq 0) { "Green" } else { "Red" })
Write-Host ""

Start-Sleep -Seconds 2

# 3. API 查询测试
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "3. 短链查询 API" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$result = Test-Performance -Url "$BaseUrl/api/v1/links/perf_test" -Count $Requests -Headers @{"X-API-Key" = $ApiKey }
Write-Host "总请求数: $($result.TotalRequests)" -ForegroundColor White
Write-Host "总耗时: $($result.TotalTime) 秒" -ForegroundColor White
Write-Host "QPS: $($result.QPS) req/s" -ForegroundColor $(if ($result.QPS -gt 200) { "Green" } else { "Yellow" })
Write-Host "平均响应时间: $($result.AvgTime) ms" -ForegroundColor White
Write-Host "P50: $($result.P50) ms | P95: $($result.P95) ms | P99: $($result.P99) ms" -ForegroundColor White
Write-Host "错误数: $($result.Errors) ($($result.ErrorRate)%)" -ForegroundColor $(if ($result.Errors -eq 0) { "Green" } else { "Red" })
Write-Host ""

# 清理
Write-Host "清理测试数据..." -ForegroundColor Yellow
try {
  Invoke-RestMethod -Uri "$BaseUrl/api/v1/links/perf_test" -Method DELETE `
    -Headers @{"X-API-Key" = $ApiKey } -ErrorAction SilentlyContinue | Out-Null
  Write-Host "✅ 清理完成" -ForegroundColor Green
}
catch {
  Write-Host "⚠️  清理失败（可忽略）" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "性能测试完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 提示：" -ForegroundColor Yellow
Write-Host "  - 这是简化版测试，建议使用 wrk 或 ab 进行更准确的压测"
Write-Host "  - 增加并发数和请求数可以获得更接近真实场景的结果"
Write-Host "  - 运行前请确保系统资源充足"
Write-Host ""
