# GeoIP分流测试脚本
# 使用X-Forwarded-For头模拟不同来源的访问

$shortCode = "img-6e4CngzfpyMM"
$baseUrl = "http://localhost"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "   GeoIP CDN 分流测试" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

# 测试1: 本地直连（无X-Forwarded-For）
Write-Host "[测试1] 本地直连 (127.0.0.1)" -ForegroundColor Cyan
Write-Host "预期: http://localhost/uploads/..." -ForegroundColor Gray
$result = curl.exe -I "$baseUrl/$shortCode" 2>&1 | Select-String "Location"
Write-Host "结果: $result`n" -ForegroundColor Yellow

# 测试2: 公网IP - Google DNS
Write-Host "[测试2] 公网IP - Google DNS (8.8.8.8)" -ForegroundColor Cyan
Write-Host "预期: https://dxy.oxvxo.net:18443/uploads/..." -ForegroundColor Gray
$result = curl.exe -H "X-Forwarded-For: 8.8.8.8" -I "$baseUrl/$shortCode" 2>&1 | Select-String "Location"
Write-Host "结果: $result`n" -ForegroundColor Yellow

# 测试3: 公网IP - Cloudflare DNS
Write-Host "[测试3] 公网IP - Cloudflare DNS (1.1.1.1)" -ForegroundColor Cyan
Write-Host "预期: https://dxy.oxvxo.net:18443/uploads/..." -ForegroundColor Gray
$result = curl.exe -H "X-Forwarded-For: 1.1.1.1" -I "$baseUrl/$shortCode" 2>&1 | Select-String "Location"
Write-Host "结果: $result`n" -ForegroundColor Yellow

# 测试4: 私有IP - 192.168网段
Write-Host "[测试4] 私有IP - 192.168.x.x" -ForegroundColor Cyan
Write-Host "预期: http://localhost/uploads/..." -ForegroundColor Gray
$result = curl.exe -H "X-Forwarded-For: 192.168.1.100" -I "$baseUrl/$shortCode" 2>&1 | Select-String "Location"
Write-Host "结果: $result`n" -ForegroundColor Yellow

# 测试5: 私有IP - 10网段
Write-Host "[测试5] 私有IP - 10.x.x.x" -ForegroundColor Cyan
Write-Host "预期: http://localhost/uploads/..." -ForegroundColor Gray
$result = curl.exe -H "X-Forwarded-For: 10.0.0.1" -I "$baseUrl/$shortCode" 2>&1 | Select-String "Location"
Write-Host "结果: $result`n" -ForegroundColor Yellow

# 测试6: 私有IP - 172.16-31网段
Write-Host "[测试6] 私有IP - 172.16-31.x.x (Docker网络)" -ForegroundColor Cyan
Write-Host "预期: http://localhost/uploads/..." -ForegroundColor Gray
$result = curl.exe -H "X-Forwarded-For: 172.18.0.1" -I "$baseUrl/$shortCode" 2>&1 | Select-String "Location"
Write-Host "结果: $result`n" -ForegroundColor Yellow

# 测试7: 中国公网IP
Write-Host "[测试7] 中国公网IP (114.114.114.114)" -ForegroundColor Cyan
Write-Host "预期: https://dxy.oxvxo.net:18443/uploads/..." -ForegroundColor Gray
$result = curl.exe -H "X-Forwarded-For: 114.114.114.114" -I "$baseUrl/$shortCode" 2>&1 | Select-String "Location"
Write-Host "结果: $result`n" -ForegroundColor Yellow

Write-Host "========================================" -ForegroundColor Green
Write-Host "   测试完成" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

# 查看分流日志
Write-Host "`n[查看分流日志]" -ForegroundColor Magenta
docker exec short-link-openresty tail -20 /usr/local/openresty/nginx/logs/access.log | Select-String "img-6e4CngzfpyMM" | Select-Object -Last 7
