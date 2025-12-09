# 上传新图片并测试短链
Write-Host "`n=== 上传测试图片 ===" -ForegroundColor Cyan

$loginResp = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -ContentType "application/json" -Body '{"username":"admin","password":"admin123"}'
$token = $loginResp.data.token

# 创建一个测试图片
Add-Type -AssemblyName System.Drawing
$bitmap = New-Object System.Drawing.Bitmap(100, 100)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([System.Drawing.Color]::Blue)
$graphics.Dispose()
$testImagePath = "$env:TEMP\test-image-$(Get-Date -Format 'HHmmss').png"
$bitmap.Save($testImagePath, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()

Write-Host "创建测试图片: $testImagePath" -ForegroundColor Yellow

# 上传图片（不生成短链）
$boundary = [System.Guid]::NewGuid().ToString()
$bodyLines = @(
    "--$boundary",
    "Content-Disposition: form-data; name=`"albumId`"",
    "",
    "1",
    "--$boundary",
    "Content-Disposition: form-data; name=`"enableShortLink`"",
    "",
    "false",
    "--$boundary",
    "Content-Disposition: form-data; name=`"file`"; filename=`"test.png`"",
    "Content-Type: image/png",
    "",
    [System.IO.File]::ReadAllText($testImagePath),
    "--$boundary--"
)
$body = $bodyLines -join "`r`n"

try {
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "multipart/form-data; boundary=$boundary"
    }

    $uploadResult = Invoke-RestMethod -Uri "http://localhost:8080/api/images/upload" -Method POST -Headers $headers -Body $body
    $imageId = $uploadResult.data.images[0].id

    Write-Host "✓ 上传成功: ID=$imageId" -ForegroundColor Green

    # 测试生成短链
    Write-Host "`n=== 测试生成短链 ===" -ForegroundColor Cyan
    Start-Sleep -Seconds 1

    $headers2 = @{"Authorization" = "Bearer $token"}
    $shortLinkResult = Invoke-RestMethod -Uri "http://localhost:8080/api/images/$imageId/shortlink" -Method POST -Headers $headers2

    Write-Host "✓ 短链生成成功: $($shortLinkResult.short_link_code)" -ForegroundColor Green
    Write-Host "  URL: $($shortLinkResult.short_link_url)" -ForegroundColor White

    # 测试重定向
    Write-Host "`n=== 测试重定向 ===" -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    $redirect = curl -I "http://localhost/$($shortLinkResult.short_link_code)" 2>&1 | Select-String "HTTP|Location"
    $redirect | ForEach-Object { Write-Host "  $_" }

} catch {
    Write-Host "✗ 失败: $_" -ForegroundColor Red
    if ($_.ErrorDetails) {
        Write-Host "  详情: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
} finally {
    Remove-Item $testImagePath -ErrorAction SilentlyContinue
}
