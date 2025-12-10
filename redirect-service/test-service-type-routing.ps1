# 服务类型分流路由测试脚本

Write-Host "🧪 测试服务类型分流路由功能" -ForegroundColor Green
Write-Host ""

$apiKey = "test-api-key-12345"
$baseUrl = "http://localhost/api/v2/imagebed"

# 测试数据：不同服务类型
$tests = @(
    @{
        Name = "图床短链 (imagebed)"
        Type = "imagebed"
        Targets = @(@{path = "/uploads/images/test.jpg"; weight = 1})
        ExpectedPrefix = "img-"
        ExpectedDomain = "img-"
    },
    @{
        Name = "文件短链 (file)"
        Type = "file"
        Targets = @(@{path = "/uploads/files/document.pdf"; weight = 1})
        ExpectedPrefix = "file-"
        ExpectedDomain = "file-"
    },
    @{
        Name = "视频短链 (video)"
        Type = "video"
        Targets = @(@{path = "/uploads/videos/movie.mp4"; weight = 1})
        ExpectedPrefix = "vid-"
        ExpectedDomain = "video-"
    },
    @{
        Name = "通用短链 (general)"
        Type = "general"
        Targets = @(@{url = "https://www.example.com/page"; weight = 1})
        ExpectedPrefix = ""
        ExpectedDomain = "cdn"
    }
)

$results = @()

foreach ($test in $tests) {
    Write-Host "📝 测试: $($test.Name)" -ForegroundColor Cyan
    
    $body = @{
        service_type = $test.Type
        targets = $test.Targets
        strategy = "geo"
    } | ConvertTo-Json -Depth 5 -Compress
    
    try {
        $response = Invoke-RestMethod -Uri $baseUrl -Method POST `
            -Headers @{
                "Content-Type" = "application/json"
                "X-API-Key" = $apiKey
            } `
            -Body $body `
            -ErrorAction Stop
        
        $shortCode = $response.data.short_code
        $serviceType = $response.data.service_type
        
        # 验证前缀
        $hasCorrectPrefix = $false
        if ($test.ExpectedPrefix -eq "") {
            $hasCorrectPrefix = -not ($shortCode -match "^(img-|file-|vid-)")
        } else {
            $hasCorrectPrefix = $shortCode.StartsWith($test.ExpectedPrefix)
        }
        
        if ($hasCorrectPrefix) {
            Write-Host "  ✅ 成功创建: $shortCode" -ForegroundColor Green
            Write-Host "    - 服务类型: $serviceType" -ForegroundColor Gray
            Write-Host "    - 前缀验证: 通过 ($($test.ExpectedPrefix))" -ForegroundColor Gray
            
            # 测试访问重定向（查看是否路由到正确的服务器群组）
            try {
                $redirectUrl = "http://localhost/$shortCode"
                Write-Host "    - 测试重定向: $redirectUrl" -ForegroundColor Gray
                
                # 使用 -MaximumRedirection 0 来捕获重定向而不跟随
                $redirectResponse = Invoke-WebRequest -Uri $redirectUrl `
                    -MaximumRedirection 0 `
                    -ErrorAction SilentlyContinue
                
            } catch {
                # 302重定向会抛出异常，从异常中获取Location
                if ($_.Exception.Response.StatusCode -eq 302) {
                    $location = $_.Exception.Response.Headers["Location"]
                    Write-Host "    - 重定向到: $location" -ForegroundColor Gray
                    
                    # 验证域名前缀
                    if ($location -like "*$($test.ExpectedDomain)*") {
                        Write-Host "    - 域名验证: ✅ 包含 '$($test.ExpectedDomain)'" -ForegroundColor Green
                    } else {
                        Write-Host "    - 域名验证: ⚠️ 不包含预期前缀 '$($test.ExpectedDomain)'" -ForegroundColor Yellow
                        Write-Host "      实际URL: $location" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "    - 重定向测试失败: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
            $results += @{
                Test = $test.Name
                Status = "成功"
                ShortCode = $shortCode
                ServiceType = $serviceType
            }
        } else {
            Write-Host "  ❌ 前缀错误: $shortCode (预期: $($test.ExpectedPrefix))" -ForegroundColor Red
            $results += @{
                Test = $test.Name
                Status = "前缀错误"
                ShortCode = $shortCode
                ServiceType = $serviceType
            }
        }
        
    } catch {
        Write-Host "  ❌ 请求失败: $($_.Exception.Message)" -ForegroundColor Red
        $results += @{
            Test = $test.Name
            Status = "失败"
            Error = $_.Exception.Message
        }
    }
    
    Write-Host ""
}

# 输出测试摘要
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host "📊 测试摘要" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Gray

$successCount = ($results | Where-Object { $_.Status -eq "成功" }).Count
$totalCount = $results.Count

Write-Host "总测试数: $totalCount" -ForegroundColor White
Write-Host "成功: $successCount" -ForegroundColor Green
Write-Host "失败: $($totalCount - $successCount)" -ForegroundColor Red
Write-Host ""

# 详细结果表格
$results | ForEach-Object {
    $status = if ($_.Status -eq "成功") { "✅" } else { "❌" }
    Write-Host "$status $($_.Test)" -ForegroundColor $(if ($_.Status -eq "成功") { "Green" } else { "Red" })
    if ($_.ShortCode) {
        Write-Host "   短链码: $($_.ShortCode)" -ForegroundColor Gray
    }
    if ($_.Error) {
        Write-Host "   错误: $($_.Error)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "✅ 测试完成！" -ForegroundColor Green

# 提示查看日志
Write-Host ""
Write-Host "💡 提示：查看路由日志验证分流效果" -ForegroundColor Yellow
Write-Host "  docker exec short-link-openresty tail -f /usr/local/openresty/nginx/logs/access.log" -ForegroundColor Gray
