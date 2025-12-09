# 测试：删除短链后再转移
$loginResp = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -ContentType "application/json" -Body '{"username":"admin","password":"admin123"}'
$token = $loginResp.data.token
$headers = @{"Authorization" = "Bearer $token"}

Write-Host "`n=== 步骤1: 删除图片 113 的短链 ===" -ForegroundColor Cyan
try {
    $delete = Invoke-RestMethod -Uri "http://localhost:8080/api/images/113/shortlink" -Method DELETE -Headers $headers
    Write-Host "删除成功: $($delete.message)" -ForegroundColor Green
} catch {
    Write-Host "删除失败或没有短链: $_" -ForegroundColor Yellow
}

Start-Sleep -Seconds 1

Write-Host "`n=== 步骤2: 转移短链从图片 114 到图片 113 ===" -ForegroundColor Cyan
$headers["Content-Type"] = "application/json"
$transferBody = '{"new_image_id": 113}'
try {
    $result = Invoke-RestMethod -Uri "http://localhost:8080/api/images/114/shortlink" -Method PUT -Headers $headers -Body $transferBody
    Write-Host "转移成功!" -ForegroundColor Green
    Write-Host "短链代码: $($result.short_link_code)" -ForegroundColor Yellow
    Write-Host "从图片 ID: $($result.old_image_id) → $($result.new_image_id)" -ForegroundColor White

    Write-Host "`n=== 步骤3: 测试重定向 ===" -ForegroundColor Cyan
    $redirectTest = curl -I "http://localhost/$($result.short_link_code)" 2>&1 | Select-String "HTTP|Location"
    $redirectTest | ForEach-Object { Write-Host $_ -ForegroundColor Magenta }
} catch {
    Write-Host "转移失败: $_" -ForegroundColor Red
}
