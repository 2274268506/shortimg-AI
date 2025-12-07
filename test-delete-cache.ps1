# 图片删除和上传缓存验证脚本
Write-Host "`n==================== 缓存问题验证测试 ====================" -ForegroundColor Cyan

# 获取token
Write-Host "`n[1] 登录获取token..." -ForegroundColor Yellow
try {
  $loginResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" `
    -Method Post `
    -ContentType "application/json" `
    -Body '{"username":"admin","password":"admin123"}'
  $token = $loginResponse.token
  Write-Host "  ✅ 登录成功" -ForegroundColor Green
}
catch {
  Write-Host "  ❌ 登录失败: $_" -ForegroundColor Red
  exit 1
}

$headers = @{
  "Authorization" = "Bearer $token"
}

# 检查当前图片列表
Write-Host "`n[2] 获取当前图片列表..." -ForegroundColor Yellow
try {
  $response1 = Invoke-RestMethod -Uri "http://localhost:8080/api/images?albumId=1&page=1&pageSize=50" `
    -Headers $headers
  Write-Host "  当前图片总数: $($response1.total)" -ForegroundColor White

  if ($response1.data.Count -gt 0) {
    Write-Host "  前3张图片:" -ForegroundColor Gray
    $response1.data | Select-Object -First 3 | ForEach-Object {
      Write-Host "    - ID: $($_.id), 文件名: $($_.fileName)" -ForegroundColor Gray
    }
  }
}
catch {
  Write-Host "  ❌ 获取失败: $_" -ForegroundColor Red
}

# 检查Redis缓存
Write-Host "`n[3] 检查Redis缓存状态..." -ForegroundColor Yellow
$cacheKeys = docker exec shortimg-redis-test redis-cli KEYS "cache:*"
$cacheCount = ($cacheKeys | Measure-Object -Line).Lines
Write-Host "  缓存键数量: $cacheCount" -ForegroundColor White

# 如果有图片，测试删除
if ($response1.data.Count -gt 0) {
  $imageToDelete = $response1.data[0]
  Write-Host "`n[4] 测试删除图片..." -ForegroundColor Yellow
  Write-Host "  删除图片 ID: $($imageToDelete.id)" -ForegroundColor White

  try {
    $deleteResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$($imageToDelete.id)" `
      -Method Delete `
      -Headers $headers
    Write-Host "  ✅ 删除请求成功" -ForegroundColor Green    # 等待1秒
    Start-Sleep -Seconds 1

    # 检查缓存是否被清除
    Write-Host "`n[5] 检查删除后的缓存..." -ForegroundColor Yellow
    $cacheKeysAfterDelete = docker exec shortimg-redis-test redis-cli KEYS "cache:*"
    $cacheCountAfterDelete = ($cacheKeysAfterDelete | Measure-Object -Line).Lines
    Write-Host "  删除后缓存键数量: $cacheCountAfterDelete" -ForegroundColor White

    if ($cacheCountAfterDelete -eq 0) {
      Write-Host "  ✅ 缓存已清除" -ForegroundColor Green
    }
    else {
      Write-Host "  ⚠️ 缓存未清除（数量: $cacheCountAfterDelete）" -ForegroundColor Yellow
    }

    # 立即查询图片列表
    Write-Host "`n[6] 查询删除后的图片列表..." -ForegroundColor Yellow
    $response2 = Invoke-RestMethod -Uri "http://localhost:8080/api/images?albumId=1&page=1&pageSize=50" `
      -Headers $headers
    Write-Host "  删除后图片总数: $($response2.total)" -ForegroundColor White

    if ($response2.total -eq ($response1.total - 1)) {
      Write-Host "  ✅ 图片列表正确（减少了1张）" -ForegroundColor Green
    }
    else {
      Write-Host "  ❌ 图片列表不正确！" -ForegroundColor Red
      Write-Host "    预期: $($response1.total - 1), 实际: $($response2.total)" -ForegroundColor Red
    }

    # 检查删除的图片是否还在列表中
    $deletedStillExists = $response2.data | Where-Object { $_.id -eq $imageToDelete.id }
    if ($deletedStillExists) {
      Write-Host "  ❌ 已删除的图片仍在列表中！" -ForegroundColor Red
    }
    else {
      Write-Host "  ✅ 已删除的图片已从列表中移除" -ForegroundColor Green
    }

  }
  catch {
    Write-Host "  ❌ 删除失败: $_" -ForegroundColor Red
  }
}
else {
  Write-Host "`n[4-6] 跳过删除测试（无图片）" -ForegroundColor Yellow
}

# 检查后端日志
Write-Host "`n[7] 检查后端缓存清除日志..." -ForegroundColor Yellow
$cacheLogs = docker logs shortimg-backend-test --tail 100 2>&1 | Select-String "清除.*缓存|cache"
if ($cacheLogs) {
  Write-Host "  ✅ 找到缓存清除日志:" -ForegroundColor Green
  $cacheLogs | Select-Object -Last 5 | ForEach-Object {
    Write-Host "    $_" -ForegroundColor Gray
  }
}
else {
  Write-Host "  ⚠️ 未找到缓存清除日志" -ForegroundColor Yellow
}

# 测试总结
Write-Host "`n==================== 测试总结 ====================" -ForegroundColor Cyan
Write-Host "`n预期行为:" -ForegroundColor Yellow
Write-Host "  1. 删除图片后，缓存应该被清除" -ForegroundColor White
Write-Host "  2. 立即查询图片列表，应该看不到已删除的图片" -ForegroundColor White
Write-Host "  3. 图片总数应该减少1" -ForegroundColor White

Write-Host "`n当前系统状态:" -ForegroundColor Yellow
docker ps --filter "name=shortimg" --format "table {{.Names}}\t{{.Status}}"

Write-Host "`n如需上传测试，请在前端界面进行批量上传" -ForegroundColor Yellow
Write-Host ""
