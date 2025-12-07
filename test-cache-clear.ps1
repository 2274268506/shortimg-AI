# 批量上传缓存清除功能测试
Write-Host "`n==================== 缓存清除功能测试 ====================" -ForegroundColor Cyan

# 获取管理员token
Write-Host "`n[1] 登录获取token..." -ForegroundColor Yellow
$loginResponse = curl -s -X POST "http://localhost:8080/api/auth/login" `
  -H "Content-Type: application/json" `
  -d '{"username":"admin","password":"admin123"}' | ConvertFrom-Json

if ($loginResponse.token) {
  Write-Host "  ✅ 登录成功" -ForegroundColor Green
  $token = $loginResponse.token
}
else {
  Write-Host "  ❌ 登录失败" -ForegroundColor Red
  exit 1
}

# 第一次请求图片列表（应该被缓存）
Write-Host "`n[2] 第一次请求图片列表（建立缓存）..." -ForegroundColor Yellow
$firstResponse = curl -s "http://localhost:8080/api/images?albumId=1&page=1&pageSize=24" `
  -H "Authorization: Bearer $token" | ConvertFrom-Json
$firstCount = $firstResponse.total
Write-Host "  当前图片数: $firstCount" -ForegroundColor White
Write-Host "  缓存状态: 已缓存（5分钟）" -ForegroundColor Gray

# 准备测试图片（创建一个临时图片）
Write-Host "`n[3] 准备测试图片..." -ForegroundColor Yellow
$testImagePath = "test-upload-cache.png"
if (Test-Path $testImagePath) {
  Write-Host "  ✅ 测试图片已存在: $testImagePath" -ForegroundColor Green
}
else {
  Write-Host "  ⚠️ 请确保有测试图片: $testImagePath" -ForegroundColor Yellow
  Write-Host "  或者修改脚本指向现有图片文件" -ForegroundColor Yellow
}

# 上传图片
Write-Host "`n[4] 批量上传测试图片..." -ForegroundColor Yellow
if (Test-Path $testImagePath) {
  try {
    # 使用 curl 上传（PowerShell 的 Invoke-RestMethod 在处理 multipart/form-data 时有bug）
    $uploadResponse = & curl -s -X POST "http://localhost:8080/api/images/batch-upload" `
      -H "Authorization: Bearer $token" `
      -F "files=@$testImagePath" `
      -F "albumId=1" | ConvertFrom-Json

    if ($uploadResponse.success -gt 0) {
      Write-Host "  ✅ 上传成功: $($uploadResponse.success)个文件" -ForegroundColor Green
    }
    else {
      Write-Host "  ⚠️ 上传可能失败" -ForegroundColor Yellow
      Write-Host "  响应: $($uploadResponse | ConvertTo-Json -Depth 2)" -ForegroundColor Gray
    }
  }
  catch {
    Write-Host "  ❌ 上传失败: $_" -ForegroundColor Red
  }
}
else {
  Write-Host "  ⏭️ 跳过上传（无测试图片）" -ForegroundColor Yellow
}

# 立即请求图片列表（测试缓存是否被清除）
Write-Host "`n[5] 立即请求图片列表（测试缓存清除）..." -ForegroundColor Yellow
Start-Sleep -Seconds 1
$secondResponse = curl -s "http://localhost:8080/api/images?albumId=1&page=1&pageSize=24" `
  -H "Authorization: Bearer $token" | ConvertFrom-Json
$secondCount = $secondResponse.total

Write-Host "  上传前: $firstCount 张" -ForegroundColor White
Write-Host "  上传后: $secondCount 张" -ForegroundColor White

if ($secondCount -gt $firstCount) {
  Write-Host "`n  ✅ 缓存清除成功！新上传的图片立即可见" -ForegroundColor Green
}
elseif ($secondCount -eq $firstCount) {
  Write-Host "`n  ⚠️ 缓存可能未清除，或上传未成功" -ForegroundColor Yellow
}
else {
  Write-Host "`n  ❌ 数据异常（图片数减少）" -ForegroundColor Red
}

# 检查后端日志中的缓存清除记录
Write-Host "`n[6] 检查后端日志..." -ForegroundColor Yellow
$cacheLog = docker logs shortimg-backend-test --tail 50 2>&1 | Select-String "清除.*缓存|cache"
if ($cacheLog) {
  Write-Host "  ✅ 找到缓存操作日志:" -ForegroundColor Green
  $cacheLog | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
}
else {
  Write-Host "  ⚠️ 未找到缓存操作日志" -ForegroundColor Yellow
}

# 总结
Write-Host "`n==================== 测试总结 ====================" -ForegroundColor Cyan
Write-Host "`n预期行为:" -ForegroundColor Yellow
Write-Host "  ✅ 批量上传后，立即刷新页面可以看到新图片" -ForegroundColor White
Write-Host "  ✅ 无需等待 5 分钟缓存过期" -ForegroundColor White
Write-Host "  ✅ 后端日志显示缓存清除记录" -ForegroundColor White

Write-Host "`n如果测试失败，请检查:" -ForegroundColor Yellow
Write-Host "  1. Redis 是否正常运行" -ForegroundColor White
Write-Host "  2. 后端是否正确编译了新代码" -ForegroundColor White
Write-Host "  3. image_controller.go 中的 clearImageListCache 是否被调用" -ForegroundColor White
Write-Host ""
