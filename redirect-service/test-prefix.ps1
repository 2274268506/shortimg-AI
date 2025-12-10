# 测试不同类型短链的前缀生成

Write-Host "🧪 测试短链前缀功能" -ForegroundColor Green
Write-Host ""

$apiKey = "test-api-key-12345"
$baseUrl = "http://localhost/api/v2/imagebed"

# 测试数据
$tests = @(
    @{
        Name = "通用短链 (general)"
        Type = "general"
        ExpectedPrefix = ""
        Targets = @(@{url = "https://www.baidu.com"; weight = 1})
    },
    @{
        Name = "图床短链 (imagebed)"
        Type = "imagebed"
        ExpectedPrefix = "img-"
        Targets = @(@{path = "/uploads/test/image.jpg"; weight = 1})
    },
    @{
        Name = "文件短链 (file)"
        Type = "file"
        ExpectedPrefix = "file-"
        Targets = @(@{path = "/uploads/test/document.pdf"; weight = 1})
    },
    @{
        Name = "视频短链 (video)"
        Type = "video"
        ExpectedPrefix = "vid-"
        Targets = @(@{path = "/uploads/test/video.mp4"; weight = 1})
    }
)

foreach ($test in $tests) {
    Write-Host "📝 测试: $($test.Name)" -ForegroundColor Cyan
    
    $body = @{
        service_type = $test.Type
        targets = $test.Targets
        strategy = "weight"
        description = "测试 $($test.Type) 类型短链"
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri $baseUrl -Method POST `
            -Headers @{
                "X-API-Key" = $apiKey
                "Content-Type" = "application/json"
            } `
            -Body $body
        
        if ($response.success) {
            $shortCode = $response.data.short_code
            $prefix = $test.ExpectedPrefix
            
            if ($prefix -eq "") {
                # 通用类型，不应该有前缀
                if ($shortCode -notmatch "^(img-|file-|vid-)") {
                    Write-Host "  ✅ 成功: $shortCode (无前缀)" -ForegroundColor Green
                } else {
                    Write-Host "  ❌ 失败: $shortCode (不应该有前缀)" -ForegroundColor Red
                }
            } else {
                # 其他类型，应该有对应前缀
                if ($shortCode.StartsWith($prefix)) {
                    Write-Host "  ✅ 成功: $shortCode (前缀: $prefix)" -ForegroundColor Green
                } else {
                    Write-Host "  ❌ 失败: $shortCode (期望前缀: $prefix)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  ❌ API错误: $($response.error)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ❌ 请求失败: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Start-Sleep -Milliseconds 500
}

Write-Host "✅ 测试完成！" -ForegroundColor Green
