# 测试短链重定向问题
Write-Host "=== 短链重定向测试 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 登录
Write-Host "1. 登录..." -ForegroundColor Yellow
$loginResp = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -ContentType "application/json" -Body '{"username":"admin","password":"admin123"}'
$token = $loginResp.data.token
$headers = @{"Authorization" = "Bearer $token"}
Write-Host "✅ 登录成功" -ForegroundColor Green
Write-Host ""

# 2. 获取一张没有短链的图片
Write-Host "2. 获取测试图片..." -ForegroundColor Yellow
$imagesResp = Invoke-RestMethod -Uri "http://localhost:8080/api/images?page=1&pageSize=10" -Method GET -Headers $headers
$imageWithoutShortLink = $imagesResp.data | Where-Object { $_.shortLinkCode -eq $null -or $_.shortLinkCode -eq "" } | Select-Object -First 1

if ($null -eq $imageWithoutShortLink) {
    Write-Host "❌ 没有找到无短链的图片" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 找到测试图片:" -ForegroundColor Green
Write-Host "   ID: $($imageWithoutShortLink.id)" -ForegroundColor White
Write-Host "   UUID: $($imageWithoutShortLink.uuid)" -ForegroundColor White
Write-Host "   URL: $($imageWithoutShortLink.url)" -ForegroundColor White
Write-Host ""

# 3. 生成短链并观察后端日志
Write-Host "3. 生成短链（将输出后端日志）..." -ForegroundColor Yellow
try {
    $generateResp = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$($imageWithoutShortLink.id)/shortlink" -Method POST -Headers $headers -ErrorAction Stop
    Write-Host "✅ 后端返回成功" -ForegroundColor Green
    Write-Host "   短链代码: $($generateResp.short_link_code)" -ForegroundColor White
    Write-Host "   短链URL: $($generateResp.short_link_url)" -ForegroundColor White

    $shortLinkCode = $generateResp.short_link_code
} catch {
    Write-Host "❌ API调用失败: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "   错误详情: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    exit 1
}
Write-Host ""

# 4. 等待短链服务处理
Write-Host "4. 等待短链服务处理..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
Write-Host ""

# 5. 测试短链重定向
Write-Host "5. 测试短链重定向..." -ForegroundColor Yellow
$shortLinkUrl = "http://localhost/$shortLinkCode"
Write-Host "   短链地址: $shortLinkUrl" -ForegroundColor White

try {
    # 使用 curl 获取重定向信息
    $curlOutput = curl -I $shortLinkUrl 2>&1 | Out-String
    $locationLine = $curlOutput -split "`n" | Where-Object { $_ -match "^Location:" }

    if ($locationLine) {
        $location = ($locationLine -split "Location:\s*")[1].Trim()
        Write-Host "   重定向目标: $location" -ForegroundColor White
        Write-Host ""

        # 分析重定向URL
        if ($location -match "^http") {
            Write-Host "✅ 重定向到完整URL" -ForegroundColor Green
            Write-Host "   格式: 完整URL (http://...)" -ForegroundColor White

            # 检查域名是否正确
            if ($location -match "http://localhost:8080/") {
                Write-Host "✅ 域名正确: localhost:8080" -ForegroundColor Green
            } else {
                Write-Host "❌ 域名不正确" -ForegroundColor Red
                Write-Host "   期望: http://localhost:8080/i/..." -ForegroundColor White
                Write-Host "   实际: $location" -ForegroundColor White
            }
        } else {
            Write-Host "❌ 重定向到相对路径" -ForegroundColor Red
            Write-Host "   格式: 相对路径 ($location)" -ForegroundColor White
            Write-Host "   问题: 短链服务存储的应该是完整URL而不是相对路径" -ForegroundColor Red
            Write-Host ""
            Write-Host "🔍 原因分析:" -ForegroundColor Yellow
            Write-Host "   1. 检查短链服务的 routing_rules.yaml 中 private CDN 配置" -ForegroundColor White
            Write-Host "   2. 检查 .env 中 CDN_PRIVATE_DOMAIN/PROTOCOL/PORT 配置" -ForegroundColor White
            Write-Host "   3. 后端传递给短链服务的应该是相对路径，短链服务负责构建完整URL" -ForegroundColor White
        }
    } else {
        Write-Host "❌ 未找到Location头" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 测试失败: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== 测试完成 ===" -ForegroundColor Cyan
