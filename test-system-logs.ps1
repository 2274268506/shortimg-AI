# 系统日志功能测试脚本

Write-Host "=== 系统日志功能测试 ===" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:8080/api"

# 1. 登录获取token
Write-Host "1. 登录..." -ForegroundColor Yellow
$loginBody = @{
  username = "admin"
  password = "admin123"
} | ConvertTo-Json

try {
  $loginResponse = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body $loginBody
  $token = $loginResponse.data.token
  Write-Host "  ✓ 登录成功" -ForegroundColor Green
  Write-Host ""
}
catch {
  Write-Host "  ✗ 登录失败: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

$headers = @{
  "Authorization" = "Bearer $token"
}

# 2. 触发一个404错误（会记录warn级别日志）
Write-Host "2. 触发404错误..." -ForegroundColor Yellow
try {
  Invoke-RestMethod -Uri "$baseUrl/nonexistent-endpoint" -Headers $headers -ErrorAction Stop
}
catch {
  Write-Host "  ✓ 404错误已触发" -ForegroundColor Green
}
Start-Sleep -Milliseconds 500

# 3. 触发一个401错误（未授权）
Write-Host "3. 触发401错误..." -ForegroundColor Yellow
try {
  Invoke-RestMethod -Uri "$baseUrl/users" -Headers @{"Authorization" = "Bearer invalid_token" } -ErrorAction Stop
}
catch {
  Write-Host "  ✓ 401错误已触发" -ForegroundColor Green
}
Start-Sleep -Milliseconds 500

# 4. 查询系统日志
Write-Host ""
Write-Host "4. 查询系统日志..." -ForegroundColor Yellow
try {
  $logsResponse = Invoke-RestMethod -Uri "$baseUrl/logs/system?page=1&pageSize=20" -Headers $headers
  $logs = $logsResponse.data
  $total = $logsResponse.pagination.total

  Write-Host "  总记录数: $total" -ForegroundColor Cyan
  Write-Host ""

  if ($logs.Count -gt 0) {
    Write-Host "  最近的系统日志:" -ForegroundColor Cyan
    Write-Host "  " + ("-" * 120) -ForegroundColor Gray

    foreach ($log in $logs | Select-Object -First 10) {
      $levelColor = switch ($log.level) {
        "error" { "Red" }
        "warn" { "Yellow" }
        "info" { "Cyan" }
        "debug" { "Gray" }
        default { "White" }
      }

      $icon = switch ($log.level) {
        "error" { "✗" }
        "warn" { "⚠" }
        "info" { "ℹ" }
        "debug" { "•" }
        default { "○" }
      }

      $timestamp = ([DateTime]$log.created_at).ToString("yyyy-MM-dd HH:mm:ss")
      Write-Host "  $icon [$timestamp] " -NoNewline -ForegroundColor $levelColor
      Write-Host "$($log.level.PadRight(5)) | " -NoNewline -ForegroundColor $levelColor
      Write-Host "$($log.module.PadRight(10)) | " -NoNewline -ForegroundColor White
      Write-Host "$($log.message)" -ForegroundColor White

      if ($log.error) {
        Write-Host "     错误: $($log.error)" -ForegroundColor Red
      }

      if ($log.extra) {
        try {
          $extra = $log.extra | ConvertFrom-Json
          $extraStr = ($extra.PSObject.Properties | ForEach-Object { "$($_.Name): $($_.Value)" }) -join " | "
          Write-Host "     额外信息: $extraStr" -ForegroundColor Gray
        }
        catch {
          Write-Host "     额外信息: $($log.extra)" -ForegroundColor Gray
        }
      }
      Write-Host ""
    }

    Write-Host "  " + ("-" * 120) -ForegroundColor Gray
    Write-Host "✓ 系统日志功能正常工作！" -ForegroundColor Green
  }
  else {
    Write-Host "  ℹ 暂无系统日志记录" -ForegroundColor Yellow
    Write-Host "  提示: 系统日志会在发生错误或警告时自动记录" -ForegroundColor Gray
  }
}
catch {
  Write-Host "  ✗ 查询系统日志失败: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. 测试日志筛选
Write-Host ""
Write-Host "5. 测试日志筛选..." -ForegroundColor Yellow

# 按级别筛选
Write-Host "  - 筛选warn级别日志..." -ForegroundColor Gray
try {
  $warnLogs = Invoke-RestMethod -Uri "$baseUrl/logs/system?level=warn" -Headers $headers
  Write-Host "    找到 $($warnLogs.pagination.total) 条warn级别日志" -ForegroundColor Cyan
}
catch {
  Write-Host "    筛选失败" -ForegroundColor Red
}

# 按模块筛选
Write-Host "  - 筛选http模块日志..." -ForegroundColor Gray
try {
  $httpLogs = Invoke-RestMethod -Uri "$baseUrl/logs/system?module=http" -Headers $headers
  Write-Host "    找到 $($httpLogs.pagination.total) 条http模块日志" -ForegroundColor Cyan
}
catch {
  Write-Host "    筛选失败" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== 测试完成 ===" -ForegroundColor Cyan
