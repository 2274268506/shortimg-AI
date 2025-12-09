# 完整测试短链功能修复
Write-Host "`n========== 短链功能完整测试 ==========" -ForegroundColor Cyan

# 登录
$loginResp = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -ContentType "application/json" -Body '{"username":"admin","password":"admin123"}'
$token = $loginResp.data.token
$headers = @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json"}

Write-Host "✓ 登录成功" -ForegroundColor Green

# 获取图片列表
$images = Invoke-RestMethod -Uri "http://localhost:8080/api/images?page=1&pageSize=50" -Method GET -Headers $headers

# 找一张没有短链的图片
$noShortLink = $images.data.images | Where-Object { -not $_.short_link_code } | Select-Object -First 1

if ($noShortLink) {
    Write-Host "`n=== 测试1: 生成短链 ===" -ForegroundColor Yellow
    Write-Host "图片 ID=$($noShortLink.id), UUID=$($noShortLink.uuid)" -ForegroundColor White

    try {
        $result = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$($noShortLink.id)/shortlink" -Method POST -Headers $headers
        Write-Host "✓ 生成成功: $($result.data.short_link_code)" -ForegroundColor Green
        Write-Host "  URL: $($result.data.short_link_url)" -ForegroundColor White

        # 测试重定向
        Start-Sleep -Seconds 1
        $redirect = curl -I "http://localhost/$($result.data.short_link_code)" 2>&1 | Select-String "HTTP|Location"
        Write-Host "  重定向测试:" -ForegroundColor White
        $redirect | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

        $generatedCode = $result.data.short_link_code
        $generatedImageId = $noShortLink.id
    } catch {
        Write-Host "✗ 失败: $_" -ForegroundColor Red
        $generatedCode = $null
    }
} else {
    Write-Host "`n所有图片都已有短链，跳过生成测试" -ForegroundColor Yellow
    # 使用已有的短链进行后续测试
    $withShortLink = $images.data.images | Where-Object { $_.short_link_code } | Select-Object -First 1
    $generatedCode = $withShortLink.short_link_code
    $generatedImageId = $withShortLink.id
}

# 测试转移短链
if ($generatedCode) {
    Write-Host "`n=== 测试2: 转移短链 ===" -ForegroundColor Yellow

    # 找另一张没有短链的图片
    $noShortLink2 = $images.data.images | Where-Object { -not $_.short_link_code -and $_.id -ne $generatedImageId } | Select-Object -First 1

    if ($noShortLink2) {
        Write-Host "从图片 ID=$generatedImageId (短链=$generatedCode)" -ForegroundColor White
        Write-Host "转移到图片 ID=$($noShortLink2.id)" -ForegroundColor White

        $transferBody = @{new_image_id = $noShortLink2.id} | ConvertTo-Json

        try {
            $result = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$generatedImageId/shortlink" -Method PUT -Headers $headers -Body $transferBody
            Write-Host "✓ 转移成功: $($result.data.short_link_code)" -ForegroundColor Green
            Write-Host "  从 ID=$($result.data.old_image_id) → ID=$($result.data.new_image_id)" -ForegroundColor White

            # 测试重定向
            Start-Sleep -Seconds 1
            docker exec short-link-redis redis-cli DEL "short_link:$($result.data.short_link_code)" | Out-Null
            $redirect = curl -I "http://localhost/$($result.data.short_link_code)" 2>&1 | Select-String "HTTP|Location"
            Write-Host "  重定向测试:" -ForegroundColor White
            $redirect | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

            if ($redirect -match "302") {
                Write-Host "  ✓ 重定向正常 (302)" -ForegroundColor Green
            } else {
                Write-Host "  ✗ 重定向失败" -ForegroundColor Red
            }
        } catch {
            Write-Host "✗ 转移失败: $_" -ForegroundColor Red
            if ($_.ErrorDetails) {
                Write-Host "  错误详情: $($_.ErrorDetails.Message)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "没有找到合适的目标图片进行转移测试" -ForegroundColor Yellow
    }
}

Write-Host "`n========== 测试完成 ==========" -ForegroundColor Cyan
