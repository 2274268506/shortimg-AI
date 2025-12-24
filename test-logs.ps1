# 日志管理功能测试脚本

Write-Host "=== 日志管理功能测试 ===" -ForegroundColor Green
Write-Host ""

# 登录获取 token
Write-Host "1. 登录..." -ForegroundColor Yellow
$loginBody = @{
  username = "admin"
  password = "admin123"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" `
  -Method POST `
  -Body $loginBody `
  -ContentType "application/json"

$token = $response.data.token
Write-Host "✓ 登录成功" -ForegroundColor Green
Write-Host ""

# 执行一些操作以生成日志
Write-Host "2. 执行操作以生成日志..." -ForegroundColor Yellow

# 创建用户
Write-Host "  - 创建测试用户..." -ForegroundColor Gray
$createBody = @{
  username = "testlog001"
  email    = "testlog001@example.com"
  password = "password123"
  role     = "user"
} | ConvertTo-Json

try {
  $user = Invoke-RestMethod -Uri "http://localhost:8080/api/users" `
    -Method POST `
    -Headers @{Authorization = "Bearer $token" } `
    -ContentType "application/json" `
    -Body $createBody
  $userId = $user.data.id
  Write-Host "    ✓ 用户创建成功 (ID: $userId)" -ForegroundColor Green
}
catch {
  Write-Host "    × 用户创建失败（可能已存在）" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# 更新用户
if ($userId) {
  Write-Host "  - 更新用户信息..." -ForegroundColor Gray
  $updateBody = @{
    username = "testlog001_updated"
    email    = "testlog001@example.com"
    bio      = "这是一个测试用户"
  } | ConvertTo-Json

  Invoke-RestMethod -Uri "http://localhost:8080/api/users/$userId" `
    -Method PUT `
    -Headers @{Authorization = "Bearer $token" } `
    -ContentType "application/json" `
    -Body $updateBody | Out-Null
  Write-Host "    ✓ 用户更新成功" -ForegroundColor Green
}

Start-Sleep -Seconds 1

# 删除用户
if ($userId) {
  Write-Host "  - 删除用户..." -ForegroundColor Gray
  Invoke-RestMethod -Uri "http://localhost:8080/api/users/$userId" `
    -Method DELETE `
    -Headers @{Authorization = "Bearer $token" } | Out-Null
  Write-Host "    ✓ 用户删除成功" -ForegroundColor Green
}

Write-Host ""

# 查询操作日志
Write-Host "3. 查询操作日志..." -ForegroundColor Yellow
$logs = Invoke-RestMethod -Uri "http://localhost:8080/api/logs/operations?page=1&pageSize=10" `
  -Headers @{Authorization = "Bearer $token" }

Write-Host "  总记录数: $($logs.pagination.total)" -ForegroundColor Cyan
Write-Host ""

if ($logs.data.Count -gt 0) {
  Write-Host "  最近的操作日志:" -ForegroundColor Cyan
  Write-Host "  " + ("-" * 80)

  foreach ($log in $logs.data) {
    $time = [DateTime]::Parse($log.created_at).ToString("yyyy-MM-dd HH:mm:ss")
    $action = $log.action.PadRight(8)
    $module = $log.module.PadRight(8)
    $status = if ($log.status -lt 400) { "✓" } else { "×" }

    Write-Host "  $status [$time] $($log.username) | $action | $module | $($log.description)" -ForegroundColor $(if ($log.status -lt 400) { "White" } else { "Red" })
    Write-Host "    路径: $($log.path) | 耗时: $($log.latency)ms | IP: $($log.ip)"
  }

  Write-Host "  " + ("-" * 80)
  Write-Host ""
  Write-Host "✓ 日志功能正常工作！" -ForegroundColor Green
}
else {
  Write-Host "× 没有找到日志记录" -ForegroundColor Red
}

Write-Host ""

# 测试筛选功能
Write-Host "4. 测试日志筛选..." -ForegroundColor Yellow

# 按模块筛选
Write-Host "  - 筛选用户模块日志..." -ForegroundColor Gray
$userLogs = Invoke-RestMethod -Uri "http://localhost:8080/api/logs/operations?page=1&pageSize=10&module=user" `
  -Headers @{Authorization = "Bearer $token" }
Write-Host "    找到 $($userLogs.pagination.total) 条用户相关日志" -ForegroundColor Cyan

# 按操作筛选
Write-Host "  - 筛选创建操作日志..." -ForegroundColor Gray
$createLogs = Invoke-RestMethod -Uri "http://localhost:8080/api/logs/operations?page=1&pageSize=10&action=create" `
  -Headers @{Authorization = "Bearer $token" }
Write-Host "    找到 $($createLogs.pagination.total) 条创建操作日志" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== 测试完成 ===" -ForegroundColor Green
