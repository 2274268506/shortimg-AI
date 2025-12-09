# 测试短链转移
$loginResp = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -ContentType "application/json" -Body '{"username":"admin","password":"admin123"}'
$token = $loginResp.data.token
$headers = @{"Authorization" = "Bearer $token"; "Content-Type" = "application/json"}

# 转移短链：从图片 114 到图片 113
$transferBody = '{"new_image_id": 113}'
$result = Invoke-RestMethod -Uri "http://localhost:8080/api/images/114/shortlink" -Method PUT -Headers $headers -Body $transferBody

Write-Host "`n=== 短链转移结果 ===" -ForegroundColor Cyan
Write-Host "消息: $($result.message)" -ForegroundColor Green
Write-Host "短链代码: $($result.short_link_code)" -ForegroundColor Yellow
Write-Host "从图片 ID: $($result.old_image_id)" -ForegroundColor White
Write-Host "到图片 ID: $($result.new_image_id)" -ForegroundColor White
Write-Host "短链URL: $($result.short_link_url)" -ForegroundColor Magenta

# 测试重定向
Write-Host "`n=== 测试重定向 ===" -ForegroundColor Cyan
$redirectTest = curl -I "http://localhost/$($result.short_link_code)" 2>&1 | Select-String "HTTP|Location"
$redirectTest | ForEach-Object { Write-Host $_ }
