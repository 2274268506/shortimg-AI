# 创建测试用 API Key

$apiKey = "sk_test_12345678901234567890123456789012"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "创建测试 API Key" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 创建 SQL 文件
$sql = @"
USE short_links;
INSERT IGNORE INTO api_keys (api_key, name, allowed_domains, max_requests_per_day, is_active, created_at, updated_at)
VALUES ('$apiKey', '测试密钥', '*', 0, 1, NOW(), NOW());
"@

$sql | Out-File -FilePath "create_test_key.sql" -Encoding UTF8

# 执行 SQL
docker cp create_test_key.sql short-link-mysql:/tmp/create_test_key.sql
docker exec short-link-mysql sh -c "mysql -uroot -pyour_strong_password < /tmp/create_test_key.sql"

# 清理
Remove-Item create_test_key.sql

Write-Host "`n✅ API Key 创建成功!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "API Key: $apiKey" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "现在可以运行测试了：" -ForegroundColor White
Write-Host ".\tests\integration\test_all.ps1 -ApiKey `"$apiKey`"`n" -ForegroundColor Gray
