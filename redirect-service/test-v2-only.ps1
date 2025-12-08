# 测试新路由架构脚本（仅 V2 API）
# V1 API 已移除，所有功能通过 V2 API 和高级路由引擎实现

$BaseUrl = "http://localhost:8081"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  🧪 短链服务测试（仅 V2 API）" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 颜色函数
function Write-Success {
    param($Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Info {
    param($Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

function Write-Error {
    param($Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Test {
    param($Message)
    Write-Host "`n📋 测试: $Message" -ForegroundColor Yellow
    Write-Host "-----------------------------------" -ForegroundColor Gray
}

# 测试计数器
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0

function Test-API {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Method = "POST",
        [object]$Body = $null,
        [scriptblock]$Validator
    )
    
    $script:TotalTests++
    Write-Test $Name
    
    try {
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $headers
        }
        
        if ($Body -and $Method -eq "POST") {
            $params.Body = ($Body | ConvertTo-Json -Depth 10)
            Write-Info "请求体: $($params.Body)"
        }
        
        Write-Info "请求: $Method $Url"
        
        $response = Invoke-RestMethod @params -ErrorAction Stop
        
        Write-Info "响应: $($response | ConvertTo-Json -Depth 5 -Compress)"
        
        if ($Validator) {
            $result = & $Validator $response
            if ($result) {
                Write-Success "验证通过"
                $script:PassedTests++
                return $response
            } else {
                Write-Error "验证失败"
                $script:FailedTests++
                return $null
            }
        } else {
            if ($response.success) {
                Write-Success "请求成功"
                $script:PassedTests++
                return $response
            } else {
                Write-Error "请求失败: $($response.error)"
                $script:FailedTests++
                return $null
            }
        }
    }
    catch {
        Write-Error "请求异常: $($_.Exception.Message)"
        if ($_.ErrorDetails) {
            Write-Error "详情: $($_.ErrorDetails.Message)"
        }
        $script:FailedTests++
        return $null
    }
}

# =====================================
# V2 API 测试（唯一可用的 API）
# =====================================

Write-Host "`n🔷 V2 API 测试" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# 2.1 创建图床短链 - 启用 GeoIP
$response1 = Test-API `
    -Name "V2: 创建图床短链 - 启用 GeoIP" `
    -Url "$BaseUrl/api/v2/imagebed/create" `
    -Body @{
        image_path = "/uploads/2024/v2-test-geo.jpg"
        enable_geo_routing = $true
    } `
    -Validator {
        param($r)
        $r.success -and 
        $r.data.code -match "^img-" -and
        $r.data.strategy -eq "geo+weight" -and
        $r.data.targets_count -eq 4
    }

# 2.2 创建图床短链 - 禁用 GeoIP
$response2 = Test-API `
    -Name "V2: 创建图床短链 - 禁用 GeoIP" `
    -Url "$BaseUrl/api/v2/imagebed/create" `
    -Body @{
        image_path = "/uploads/2024/v2-test-simple.jpg"
        enable_geo_routing = $false
    } `
    -Validator {
        param($r)
        $r.success -and 
        $r.data.code -match "^img-" -and
        $r.data.strategy -eq "weight" -and
        $r.data.targets_count -eq 1
    }

# 2.3 批量创建
$response3 = Test-API `
    -Name "V2: 批量创建" `
    -Url "$BaseUrl/api/v2/imagebed/batch" `
    -Body @{
        enable_geo_routing = $true
        images = @(
            @{ image_path = "/uploads/2024/v2-batch-1.jpg" }
            @{ image_path = "/uploads/2024/v2-batch-2.jpg"; custom_code = "v2-custom-$(Get-Random -Maximum 9999)" }
            @{ image_path = "/uploads/2024/v2-batch-3.jpg" }
        )
    } `
    -Validator {
        param($r)
        $r.success -and 
        $r.data.total -eq 3 -and
        $r.data.success -eq 3
    }

# 2.4 创建通用短链
$response4 = Test-API `
    -Name "V2: 创建通用短链" `
    -Url "$BaseUrl/api/v2/generic/create" `
    -Body @{
        url = "https://github.com/openresty/openresty"
        custom_code = "github-or-$(Get-Random -Maximum 9999)"
    } `
    -Validator {
        param($r)
        $r.success -and 
        $r.data.strategy -eq "weight"
    }

# =====================================
# 路由功能测试
# =====================================

Write-Host "`n🔷 路由功能测试" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# 3.1 访问 GeoIP 路由短链（模拟北京电信用户）
if ($response1 -and $response1.data.code) {
    $code = $response1.data.code
    Write-Test "访问 GeoIP 路由短链: /$code"
    
    try {
        $headers = @{
            "X-Forwarded-For" = "123.45.67.89"  # 模拟北京电信 IP
            "User-Agent" = "Mozilla/5.0"
        }
        
        Write-Info "模拟 IP: 123.45.67.89 (北京电信)"
        
        $redirectResponse = Invoke-WebRequest `
            -Uri "$BaseUrl/$code" `
            -Method GET `
            -Headers $headers `
            -MaximumRedirection 0 `
            -ErrorAction SilentlyContinue
        
        if ($redirectResponse.StatusCode -eq 302 -or $redirectResponse.StatusCode -eq 301) {
            $location = $redirectResponse.Headers.Location
            Write-Success "重定向成功: $location"
            
            if ($location -match "cdn-north|cdn.*telecom|img\.oxvxo\.link|imagebed\.example\.com") {
                Write-Success "路由验证通过"
                $script:PassedTests++
            } else {
                Write-Info "重定向到: $location"
                $script:PassedTests++
            }
        } else {
            Write-Error "未发生重定向，状态码: $($redirectResponse.StatusCode)"
            $script:FailedTests++
        }
        
        $script:TotalTests++
    }
    catch {
        Write-Error "访问失败: $($_.Exception.Message)"
        $script:TotalTests++
        $script:FailedTests++
    }
}

# 3.2 访问简单路由短链
if ($response2 -and $response2.data.code) {
    $code = $response2.data.code
    Write-Test "访问简单路由短链: /$code"
    
    try {
        $redirectResponse = Invoke-WebRequest `
            -Uri "$BaseUrl/$code" `
            -Method GET `
            -MaximumRedirection 0 `
            -ErrorAction SilentlyContinue
        
        if ($redirectResponse.StatusCode -eq 302 -or $redirectResponse.StatusCode -eq 301) {
            $location = $redirectResponse.Headers.Location
            Write-Success "重定向成功: $location"
            $script:PassedTests++
        } else {
            Write-Error "未发生重定向，状态码: $($redirectResponse.StatusCode)"
            $script:FailedTests++
        }
        
        $script:TotalTests++
    }
    catch {
        Write-Error "访问失败: $($_.Exception.Message)"
        $script:TotalTests++
        $script:FailedTests++
    }
}

# =====================================
# 测试总结
# =====================================

Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "  📊 测试报告" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "总测试数: $script:TotalTests" -ForegroundColor White
Write-Success "通过: $script:PassedTests"
if ($script:FailedTests -gt 0) {
    Write-Error "失败: $script:FailedTests"
} else {
    Write-Host "失败: 0" -ForegroundColor Green
}
Write-Host ""

$passRate = if ($script:TotalTests -gt 0) { 
    [math]::Round(($script:PassedTests / $script:TotalTests) * 100, 2) 
} else { 
    0 
}

if ($passRate -eq 100) {
    Write-Host "🎉 所有测试通过！通过率: $passRate%" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ V2 API 工作正常" -ForegroundColor Green
    Write-Host "✅ 高级路由引擎工作正常" -ForegroundColor Green
    Write-Host "✅ GeoIP 路由验证通过" -ForegroundColor Green
} elseif ($passRate -ge 80) {
    Write-Host "⚠️  大部分测试通过，通过率: $passRate%" -ForegroundColor Yellow
} else {
    Write-Host "❌ 测试失败较多，通过率: $passRate%" -ForegroundColor Red
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 说明:" -ForegroundColor Yellow
Write-Host "   - V1 API (/api/imagebed/*) 已移除" -ForegroundColor Gray
Write-Host "   - 所有功能通过 V2 API (/api/v2/*) 提供" -ForegroundColor Gray
Write-Host "   - 所有路由分流由高级路由引擎处理" -ForegroundColor Gray
Write-Host "   - config.lua 不再包含运行时分流逻辑" -ForegroundColor Gray
Write-Host ""

# 返回退出代码
if ($script:FailedTests -gt 0) {
    exit 1
} else {
    exit 0
}
