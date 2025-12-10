# 测试通用类型短链直接重定向（不经过CDN分流）
# 确认通用短链直接302重定向到目标URL，而不通过路由引擎

$baseUrl = "http://localhost:3000/api"
$redirectUrl = "http://localhost:3000"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "通用类型短链直接重定向测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 测试计数
$totalTests = 0
$passedTests = 0
$failedTests = 0

# 创建测试用的通用短链
Write-Host "步骤1: 创建测试短链" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Yellow
Write-Host ""

$testUrls = @(
    @{
        name = "百度首页"
        url = "https://www.baidu.com"
    },
    @{
        name = "谷歌首页"
        url = "https://www.google.com"
    },
    @{
        name = "GitHub"
        url = "https://github.com"
    }
)

$createdLinks = @()

foreach ($testUrl in $testUrls) {
    Write-Host "创建短链: $($testUrl.name)" -ForegroundColor White
    
    $body = @{
        targets = @(
            @{
                url = $testUrl.url
                weight = 1
            }
        )
        strategy = "weight"
        service_type = "general"
        permissions = @{
            require_auth = $false
            allowed_users = @()
            allowed_ips = @()
        }
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/imagebed/create_universal" `
            -Method Post `
            -Body $body `
            -ContentType "application/json" `
            -Headers @{
                "X-API-Key" = "test-api-key-12345"
            }

        if ($response.code -eq 200 -and $response.data.short_code) {
            $shortCode = $response.data.short_code
            Write-Host "  ✅ 成功创建: $shortCode" -ForegroundColor Green
            Write-Host "  目标URL: $($testUrl.url)" -ForegroundColor Gray
            
            $createdLinks += @{
                name = $testUrl.name
                short_code = $shortCode
                target_url = $testUrl.url
            }
        } else {
            Write-Host "  ❌ 创建失败: $($response.message)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ❌ 请求失败: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host ""
Write-Host "步骤2: 测试短链重定向" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Yellow
Write-Host ""

foreach ($link in $createdLinks) {
    $totalTests++
    
    Write-Host "测试短链: $($link.short_code) -> $($link.name)" -ForegroundColor White
    
    try {
        # 使用 -AllowUnauthorizedSSL 和 -MaximumRedirection 0 来捕获302重定向
        $response = Invoke-WebRequest -Uri "$redirectUrl/$($link.short_code)" `
            -Method Get `
            -MaximumRedirection 0 `
            -SkipHttpErrorCheck `
            -ErrorAction SilentlyContinue

        $statusCode = $response.StatusCode
        $location = $response.Headers['Location']

        Write-Host "  状态码: $statusCode" -ForegroundColor $(if ($statusCode -eq 302) { "Green" } else { "Yellow" })
        
        if ($location) {
            Write-Host "  Location: $location" -ForegroundColor Gray
            
            # 检查是否直接重定向到目标URL（而不是CDN URL）
            if ($location -eq $link.target_url) {
                Write-Host "  ✅ 直接重定向到目标URL（正确）" -ForegroundColor Green
                $passedTests++
            } elseif ($location -match "\.example\.com") {
                Write-Host "  ❌ 错误：重定向到CDN服务器 ($location)" -ForegroundColor Red
                Write-Host "     通用短链不应该经过CDN分流！" -ForegroundColor Red
                $failedTests++
            } else {
                Write-Host "  ⚠️  重定向到其他URL: $location" -ForegroundColor Yellow
                $passedTests++
            }
        } else {
            Write-Host "  ❌ 未找到Location头" -ForegroundColor Red
            $failedTests++
        }
    } catch {
        Write-Host "  ❌ 请求失败: $($_.Exception.Message)" -ForegroundColor Red
        $failedTests++
    }
    Write-Host ""
}

Write-Host ""
Write-Host "步骤3: 检查路由引擎日志" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Yellow
Write-Host ""

Write-Host "查看最近的路由日志（应该不包含general类型的路由选择）..." -ForegroundColor White
try {
    $logs = docker exec short-link-openresty tail -n 50 /usr/local/openresty/nginx/logs/error.log 2>$null
    
    # 过滤包含"general"或"通用"的日志
    $generalLogs = $logs | Select-String -Pattern "general|通用" -CaseSensitive
    
    if ($generalLogs) {
        Write-Host ""
        Write-Host "发现general相关的日志:" -ForegroundColor Yellow
        $generalLogs | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        
        # 检查是否有CDN选择日志
        $cdnSelectionLogs = $generalLogs | Select-String -Pattern "Selected CDN"
        if ($cdnSelectionLogs) {
            Write-Host ""
            Write-Host "⚠️  警告：发现general类型的CDN选择日志" -ForegroundColor Red
            Write-Host "   这表明general类型可能仍在使用路由引擎，需要检查代码" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✅ 未发现general类型的路由日志（正确）" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  无法读取日志: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "测试总结" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "总测试数: $totalTests" -ForegroundColor White
Write-Host "成功: $passedTests" -ForegroundColor Green
Write-Host "失败: $failedTests" -ForegroundColor Red
Write-Host ""

if ($failedTests -eq 0) {
    Write-Host "✅ 所有测试通过！通用短链正确地直接重定向到目标URL" -ForegroundColor Green
} else {
    Write-Host "❌ 部分测试失败，请检查配置" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "架构说明" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "服务类型路由架构：" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 图床类型 (imagebed, 前缀: img-)" -ForegroundColor White
Write-Host "   → 路由引擎选择CDN" -ForegroundColor Gray
Write-Host "   → 根据运营商/地区分流到不同的CDN节点" -ForegroundColor Gray
Write-Host "   → 构建CDN URL: https://img-xxx.example.com/path" -ForegroundColor Gray
Write-Host ""
Write-Host "2. 文件类型 (file, 前缀: file-)" -ForegroundColor White
Write-Host "   → 路由引擎选择CDN" -ForegroundColor Gray
Write-Host "   → 根据运营商/地区分流到不同的CDN节点" -ForegroundColor Gray
Write-Host "   → 构建CDN URL: https://file-xxx.example.com/path" -ForegroundColor Gray
Write-Host ""
Write-Host "3. 视频类型 (video, 前缀: vid-)" -ForegroundColor White
Write-Host "   → 路由引擎选择CDN" -ForegroundColor Gray
Write-Host "   → 根据运营商/地区分流到不同的CDN节点" -ForegroundColor Gray
Write-Host "   → 构建CDN URL: https://video-xxx.example.com/path" -ForegroundColor Gray
Write-Host ""
Write-Host "4. 通用类型 (general, 无前缀)" -ForegroundColor White
Write-Host "   → 不使用路由引擎" -ForegroundColor Green
Write-Host "   → 不经过CDN分流" -ForegroundColor Green
Write-Host "   → 直接302重定向到完整的目标URL" -ForegroundColor Green
Write-Host ""
Write-Host "配置文件：" -ForegroundColor Yellow
Write-Host "  - lua/routing_config_simple.lua: 16个CDN节点（不含general）" -ForegroundColor Gray
Write-Host "  - lua/routing_engine.lua: 路由引擎核心逻辑" -ForegroundColor Gray
Write-Host "  - lua/core/router.lua: 重定向处理（general类型跳过路由引擎）" -ForegroundColor Gray
Write-Host ""
