# 前端依赖安装脚本
# 用途：为图床前端安装短链功能所需的依赖

param(
  [string]$FrontendPath = "c:\Users\DXY\Documents\TC-GO\frontend"
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           图床前端短链功能 - 依赖安装                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "`n开始安装依赖..." -ForegroundColor Yellow

# 检查前端目录
if (-not (Test-Path $FrontendPath)) {
  Write-Host "✗ 前端目录不存在: $FrontendPath" -ForegroundColor Red
  exit 1
}

Set-Location $FrontendPath

# 检查 package.json
if (-not (Test-Path "package.json")) {
  Write-Host "✗ package.json 文件不存在" -ForegroundColor Red
  exit 1
}

Write-Host "✓ 前端目录: $FrontendPath" -ForegroundColor Green

# 检查 Node.js
Write-Host "`n检查 Node.js 环境..." -ForegroundColor Cyan
try {
  $nodeVersion = node --version
  $npmVersion = npm --version
  Write-Host "✓ Node.js: $nodeVersion" -ForegroundColor Green
  Write-Host "✓ npm: $npmVersion" -ForegroundColor Green
}
catch {
  Write-Host "✗ Node.js 未安装或不在 PATH 中" -ForegroundColor Red
  Write-Host "  请先安装 Node.js: https://nodejs.org/" -ForegroundColor Yellow
  exit 1
}

# 安装 qrcode 库
Write-Host "`n[1/2] 安装 qrcode 库..." -ForegroundColor Cyan
try {
  npm install qrcode
  Write-Host "✓ qrcode 库安装成功" -ForegroundColor Green
}
catch {
  Write-Host "✗ qrcode 库安装失败" -ForegroundColor Red
  Write-Host "  错误: $_" -ForegroundColor Red
}

# 安装 TypeScript 类型定义
Write-Host "`n[2/2] 安装 @types/qrcode 类型定义..." -ForegroundColor Cyan
try {
  npm install --save-dev @types/qrcode
  Write-Host "✓ @types/qrcode 安装成功" -ForegroundColor Green
}
catch {
  Write-Host "✗ @types/qrcode 安装失败" -ForegroundColor Red
  Write-Host "  错误: $_" -ForegroundColor Red
}

# 验证安装
Write-Host "`n验证安装..." -ForegroundColor Cyan
$packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json

$hasQrcode = $packageJson.dependencies.PSObject.Properties.Name -contains "qrcode"
$hasTypesQrcode = $packageJson.devDependencies.PSObject.Properties.Name -contains "@types/qrcode"

if ($hasQrcode) {
  Write-Host "✓ qrcode 已添加到 dependencies" -ForegroundColor Green
}
else {
  Write-Host "⚠ qrcode 未在 dependencies 中找到" -ForegroundColor Yellow
}

if ($hasTypesQrcode) {
  Write-Host "✓ @types/qrcode 已添加到 devDependencies" -ForegroundColor Green
}
else {
  Write-Host "⚠ @types/qrcode 未在 devDependencies 中找到" -ForegroundColor Yellow
}

# 检查新增文件
Write-Host "`n检查集成文件..." -ForegroundColor Cyan

$requiredFiles = @(
  "src\utils\shortlink.ts",
  "src\components\ShortLinkInfo.vue"
)

$allFilesExist = $true
foreach ($file in $requiredFiles) {
  if (Test-Path $file) {
    Write-Host "✓ $file" -ForegroundColor Green
  }
  else {
    Write-Host "✗ $file 不存在" -ForegroundColor Red
    $allFilesExist = $false
  }
}

if (-not $allFilesExist) {
  Write-Host "`n⚠ 部分文件缺失，请确保已复制所有集成文件" -ForegroundColor Yellow
}

# 检查修改的文件
Write-Host "`n检查修改的文件..." -ForegroundColor Cyan

$modifiedFiles = @(
  "src\types\index.ts",
  "src\components\ImageList.vue",
  "src\components\ImageGrid.vue",
  "src\components\ImagePreviewDialog.vue",
  "src\views\ImageManager.vue"
)

foreach ($file in $modifiedFiles) {
  if (Test-Path $file) {
    Write-Host "✓ $file" -ForegroundColor Green
  }
  else {
    Write-Host "⚠ $file 不存在" -ForegroundColor Yellow
  }
}

# 总结
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                   安装完成                                   ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n📋 下一步操作:" -ForegroundColor Cyan
Write-Host "  1. 启动开发服务器:" -ForegroundColor Yellow
Write-Host "     npm run dev" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. 或构建生产版本:" -ForegroundColor Yellow
Write-Host "     npm run build" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. 确保 Backend 已启用短链功能" -ForegroundColor Yellow
Write-Host "     参考: ..\IMAGEBED_INTEGRATION.md" -ForegroundColor Gray

Write-Host "`n📖 文档:" -ForegroundColor Cyan
Write-Host "  - 前端集成说明: ..\FRONTEND_SHORTLINK_INTEGRATION.md" -ForegroundColor Gray
Write-Host "  - Backend集成说明: ..\IMAGEBED_INTEGRATION.md" -ForegroundColor Gray

Write-Host "`n🎯 功能说明:" -ForegroundColor Cyan
Write-Host "  - 图片列表显示短链列" -ForegroundColor Gray
Write-Host "  - 图片网格悬停显示短链按钮" -ForegroundColor Gray
Write-Host "  - 预览对话框显示完整短链信息" -ForegroundColor Gray
Write-Host "  - 支持二维码生成和下载" -ForegroundColor Gray
Write-Host "  - 支持多种格式（Markdown/HTML/BBCode）" -ForegroundColor Gray

Write-Host "`n💡 提示:" -ForegroundColor Cyan
if ($hasQrcode -and $hasTypesQrcode) {
  Write-Host "  ✅ 所有依赖已正确安装" -ForegroundColor Green
  Write-Host "  ✅ 可以使用完整的短链功能（包括二维码）" -ForegroundColor Green
}
else {
  Write-Host "  ⚠️  部分依赖未安装" -ForegroundColor Yellow
  Write-Host "  ⚠️  二维码功能可能无法使用" -ForegroundColor Yellow
  Write-Host "  💡 运行以下命令手动安装:" -ForegroundColor Cyan
  Write-Host "     npm install qrcode @types/qrcode --save-dev" -ForegroundColor Gray
}

Write-Host ""
