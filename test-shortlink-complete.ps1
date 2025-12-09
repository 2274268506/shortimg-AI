# 完整测试短链功能
Write-Host "`n=== 测试1: 生成短链 ===" -ForegroundColor Cyan

$loginResp = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -ContentType "application/json" -Body '{"username":"admin","password":"admin123"}'
$token = $loginResp.data.token
$headers = @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json"}

# 获取一张没有短链的图片
$images = Invoke-RestMethod -Uri "http://localhost:8080/api/images?page=1&pageSize=50" -Method GET -Headers $headers
$noShortLink = $images.data.images | Where-Object { -not $_.short_link_code } | Select-Object -First 1

if ($noShortLink) {
    Write-Host "找到图片 ID=$($noShortLink.id), UUID=$($noShortLink.uuid)" -ForegroundColor Yellow

    try {
        $result = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$($noShortLink.id)/shortlink" -Method POST -Headers $headers
        Write-Host "✓ 生成成功: $($result.short_link_code)" -ForegroundColor Green

        # 测试重定向
        $redirect = curl -I "http://localhost/$($result.short_link_code)" 2>&1 | Select-String "Location"
        Write-Host "  重定向: $redirect" -ForegroundColor White
    } catch {
        Write-Host "✗ 生成失败: $_" -ForegroundColor Red
        Write-Host "  错误详情: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "没有找到无短链的图片" -ForegroundColor Yellow
}

Write-Host "`n=== 测试2: 转移短链 ===" -ForegroundColor Cyan

# 找两张图片：一张有短链，一张没有短链
$withShortLink = $images.data.images | Where-Object { $_.short_link_code } | Select-Object -First 1
$noShortLink2 = $images.data.images | Where-Object { -not $_.short_link_code } | Select-Object -First 1

if ($withShortLink -and $noShortLink2) {
    Write-Host "从图片 ID=$($withShortLink.id) (短链=$($withShortLink.short_link_code))" -ForegroundColor Yellow
    Write-Host "转移到图片 ID=$($noShortLink2.id)" -ForegroundColor Yellow

    $transferBody = @{new_image_id = $noShortLink2.id} | ConvertTo-Json

    try {
        $result = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$($withShortLink.id)/shortlink" -Method PUT -Headers $headers -Body $transferBody
        Write-Host "✓ 转移成功: $($result.short_link_code)" -ForegroundColor Green
        Write-Host "  从 ID=$($result.old_image_id) → ID=$($result.new_image_id)" -ForegroundColor White

        # 测试重定向
        Start-Sleep -Seconds 1
        $redirect = curl -I "http://localhost/$($result.short_link_code)" 2>&1 | Select-String "HTTP|Location"
        Write-Host "  重定向测试:" -ForegroundColor White
        $redirect | ForEach-Object { Write-Host "    $_" }
    } catch {
        Write-Host "✗ 转移失败: $_" -ForegroundColor Red
        Write-Host "  错误详情: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "没有找到合适的图片进行转移测试" -ForegroundColor Yellow
}
