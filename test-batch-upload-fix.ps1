# 批量上传短链生成修复验证脚本

Write-Host "================================" -ForegroundColor Cyan
Write-Host "批量上传短链生成修复验证" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# 测试配置
$backendUrl = "http://localhost:8080"
$redirectServiceUrl = "http://localhost:8081"

# 1. 检查服务状态
Write-Host "[1] 检查服务状态..." -ForegroundColor Yellow
Write-Host ""

Write-Host "  后端服务: " -NoNewline
try {
  $health = Invoke-RestMethod -Uri "$backendUrl/health" -TimeoutSec 5
  Write-Host "✅ 运行中" -ForegroundColor Green
}
catch {
  Write-Host "❌ 未运行" -ForegroundColor Red
  Write-Host "  请先启动后端服务: cd backend && go run main.go" -ForegroundColor Yellow
  exit 1
}

Write-Host "  重定向服务: " -NoNewline
try {
  $health = Invoke-RestMethod -Uri "$redirectServiceUrl/health" -TimeoutSec 5
  Write-Host "✅ 运行中" -ForegroundColor Green
}
catch {
  Write-Host "❌ 未运行" -ForegroundColor Red
  Write-Host "  请先启动重定向服务: docker-compose up -d" -ForegroundColor Yellow
  exit 1
}

Write-Host ""

# 2. 测试说明
Write-Host "[2] 测试说明" -ForegroundColor Yellow
Write-Host "  ✅ 问题1修复: 数据库同时保存 short_link_code 和 short_link_url" -ForegroundColor Green
Write-Host "  ✅ 问题2修复: 内网IP自动使用 private CDN (localhost)" -ForegroundColor Green
Write-Host ""

# 3. 预期结果
Write-Host "[3] 预期结果" -ForegroundColor Yellow
Write-Host "  - 所有上传的图片都应该生成短链（包括第一张）" -ForegroundColor White
Write-Host "  - short_link_url 格式应为: http://localhost:8081/<code>" -ForegroundColor White
Write-Host "  - 访问短链应该重定向到: http://localhost:8080/uploads/..." -ForegroundColor White
Write-Host ""

# 4. 手动测试步骤
Write-Host "[4] 手动测试步骤" -ForegroundColor Yellow
Write-Host "  1. 打开前端: http://localhost:5173" -ForegroundColor White
Write-Host "  2. 登录系统（用户名: admin）" -ForegroundColor White
Write-Host "  3. 点击「上传图片」" -ForegroundColor White
Write-Host "  4. ✅ 勾选「生成短链」" -ForegroundColor Green
Write-Host "  5. 选择 2-3 张图片批量上传" -ForegroundColor White
Write-Host "  6. 查看上传结果" -ForegroundColor White
Write-Host ""

# 5. 验证点
Write-Host "[5] 验证点" -ForegroundColor Yellow
Write-Host ""
Write-Host "  ✓ 第一张图片是否有短链？" -ForegroundColor Cyan
Write-Host "    • 鼠标悬停查看 URL" -ForegroundColor Gray
Write-Host "    • 应该显示 http://localhost:8081/..." -ForegroundColor Gray
Write-Host ""
Write-Host "  ✓ 所有图片是否都有短链？" -ForegroundColor Cyan
Write-Host "    • 检查每张图片的链接" -ForegroundColor Gray
Write-Host ""
Write-Host "  ✓ 短链是否指向 localhost？" -ForegroundColor Cyan
Write-Host "    • ❌ 错误: http://cdn-china.example.com/..." -ForegroundColor Red
Write-Host "    • ✅ 正确: http://localhost:8080/uploads/..." -ForegroundColor Green
Write-Host ""
Write-Host "  ✓ 点击短链是否能正常访问图片？" -ForegroundColor Cyan
Write-Host "    • 应该能直接打开图片" -ForegroundColor Gray
Write-Host ""

# 6. 数据库验证（可选）
Write-Host "[6] 数据库验证 SQL（可选）" -ForegroundColor Yellow
Write-Host @"
  USE imagebed;

  -- 查看最近上传的图片（应该都有短链）
  SELECT
    id,
    file_name,
    short_link_code,
    short_link_url,
    created_at
  FROM images
  ORDER BY created_at DESC
  LIMIT 10;

  -- 统计有无短链的图片数量
  SELECT
    COUNT(*) as total,
    SUM(CASE WHEN short_link_code IS NOT NULL THEN 1 ELSE 0 END) as with_link,
    SUM(CASE WHEN short_link_code IS NULL THEN 1 ELSE 0 END) as without_link
  FROM images;
"@ -ForegroundColor Gray

Write-Host ""

# 7. 日志检查
Write-Host "[7] 查看后端日志" -ForegroundColor Yellow
Write-Host "  运行以下命令查看批量上传日志:" -ForegroundColor White
Write-Host "  docker logs shortimg-backend-test --tail 50 | Select-String -Pattern '短链'" -ForegroundColor Cyan
Write-Host ""

Write-Host "================================" -ForegroundColor Cyan
Write-Host "请按照上述步骤进行测试" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
