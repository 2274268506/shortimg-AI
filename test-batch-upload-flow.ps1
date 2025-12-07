# 批量上传功能测试脚本
Write-Host "`n==================== 批量上传功能测试 ====================" -ForegroundColor Cyan

# 1. 检查后端容器状态
Write-Host "`n[1] 检查后端容器状态..." -ForegroundColor Yellow
docker ps --filter "name=shortimg-backend-test" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. 检查数据库中的图片记录
Write-Host "`n[2] 检查数据库中的图片记录..." -ForegroundColor Yellow
docker exec shortimg-mysql-test mysql -uimagebed_user -ptest_password_123 imagebed -se "SELECT id, file_name, album_id, file_size, created_at FROM images ORDER BY created_at DESC LIMIT 5;" 2>$null

# 3. 检查上传目录中的文件
Write-Host "`n[3] 检查上传目录中的文件..." -ForegroundColor Yellow
docker exec shortimg-backend-test ls -lh /app/uploads/album_1/

# 4. 测试图片API
Write-Host "`n[4] 测试图片列表API..." -ForegroundColor Yellow
$response = curl -s "http://localhost:8080/api/images?albumId=1&page=1&pageSize=5" | ConvertFrom-Json
Write-Host "  - 总数: $($response.total)" -ForegroundColor White
Write-Host "  - 当前页: $($response.page)" -ForegroundColor White
Write-Host "  - 图片数: $($response.data.Count)" -ForegroundColor White
if ($response.data.Count -gt 0) {
  Write-Host "`n  第一张图片信息:" -ForegroundColor Cyan
  $firstImage = $response.data[0]
  Write-Host "    ID: $($firstImage.id)" -ForegroundColor White
  Write-Host "    文件名: $($firstImage.fileName)" -ForegroundColor White
  Write-Host "    原始名: $($firstImage.originalName)" -ForegroundColor White
  Write-Host "    URL: $($firstImage.url)" -ForegroundColor White
  Write-Host "    文件大小: $($firstImage.fileSize) bytes" -ForegroundColor White
  Write-Host "    创建时间: $($firstImage.createdAt)" -ForegroundColor White
}

# 5. 测试图片访问
Write-Host "`n[5] 测试图片直接访问..." -ForegroundColor Yellow
if ($response.data.Count -gt 0) {
  $imageUrl = $response.data[0].url
  $fullUrl = "http://localhost:8080$imageUrl"
  Write-Host "  测试URL: $fullUrl" -ForegroundColor White

  try {
    $headers = curl -I -s $fullUrl 2>&1 | Select-String "Content-Type|Content-Length"
    if ($headers) {
      Write-Host "  ✅ 图片可访问:" -ForegroundColor Green
      $headers | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    }
    else {
      Write-Host "  ❌ 图片访问失败" -ForegroundColor Red
    }
  }
  catch {
    Write-Host "  ❌ 错误: $_" -ForegroundColor Red
  }
}
else {
  Write-Host "  ⚠️ 没有图片可测试" -ForegroundColor Yellow
}

# 6. 检查前端代理配置
Write-Host "`n[6] 检查前端Vite代理配置..." -ForegroundColor Yellow
if (Test-Path "frontend/vite.config.ts") {
  $viteConfig = Get-Content "frontend/vite.config.ts" | Select-String -Pattern "/i.*:|/api.*:" -Context 0, 1
  if ($viteConfig) {
    Write-Host "  ✅ 找到代理配置:" -ForegroundColor Green
    $viteConfig | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
  }
  else {
    Write-Host "  ❌ 未找到/i路径的代理配置" -ForegroundColor Red
  }
}

# 7. 建议
Write-Host "`n==================== 测试结果总结 ====================" -ForegroundColor Cyan
Write-Host "`n如果前端显示图片有问题，请检查:" -ForegroundColor Yellow
Write-Host "  1. 前端是否通过 npm run dev 启动在 http://localhost:5173" -ForegroundColor White
Write-Host "  2. 浏览器控制台是否有图片加载错误（Network标签）" -ForegroundColor White
Write-Host "  3. 图片URL是否被正确代理到后端" -ForegroundColor White
Write-Host "  4. 刷新页面后是否重新请求了图片列表API" -ForegroundColor White

Write-Host "`n如果需要调试，可以:" -ForegroundColor Yellow
Write-Host "  • 打开浏览器开发者工具 (F12)" -ForegroundColor White
Write-Host "  • 切换到 Network 标签" -ForegroundColor White
Write-Host "  • 刷新页面，查看 /api/images 请求" -ForegroundColor White
Write-Host "  • 检查图片资源请求 (/i/xxx) 是否成功" -ForegroundColor White
Write-Host ""
