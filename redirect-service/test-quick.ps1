# 一键测试新路由架构
# 自动启动服务、运行测试、生成报告

param(
    [switch]$SkipServiceStart,  # 跳过服务启动
    [switch]$QuickTest,         # 快速测试模式（仅核心功能）
    [string]$BaseUrl = "http://localhost:8081"
)

$ErrorActionPreference = "Continue"

Write-Host @"
╔════════════════════════════════════════╗
║  🚀 短链服务新路由架构一键测试  ║
╔════════════════════════════════════════╗
"@ -ForegroundColor Cyan

# 检查并启动服务
if (-not $SkipServiceStart) {
    Write-Host "`n📦 步骤 1: 检查服务状态..." -ForegroundColor Yellow
    
    $containers = docker ps --filter "name=openresty" --format "{{.Names}}"
    
    if (-not $containers) {
        Write-Host "⚠️  OpenResty 容器未运行，正在启动服务..." -ForegroundColor Yellow
        
        Push-Location "c:\Users\DXY\Documents\shortimg-AI"
        
        Write-Host "▶️  执行: docker-compose up -d" -ForegroundColor Gray
        docker-compose up -d
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ 服务启动成功！等待 15 秒..." -ForegroundColor Green
            Start-Sleep -Seconds 15
        } else {
            Write-Host "❌ 服务启动失败！" -ForegroundColor Red
            Pop-Location
            exit 1
        }
        
        Pop-Location
    } else {
        Write-Host "✅ OpenResty 容器已运行: $containers" -ForegroundColor Green
    }
}

# 健康检查
Write-Host "`n🏥 步骤 2: 健康检查..." -ForegroundColor Yellow

try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -ErrorAction Stop
    Write-Host "✅ 服务健康: $($health | ConvertTo-Json -Compress)" -ForegroundColor Green
}
catch {
    Write-Host "❌ 服务不可用: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n💡 提示: 请检查服务是否正常启动" -ForegroundColor Yellow
    Write-Host "    运行命令: docker ps | findstr openresty" -ForegroundColor Gray
    exit 1
}

# 测试结果统计
$script:Results = @{
    Total = 0
    Passed = 0
    Failed = 0
    Tests = @()
}

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method = "POST",
        [string]$Url,
        [object]$Body,
        [scriptblock]$Validator
    )
    
    $script:Results.Total++
    $testResult = @{
        Name = $Name
        Status = "❌ Failed"
        Message = ""
        Duration = 0
    }
    
    Write-Host "`n  📝 $Name" -ForegroundColor Cyan
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = @{ "Content-Type" = "application/json" }
            ErrorAction = "Stop"
        }
        
        if ($Body -and $Method -eq "POST") {
            $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
        }
        
        $response = Invoke-RestMethod @params
        
        $stopwatch.Stop()
        $testResult.Duration = $stopwatch.ElapsedMilliseconds
        
        if ($Validator) {
            $validationResult = & $Validator $response
            if ($validationResult) {
                Write-Host "     ✅ 通过 ($($testResult.Duration)ms)" -ForegroundColor Green
                $testResult.Status = "✅ Passed"
                $script:Results.Passed++
            } else {
                Write-Host "     ❌ 验证失败 ($($testResult.Duration)ms)" -ForegroundColor Red
                $testResult.Message = "Validation failed"
                $script:Results.Failed++
            }
        } else {
            if ($response.success) {
                Write-Host "     ✅ 通过 ($($testResult.Duration)ms)" -ForegroundColor Green
                $testResult.Status = "✅ Passed"
                $script:Results.Passed++
            } else {
                Write-Host "     ❌ 失败: $($response.error) ($($testResult.Duration)ms)" -ForegroundColor Red
                $testResult.Message = $response.error
                $script:Results.Failed++
            }
        }
        
        return $response
    }
    catch {
        $stopwatch.Stop()
        $testResult.Duration = $stopwatch.ElapsedMilliseconds
        Write-Host "     ❌ 异常: $($_.Exception.Message) ($($testResult.Duration)ms)" -ForegroundColor Red
        $testResult.Message = $_.Exception.Message
        $script:Results.Failed++
        return $null
    }
    finally {
        $script:Results.Tests += $testResult
    }
}

# V1 API 测试
Write-Host "`n🧪 步骤 3: V1 API 测试（已迁移）..." -ForegroundColor Yellow

$v1_geo = Test-Endpoint `
    -Name "V1: 创建 GeoIP 路由短链" `
    -Url "$BaseUrl/api/imagebed/create" `
    -Body @{ image_path = "/uploads/2024/test-geo.jpg" } `
    -Validator { param($r) 
        $r.success -and $r.data.strategy -eq "geo+weight" -and $r.data.targets_count -eq 4 
    }

$v1_simple = Test-Endpoint `
    -Name "V1: 创建简单路由短链" `
    -Url "$BaseUrl/api/imagebed/create" `
    -Body @{ image_path = "/uploads/2024/test-simple.jpg"; enable_geo_routing = $false } `
    -Validator { param($r) 
        $r.success -and $r.data.strategy -eq "weight" -and $r.data.targets_count -eq 1 
    }

if (-not $QuickTest) {
    $v1_batch = Test-Endpoint `
        -Name "V1: 批量创建" `
        -Url "$BaseUrl/api/imagebed/batch" `
        -Body @{
            enable_geo_routing = $true
            images = @(
                @{ image_path = "/uploads/2024/batch-1.jpg" }
                @{ image_path = "/uploads/2024/batch-2.jpg" }
            )
        } `
        -Validator { param($r) 
            $r.success -and $r.data.total -eq 2 -and $r.data.success -eq 2 
        }
}

# V2 API 测试
Write-Host "`n🧪 步骤 4: V2 API 测试（新架构）..." -ForegroundColor Yellow

$v2_geo = Test-Endpoint `
    -Name "V2: 创建 GeoIP 路由短链" `
    -Url "$BaseUrl/api/v2/imagebed/create" `
    -Body @{ image_path = "/uploads/2024/v2-test.jpg"; enable_geo_routing = $true } `
    -Validator { param($r) 
        $r.success -and $r.data.strategy -eq "geo+weight" 
    }

$v2_generic = Test-Endpoint `
    -Name "V2: 创建通用短链" `
    -Url "$BaseUrl/api/v2/generic/create" `
    -Body @{ url = "https://github.com/openresty"; custom_code = "test-openresty-$(Get-Random)" } `
    -Validator { param($r) 
        $r.success 
    }

# 路由功能测试
Write-Host "`n🧪 步骤 5: 路由功能测试..." -ForegroundColor Yellow

if ($v1_geo -and $v1_geo.data.code) {
    $code = $v1_geo.data.code
    Write-Host "`n  📝 测试重定向: /$code" -ForegroundColor Cyan
    
    try {
        $redirect = Invoke-WebRequest `
            -Uri "$BaseUrl/$code" `
            -Headers @{ "X-Forwarded-For" = "123.45.67.89" } `
            -MaximumRedirection 0 `
            -ErrorAction SilentlyContinue
        
        if ($redirect.StatusCode -in @(301, 302)) {
            $location = $redirect.Headers.Location
            Write-Host "     ✅ 重定向成功: $location" -ForegroundColor Green
            $script:Results.Passed++
        } else {
            Write-Host "     ❌ 未重定向，状态码: $($redirect.StatusCode)" -ForegroundColor Red
            $script:Results.Failed++
        }
        $script:Results.Total++
    }
    catch {
        Write-Host "     ❌ 重定向失败: $($_.Exception.Message)" -ForegroundColor Red
        $script:Results.Failed++
        $script:Results.Total++
    }
}

# 生成测试报告
Write-Host "`n" -NoNewline
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  📊 测试报告" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`n总测试数: " -NoNewline
Write-Host $script:Results.Total -ForegroundColor White

Write-Host "通过: " -NoNewline
Write-Host $script:Results.Passed -ForegroundColor Green

Write-Host "失败: " -NoNewline
if ($script:Results.Failed -gt 0) {
    Write-Host $script:Results.Failed -ForegroundColor Red
} else {
    Write-Host $script:Results.Failed -ForegroundColor Green
}

$passRate = if ($script:Results.Total -gt 0) {
    [math]::Round(($script:Results.Passed / $script:Results.Total) * 100, 2)
} else {
    0
}

Write-Host "`n通过率: " -NoNewline
if ($passRate -eq 100) {
    Write-Host "$passRate%" -ForegroundColor Green
} elseif ($passRate -ge 80) {
    Write-Host "$passRate%" -ForegroundColor Yellow
} else {
    Write-Host "$passRate%" -ForegroundColor Red
}

# 详细测试结果
if ($script:Results.Failed -gt 0) {
    Write-Host "`n失败的测试:" -ForegroundColor Red
    $script:Results.Tests | Where-Object { $_.Status -like "*Failed*" } | ForEach-Object {
        Write-Host "  ❌ $($_.Name)" -ForegroundColor Red
        if ($_.Message) {
            Write-Host "     原因: $($_.Message)" -ForegroundColor Gray
        }
    }
}

# 性能统计
$avgDuration = ($script:Results.Tests | Measure-Object -Property Duration -Average).Average
Write-Host "`n平均响应时间: $([math]::Round($avgDuration, 2))ms" -ForegroundColor Cyan

Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan

# 最终结论
if ($passRate -eq 100) {
    Write-Host "`n🎉 恭喜！所有测试通过！" -ForegroundColor Green
    Write-Host "✅ V1 API 已成功迁移到新架构" -ForegroundColor Green
    Write-Host "✅ V2 API 工作正常" -ForegroundColor Green
    Write-Host "✅ 路由功能验证通过" -ForegroundColor Green
    exit 0
} elseif ($passRate -ge 80) {
    Write-Host "`n⚠️  大部分测试通过，但有少量失败" -ForegroundColor Yellow
    Write-Host "请检查上述失败的测试项" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "`n❌ 测试失败较多，请检查配置和日志" -ForegroundColor Red
    Write-Host "`n💡 故障排查建议:" -ForegroundColor Yellow
    Write-Host "   1. 查看容器日志: docker logs shortlink-openresty-1 --tail 50" -ForegroundColor Gray
    Write-Host "   2. 检查数据库连接: docker exec -it shortlink-mysql-1 mysql -u root -p" -ForegroundColor Gray
    Write-Host "   3. 检查 Redis: docker exec -it shortlink-redis-1 redis-cli ping" -ForegroundColor Gray
    exit 1
}
