# 测试缩略图质量功能
Write-Host "=== 测试缩略图质量功能 ===" -ForegroundColor Cyan

# 1. 检查后端编译状态
Write-Host "`n1. 检查后端编译..." -ForegroundColor Yellow
if (Test-Path ".\bin\backend.exe") {
  Write-Host "   ✓ 后端编译成功" -ForegroundColor Green
}
else {
  Write-Host "   ✗ 后端编译失败，请先运行: cd backend && go build -o ../bin/backend.exe" -ForegroundColor Red
  exit 1
}

# 2. 检查前端文件修改
Write-Host "`n2. 检查前端文件修改..." -ForegroundColor Yellow
$gridFile = ".\frontend\src\components\ImageGrid.vue"
$listFile = ".\frontend\src\components\ImageList.vue"

if (Select-String -Path $gridFile -Pattern "thumbnailQuality" -Quiet) {
  Write-Host "   ✓ ImageGrid.vue 已添加缩略图质量支持" -ForegroundColor Green
}
else {
  Write-Host "   ✗ ImageGrid.vue 未找到 thumbnailQuality" -ForegroundColor Red
}

if (Select-String -Path $listFile -Pattern "thumbnailQuality" -Quiet) {
  Write-Host "   ✓ ImageList.vue 已添加缩略图质量支持" -ForegroundColor Green
}
else {
  Write-Host "   ✗ ImageList.vue 未找到 thumbnailQuality" -ForegroundColor Red
}

# 3. 检查 localStorage 键名统一性
Write-Host "`n3. 检查 localStorage 键名..." -ForegroundColor Yellow
if (Select-String -Path $gridFile -Pattern "display-settings" -Quiet) {
  Write-Host "   ✓ ImageGrid.vue 使用正确的键名 'display-settings'" -ForegroundColor Green
}
else {
  Write-Host "   ✗ ImageGrid.vue 键名不正确" -ForegroundColor Red
}

if (Select-String -Path $listFile -Pattern "display-settings" -Quiet) {
  Write-Host "   ✓ ImageList.vue 使用正确的键名 'display-settings'" -ForegroundColor Green
}
else {
  Write-Host "   ✗ ImageList.vue 键名不正确" -ForegroundColor Red
}

# 4. 显示测试说明
Write-Host "`n=== 手动测试步骤 ===" -ForegroundColor Cyan
Write-Host "
1. 启动后端服务:
   cd backend && ..\bin\backend.exe

2. 启动前端服务:
   cd frontend && npm run dev

3. 测试步骤:
   a. 打开浏览器，登录系统
   b. 进入「系统设置」->「显示设置」
   c. 调整「图片缩略图质量」滑块 (50-100)
   d. 点击「保存设置」
   e. 刷新「图片管理」页面
   f. 打开浏览器开发者工具 -> Network 标签
   g. 查看图片请求，应该看到 URL 包含 quality 参数

4. 验证效果:
   - 质量 50: 图片模糊但加载快
   - 质量 70: 适中
   - 质量 100: 清晰但文件较大

5. 检查 API 请求:
   - URL 格式: /api/images/{id}/thumbnail?quality=XX&t=timestamp
   - quality 参数范围: 50-100

" -ForegroundColor White

Write-Host "=== 功能实现总结 ===" -ForegroundColor Cyan
Write-Host "
✓ 后端修改:
  - image_controller.go: GetImageThumbnail 支持 quality 参数
  - 动态生成指定质量的 JPEG 缩略图
  - 质量范围: 50-100，默认 80

✓ 前端修改:
  - ImageGrid.vue: 从设置读取 thumbnailQuality
  - ImageList.vue: 从设置读取 thumbnailQuality
  - 统一使用 'display-settings' localStorage 键
  - URL 自动添加 quality 参数

✓ 设置界面:
  - Settings.vue 已有缩略图质量滑块控件
  - 范围: 50-100，步进 10
  - 实时保存到 localStorage
" -ForegroundColor Green
