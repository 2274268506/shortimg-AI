# 显示设置功能测试脚本

Write-Host "=== 显示设置功能测试 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 检查 LocalStorage 中是否有显示设置
Write-Host "1. 检查浏览器存储的显示设置..." -ForegroundColor Yellow
Write-Host "  请在浏览器控制台运行以下命令查看当前设置：" -ForegroundColor Gray
Write-Host "  localStorage.getItem('display-settings')" -ForegroundColor Cyan
Write-Host ""

# 2. 设置测试配置
Write-Host "2. 设置测试配置..." -ForegroundColor Yellow
Write-Host "  在浏览器控制台运行以下命令设置测试配置：" -ForegroundColor Gray
Write-Host "  localStorage.setItem('display-settings', JSON.stringify({" -ForegroundColor Cyan
Write-Host "    theme: 'light'," -ForegroundColor Cyan
Write-Host "    defaultView: 'list'," -ForegroundColor Cyan
Write-Host "    pageSize: 48," -ForegroundColor Cyan
Write-Host "    thumbnailQuality: 90," -ForegroundColor Cyan
Write-Host "    lazyLoad: true," -ForegroundColor Cyan
Write-Host "    showFileSize: true," -ForegroundColor Cyan
Write-Host "    showUploadDate: true" -ForegroundColor Cyan
Write-Host "  }))" -ForegroundColor Cyan
Write-Host ""

# 3. 验证步骤
Write-Host "3. 验证步骤：" -ForegroundColor Yellow
Write-Host "  a) 在浏览器中打开系统设置页面（http://localhost:5173/settings）" -ForegroundColor White
Write-Host "  b) 修改以下设置：" -ForegroundColor White
Write-Host "     - 默认视图：改为 '列表视图'" -ForegroundColor Cyan
Write-Host "     - 每页显示数量：改为 '48 张'" -ForegroundColor Cyan
Write-Host "  c) 点击 '保存所有设置' 按钮" -ForegroundColor White
Write-Host "  d) 返回图片管理页面（http://localhost:5173）" -ForegroundColor White
Write-Host "  e) 刷新页面（F5）" -ForegroundColor White
Write-Host ""

Write-Host "4. 预期效果：" -ForegroundColor Yellow
Write-Host "  ✓ 图片应以列表模式显示（而不是网格模式）" -ForegroundColor Green
Write-Host "  ✓ 每次加载应显示 48 张图片（而不是 24 张）" -ForegroundColor Green
Write-Host ""

Write-Host "5. 测试其他设置：" -ForegroundColor Yellow
Write-Host "  返回设置页面，尝试以下配置：" -ForegroundColor White
Write-Host "  - 默认视图：网格视图" -ForegroundColor Cyan
Write-Host "  - 每页显示数量：12 张" -ForegroundColor Cyan
Write-Host "  保存后刷新图片管理页面，验证更改生效" -ForegroundColor White
Write-Host ""

# 6. 后端编译状态
Write-Host "6. 检查前端是否需要重新编译..." -ForegroundColor Yellow
$frontendProcess = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*vite*" }
if ($frontendProcess) {
  Write-Host "  ✓ 前端开发服务器正在运行" -ForegroundColor Green
  Write-Host "  前端应该会自动热更新，无需手动重启" -ForegroundColor Gray
}
else {
  Write-Host "  ⚠ 前端开发服务器未运行" -ForegroundColor Yellow
  Write-Host "  请运行以下命令启动前端：" -ForegroundColor Gray
  Write-Host "  cd frontend && npm run dev" -ForegroundColor Cyan
}
Write-Host ""

Write-Host "7. 代码修改说明：" -ForegroundColor Yellow
Write-Host "  已修改以下文件以支持显示设置：" -ForegroundColor White
Write-Host "  ✓ frontend/src/stores/image.ts" -ForegroundColor Green
Write-Host "    - pageSize 现在从 LocalStorage 读取" -ForegroundColor Gray
Write-Host "  ✓ frontend/src/views/ImageManager.vue" -ForegroundColor Green
Write-Host "    - viewMode 现在从 LocalStorage 读取" -ForegroundColor Gray
Write-Host "    - 使用 displaySettings.defaultView 初始化" -ForegroundColor Gray
Write-Host ""

Write-Host "8. 如何验证代码是否生效：" -ForegroundColor Yellow
Write-Host "  在浏览器控制台（F12）运行：" -ForegroundColor White
Write-Host "  JSON.parse(localStorage.getItem('display-settings'))" -ForegroundColor Cyan
Write-Host "  应该看到你在设置页面保存的配置" -ForegroundColor Gray
Write-Host ""

Write-Host "=== 测试指南完成 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "提示：" -ForegroundColor Yellow
Write-Host "- 如果修改未生效，请尝试清除浏览器缓存（Ctrl+Shift+Delete）" -ForegroundColor Gray
Write-Host "- 或者使用无痕模式（Ctrl+Shift+N）测试" -ForegroundColor Gray
Write-Host "- 确保前端开发服务器正在运行并已自动重新编译" -ForegroundColor Gray
