# 测试新路由架构脚本
# 测试 V1 API (已迁移) 和 V2 API

$BaseUrl = "http://localhost:8081"
$Domain = "short.oxvxo.link"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  🧪 短链服务新路由架构测试" -ForegroundColor Cyan
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
# 1. 测试 V1 API (已迁移到新架构)
# =====================================

Write-Host "`n🔷 V1 API 测试（已迁移）" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# 1.1 创建图床短链 - 启用 GeoIP 路由（默认）
$response1 = Test-API `
    -Name "V1: 创建图床短链 - 默认启用 GeoIP" `
    -Url "$BaseUrl/api/imagebed/create" `
    -Body @{
        image_path = "/uploads/2024/test-geo-routing.jpg"
    } `
    -Validator {
        param($r)
        $r.success -and 
        $r.data.code -match "^img-" -and
        $r.data.strategy -eq "geo+weight" -and
        $r.data.targets_count -eq 4 -and
        $r.data.geo_routing_enabled -eq $true
    }

# 1.2 创建图床短链 - 禁用 GeoIP 路由
$response2 = Test-API `
    -Name "V1: 创建图床短链 - 禁用 GeoIP" `
    -Url "$BaseUrl/api/imagebed/create" `
    -Body @{
        image_path = "/uploads/2024/test-simple.jpg"
        enable_geo_routing = $false
    } `
    -Validator {
        param($r)
        $r.success -and 
        $r.data.code -match "^img-" -and
        $r.data.strategy -eq "weight" -and
        $r.data.targets_count -eq 1 -and
        $r.data.geo_routing_enabled -eq $false
    }

# 1.3 创建通用短链
$response3 = Test-API `
    -Name "V1: 创建通用短链（完整URL）" `
    -Url "$BaseUrl/api/imagebed/create" `
    -Body @{
        image_url = "https://www.example.com/page.html"
    } `
    -Validator {
        param($r)
        $r.success -and 
        $r.data.code -match "^img-" -and
        $r.data.strategy -eq "weight" -and
        $r.data.targets_count -eq 1
    }

# 1.4 批量创建 - 启用 GeoIP
$response4 = Test-API `
    -Name "V1: 批量创建图床短链 - 启用 GeoIP" `
    -Url "$BaseUrl/api/imagebed/batch" `
    -Body @{
        enable_geo_routing = $true
        images = @(
            @{ image_path = "/uploads/2024/batch-1.jpg" }
            @{ image_path = "/uploads/2024/batch-2.jpg" }
            @{ image_path = "/uploads/2024/batch-3.jpg" }
        )
    } `
    -Validator {
        param($r)
        $r.success -and 
        $r.data.total -eq 3 -and
        $r.data.success -eq 3 -and
        $r.data.results[0].strategy -eq "geo+weight" -and
        $r.data.results[0].targets_count -eq 4
    }

# =====================================
# 2. 测试 V2 API (新架构)
# =====================================

Write-Host "`n🔷 V2 API 测试（新架构）" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# 2.1 创建图床短链 - 启用 GeoIP
$response5 = Test-API `
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
$response6 = Test-API `
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
$response7 = Test-API `
    -Name "V2: 批量创建" `
    -Url "$BaseUrl/api/v2/imagebed/batch" `
    -Body @{
        enable_geo_routing = $true
        images = @(
            @{ image_path = "/uploads/2024/v2-batch-1.jpg" }
            @{ image_path = "/uploads/2024/v2-batch-2.jpg"; custom_code = "v2-custom" }
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
$response8 = Test-API `
    -Name "V2: 创建通用短链" `
    -Url "$BaseUrl/api/v2/generic/create" `
    -Body @{
        url = "https://github.com/openresty/openresty"
        custom_code = "github-openresty"
    } `
    -Validator {
        param($r)
        $r.success -and 
        $r.data.code -eq "github-openresty" -and
        $r.data.strategy -eq "weight"
    }

# =====================================
# 3. 测试路由功能
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
            
            if ($location -match "cdn-north|cdn.*telecom|img\.oxvxo\.link") {
                Write-Success "路由正确：匹配北方/电信 CDN"
                $script:PassedTests++
            } else {
                Write-Error "路由可能不正确：$location"
                $script:FailedTests++
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
            
            if ($location -match "img\.oxvxo\.link") {
                Write-Success "路由正确：使用主图床"
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

# =====================================
# 4. 查询短链信息
# =====================================

Write-Host "`n🔷 查询短链信息" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

if ($response1 -and $response1.data.code) {
    $code = $response1.data.code
    Test-API `
        -Name "查询短链信息: $code" `
        -Url "$BaseUrl/api/imagebed/info/$code" `
        -Method GET `
        -Validator {
            param($r)
            $r.success -and $r.data.code -eq $code
        }
}

# =====================================
# 测试总结
# =====================================

Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "  📊 测试总结" -ForegroundColor Cyan
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
} elseif ($passRate -ge 80) {
    Write-Host "⚠️  大部分测试通过，通过率: $passRate%" -ForegroundColor Yellow
} else {
    Write-Host "❌ 测试失败较多，通过率: $passRate%" -ForegroundColor Red
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan

# 返回退出代码
if ($script:FailedTests -gt 0) {
    exit 1
} else {
    exit 0
}
