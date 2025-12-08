# 简单的 V2 API 测试
$apiKey = "sk_test_12345678901234567890123456789012"
$baseUrl = "http://localhost"

# 生成随机代码避免冲突
$randomCode = "test-v2-" + (Get-Random -Maximum 999999)

$body = @{
    image_path = "/uploads/2024/12/test.jpg"
    custom_code = $randomCode
    enable_geo_routing = $true
} | ConvertTo-Json

Write-Host "测试 V2 API 创建短链..." -ForegroundColor Yellow
Write-Host "使用自定义代码: $randomCode" -ForegroundColor Gray
Write-Host "请求体: $body" -ForegroundColor Gray

$response = Invoke-RestMethod -Uri "$baseUrl/api/v2/imagebed/create" `
    -Method Post `
    -Headers @{"X-API-Key" = $apiKey} `
    -ContentType "application/json" `
    -Body $body

Write-Host "响应:" -ForegroundColor Green
$response | ConvertTo-Json -Depth 5
