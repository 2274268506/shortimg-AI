# 测试短链访问计数脚本
# 通过访问短链来增加 visit_count

Write-Host "🚀 开始测试短链访问计数..." -ForegroundColor Green

# 定义测试短链列表（从统计中获取）
$testCodes = @("tc-go-demo", "test_20251205223809", "test_20251205224650", "perf_test", "nhak5eLj")

Write-Host "`n📊 准备测试 $($testCodes.Count) 个短链" -ForegroundColor Cyan

foreach ($shortCode in $testCodes) {
    Write-Host "`n正在访问: $shortCode" -ForegroundColor Yellow
    
    # 访问短链多次（模拟20次访问）
    $successCount = 0
    for ($i = 1; $i -le 20; $i++) {
        try {
            # 使用 -MaximumRedirection 0 避免实际跟随重定向
            $response = Invoke-WebRequest -Uri "http://localhost/$shortCode" -Method GET -MaximumRedirection 0 -ErrorAction Stop
            Write-Host "  ✓" -NoNewline -ForegroundColor Green
            $successCount++
        } catch {
            # 302/301 重定向也算成功（说明短链有效）
            if ($_.Exception.Response.StatusCode -in @(301,302,307,308)) {
                Write-Host "  ✓" -NoNewline -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  ✗" -NoNewline -ForegroundColor Red
            }
        }
        if ($i % 10 -eq 0) { Write-Host "" }
        Start-Sleep -Milliseconds 50
    }
    Write-Host "`n  成功: $successCount/20" -ForegroundColor Cyan
}

Write-Host "`n⏳ 等待2秒后查询统计..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

# 查询统计信息
Write-Host "`n📊 查询最新统计信息..." -ForegroundColor Green
$stats = Invoke-RestMethod -Uri "http://localhost/api/v2/imagebed/stats/overview" -Headers @{
    "X-API-Key" = "test-api-key-12345"
    "Content-Type" = "application/json"
}

Write-Host "`n统计结果:" -ForegroundColor Cyan
Write-Host "  总链接数: $($stats.data.total_links)"
Write-Host "  总访问量: $($stats.data.total_visits)"
Write-Host "  独立访客: $($stats.data.unique_visitors)"
Write-Host "  今日新增: $($stats.data.today_new)"

Write-Host "`n🎯 访问量 TOP 5:" -ForegroundColor Cyan
foreach ($topLink in $stats.data.top_links | Select-Object -First 5) {
    Write-Host "  $($topLink.short_code): $($topLink.visit_count) 次"
}

Write-Host "`n✅ 测试完成！请刷新浏览器查看统计页面。" -ForegroundColor Green
