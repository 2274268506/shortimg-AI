# 测试服务类型分流规则

Write-Host "🧪 测试服务类型分流规则" -ForegroundColor Green
Write-Host "=" * 60
Write-Host ""

# 配置
$apiKey = "test-api-key-12345"
$createUrl = "http://localhost/api/v2/imagebed"

# 测试数据 - 为每种类型创建短链
$testCases = @(
    @{
        Name = "图床短链测试"
        ServiceType = "imagebed"
        Targets = @(@{path = "/uploads/test-image.jpg"; weight = 1})
        ExpectedPrefix = "img-"
        ExpectedDomain = "img-"
    },
    @{
        Name = "文件短链测试"
        ServiceType = "file"
        Targets = @(@{path = "/files/test-doc.pdf"; weight = 1})
        ExpectedPrefix = "file-"
        ExpectedDomain = "file-"
    },
    @{
        Name = "视频短链测试"
        ServiceType = "video"
        Targets = @(@{path = "/videos/test-video.mp4"; weight = 1})
        ExpectedPrefix = "vid-"
        ExpectedDomain = "video-"
    },
    @{
        Name = "通用短链测试"
        ServiceType = "general"
        Targets = @(@{url = "https://www.baidu.com"; weight = 1})
        ExpectedPrefix = ""
        ExpectedDomain = "www.baidu.com"
    }
)

$results = @()
$createdLinks = @()

Write-Host "📝 第一步：创建测试短链" -ForegroundColor Cyan
Write-Host ""

foreach ($test in $testCases) {
    Write-Host "  创建 $($test.Name)..." -NoNewline
    
    $body = @{
        service_type = $test.ServiceType
        targets = $test.Targets
        strategy = "geo"
    } | ConvertTo-Json -Depth 5 -Compress
    
    try {
        $response = Invoke-RestMethod -Uri $createUrl -Method POST `
            -Headers @{
                "Content-Type" = "application/json"
                "X-API-Key" = $apiKey
            } `
            -Body $body `
            -ErrorAction Stop
        
        $shortCode = $response.data.short_code
        
        # 验证前缀
        $hasCorrectPrefix = $false
        if ($test.ExpectedPrefix -eq "") {
            $hasCorrectPrefix = -not ($shortCode -match "^(img-|file-|vid-)")
        } else {
            $hasCorrectPrefix = $shortCode.StartsWith($test.ExpectedPrefix)
        }
        
        if ($hasCorrectPrefix) {
            Write-Host " ✅ $shortCode" -ForegroundColor Green
            $createdLinks += @{
                Test = $test
                ShortCode = $shortCode
                ServiceType = $test.ServiceType
            }
        } else {
            Write-Host " ❌ 前缀错误: $shortCode" -ForegroundColor Red
        }
        
    } catch {
        Write-Host " ❌ 创建失败: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "📍 第二步：测试重定向和分流规则" -ForegroundColor Cyan
Write-Host ""

foreach ($link in $createdLinks) {
    $test = $link.Test
    $shortCode = $link.ShortCode
    $serviceType = $link.ServiceType
    
    Write-Host "  测试 $($test.Name): $shortCode" -ForegroundColor Yellow
    
    # 方法1：使用docker内部curl测试（模拟内网环境）
    Write-Host "    [内网环境测试]" -ForegroundColor Gray
    $dockerCmd = "curl -i http://localhost/$shortCode -L --max-redirs 0 2>&1"
    $curlOutput = docker exec short-link-openresty sh -c $dockerCmd 2>&1 | Out-String
    
    # 提取Location头
    if ($curlOutput -match "Location:\s*(.+)") {
        $location = $matches[1].Trim()
        Write-Host "      重定向到: $location" -ForegroundColor Green
        
        # 验证域名
        if ($serviceType -eq "general") {
            # 通用短链直接重定向到目标URL
            if ($location -like "*$($test.ExpectedDomain)*") {
                Write-Host "      ✅ 域名匹配: 包含 $($test.ExpectedDomain)" -ForegroundColor Green
            } else {
                Write-Host "      ⚠️ 域名不匹配" -ForegroundColor Yellow
            }
        } else {
            # 图床/文件/视频应该重定向到CDN域名
            if ($location -like "*localhost*" -or $location -like "*127.0.0.1*") {
                Write-Host "      ✅ 路由到内网CDN (private节点)" -ForegroundColor Green
            } elseif ($location -like "*$($test.ExpectedDomain)*") {
                Write-Host "      ✅ 域名匹配: $($test.ExpectedDomain)" -ForegroundColor Green
            } else {
                Write-Host "      ⚠️ 域名: $location" -ForegroundColor Yellow
            }
        }
        
        $results += @{
            ServiceType = $serviceType
            ShortCode = $shortCode
            Status = "成功"
            RedirectUrl = $location
        }
    } else {
        Write-Host "      ❌ 未找到Location头" -ForegroundColor Red
        Write-Host "      响应: $($curlOutput.Substring(0, [Math]::Min(200, $curlOutput.Length)))" -ForegroundColor Gray
        
        $results += @{
            ServiceType = $serviceType
            ShortCode = $shortCode
            Status = "失败"
            RedirectUrl = "N/A"
        }
    }
    
    Write-Host ""
}

Write-Host "=" * 60
Write-Host "📊 测试总结" -ForegroundColor Green
Write-Host "=" * 60
Write-Host ""

# 统计
$totalTests = $results.Count
$successTests = ($results | Where-Object { $_.Status -eq "成功" }).Count

Write-Host "总测试数: $totalTests"
Write-Host "成功: $successTests" -ForegroundColor Green
Write-Host "失败: $($totalTests - $successTests)" -ForegroundColor $(if ($totalTests -eq $successTests) { "Green" } else { "Red" })
Write-Host ""

# 详细结果表
Write-Host "详细结果:" -ForegroundColor Cyan
$results | ForEach-Object {
    $icon = if ($_.Status -eq "成功") { "✅" } else { "❌" }
    Write-Host "$icon [$($_.ServiceType)] $($_.ShortCode)"
    if ($_.RedirectUrl -ne "N/A") {
        Write-Host "   → $($_.RedirectUrl)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=" * 60
Write-Host "🔍 验证路由引擎日志" -ForegroundColor Cyan
Write-Host "=" * 60
Write-Host ""

Write-Host "查看最近的路由日志..." -ForegroundColor Gray
$logCmd = "tail -50 /usr/local/openresty/nginx/logs/error.log | grep -i 'RoutingEngine\|Selected CDN\|imagebed\|file\|video'"
$logs = docker exec short-link-openresty sh -c $logCmd 2>&1 | Out-String

if ($logs.Trim()) {
    Write-Host $logs
} else {
    Write-Host "  ℹ️ 未找到相关日志（可能日志级别较低）" -ForegroundColor Yellow
    Write-Host "  提示：检查 routing_config_simple.lua 中的日志配置" -ForegroundColor Gray
}

Write-Host ""
Write-Host "✅ 测试完成！" -ForegroundColor Green
Write-Host ""
Write-Host "💡 提示：" -ForegroundColor Yellow
Write-Host "  - 内网环境会自动路由到 'private' CDN节点" -ForegroundColor Gray
Write-Host "  - 要测试运营商分流，需要从不同网络环境访问" -ForegroundColor Gray
Write-Host "  - 可以通过修改 routing_config_simple.lua 自定义规则" -ForegroundColor Gray
Write-Host ""

# 显示创建的测试短链
Write-Host "📋 创建的测试短链：" -ForegroundColor Cyan
$createdLinks | ForEach-Object {
    Write-Host "  http://localhost/$($_.ShortCode)" -ForegroundColor White
}
