# 短链管理功能测试脚本
Write-Host "=== 短链管理功能测试 ===" -ForegroundColor Cyan
Write-Host ""

# 登录获取 token
Write-Host "1. 登录获取 token..." -ForegroundColor Yellow
$loginResp = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -ContentType "application/json" -Body '{"username":"admin","password":"admin123"}'
$token = $loginResp.data.token
$headers = @{"Authorization" = "Bearer $token"}
Write-Host "✅ 登录成功" -ForegroundColor Green
Write-Host ""

# 获取一张没有短链的图片
Write-Host "2. 获取测试图片..." -ForegroundColor Yellow
$imagesResp = Invoke-RestMethod -Uri "http://localhost:8080/api/images?page=1&pageSize=10" -Method GET -Headers $headers
$imageWithoutShortLink = $imagesResp.data | Where-Object { $_.shortLinkCode -eq $null -or $_.shortLinkCode -eq "" } | Select-Object -First 1

if ($null -eq $imageWithoutShortLink) {
    Write-Host "❌ 没有找到无短链的图片，请先上传一张新图片" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 找到测试图片 ID: $($imageWithoutShortLink.id)" -ForegroundColor Green
Write-Host ""

# 测试1: 生成短链
Write-Host "3. 测试生成短链..." -ForegroundColor Yellow
try {
    $generateResp = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$($imageWithoutShortLink.id)/shortlink" -Method POST -Headers $headers
    Write-Host "✅ 短链生成成功" -ForegroundColor Green
    Write-Host "   短链代码: $($generateResp.short_link_code)" -ForegroundColor White
    Write-Host "   短链URL: $($generateResp.short_link_url)" -ForegroundColor White

    # 检查短链URL是否使用了正确的域名
    if ($generateResp.short_link_url -like "http://localhost/*") {
        Write-Host "✅ 短链URL使用了正确的公开域名 (SHORT_LINK_PUBLIC_URL)" -ForegroundColor Green
    } else {
        Write-Host "❌ 短链URL域名不正确: $($generateResp.short_link_url)" -ForegroundColor Red
        Write-Host "   应该是: http://localhost/..." -ForegroundColor Red
    }

    $shortLinkCode = $generateResp.short_link_code
} catch {
    Write-Host "❌ 生成短链失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 等待数据库更新
Start-Sleep -Seconds 1

# 重新查询图片确认短链已保存
Write-Host "4. 验证短链已保存到数据库..." -ForegroundColor Yellow
$imageResp = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$($imageWithoutShortLink.id)" -Method GET -Headers $headers
if ($imageResp.data.shortLinkCode -eq $shortLinkCode) {
    Write-Host "✅ 短链已正确保存到数据库" -ForegroundColor Green
    Write-Host "   短链代码: $($imageResp.data.shortLinkCode)" -ForegroundColor White
    Write-Host "   短链URL: $($imageResp.data.shortLinkUrl)" -ForegroundColor White
} else {
    Write-Host "❌ 短链未正确保存" -ForegroundColor Red
}
Write-Host ""

# 获取另一张图片用于测试转移
Write-Host "5. 获取第二张图片用于测试转移..." -ForegroundColor Yellow
$targetImage = $imagesResp.data | Where-Object { $_.id -ne $imageWithoutShortLink.id -and ($_.shortLinkCode -eq $null -or $_.shortLinkCode -eq "") } | Select-Object -First 1

if ($null -eq $targetImage) {
    Write-Host "⚠️  没有找到第二张无短链的图片，跳过转移测试" -ForegroundColor Yellow
} else {
    Write-Host "✅ 找到目标图片 ID: $($targetImage.id), UUID: $($targetImage.uuid)" -ForegroundColor Green
    Write-Host ""

    # 测试3: 转移短链
    Write-Host "6. 测试转移短链..." -ForegroundColor Yellow
    try {
        $transferBody = @{
            target_uuid = $targetImage.uuid
        } | ConvertTo-Json

        $transferResp = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$($imageWithoutShortLink.id)/shortlink" -Method PUT -Headers $headers -ContentType "application/json" -Body $transferBody
        Write-Host "✅ 短链转移成功" -ForegroundColor Green
        Write-Host "   从图片 $($transferResp.old_image_id) 转移到 $($transferResp.new_image_id)" -ForegroundColor White
        Write-Host "   短链代码: $($transferResp.short_link_code)" -ForegroundColor White
        Write-Host "   短链URL: $($transferResp.short_link_url)" -ForegroundColor White

        # 检查转移后的短链URL是否正确
        if ($transferResp.short_link_url -like "http://localhost/*") {
            Write-Host "✅ 转移后的短链URL使用了正确的公开域名" -ForegroundColor Green
        } else {
            Write-Host "❌ 转移后的短链URL域名不正确: $($transferResp.short_link_url)" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ 转移短链失败: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) {
            $errorObj = $_.ErrorDetails.Message | ConvertFrom-Json
            Write-Host "   错误详情: $($errorObj.error)" -ForegroundColor Red
        }
    }
    Write-Host ""

    # 验证转移结果
    Write-Host "7. 验证转移结果..." -ForegroundColor Yellow
    $oldImageResp = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$($imageWithoutShortLink.id)" -Method GET -Headers $headers
    $newImageResp = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$($targetImage.id)" -Method GET -Headers $headers

    if ($oldImageResp.data.shortLinkCode -eq "" -and $newImageResp.data.shortLinkCode -eq $shortLinkCode) {
        Write-Host "✅ 短链转移验证成功" -ForegroundColor Green
        Write-Host "   原图片已清除短链" -ForegroundColor White
        Write-Host "   新图片已获得短链: $($newImageResp.data.shortLinkCode)" -ForegroundColor White
    } else {
        Write-Host "❌ 短链转移验证失败" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== 测试完成 ===" -ForegroundColor Cyan
