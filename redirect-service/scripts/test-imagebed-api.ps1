# 图床短链 API 测试脚本
# 功能：测试所有图床短链API端点

param(
  [string]$BaseUrl = "http://localhost",
  [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$testResults = @()

# 颜色输出函数
function Write-Success {
  param([string]$Message)
  Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Failure {
  param([string]$Message)
  Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
  param([string]$Message)
  Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Write-Section {
  param([string]$Title)
  Write-Host "`n========================================" -ForegroundColor Yellow
  Write-Host "  $Title" -ForegroundColor Yellow
  Write-Host "========================================`n" -ForegroundColor Yellow
}

# 记录测试结果
function Add-TestResult {
  param(
    [string]$TestName,
    [bool]$Success,
    [string]$Details = ""
  )

  $script:testResults += [PSCustomObject]@{
    TestName = $TestName
    Success  = $Success
    Details  = $Details
  }
}

# HTTP请求函数
function Invoke-ApiRequest {
  param(
    [string]$Method,
    [string]$Endpoint,
    [object]$Body = $null
  )

  $url = "$BaseUrl$Endpoint"

  try {
    $params = @{
      Uri             = $url
      Method          = $Method
      ContentType     = "application/json"
      UseBasicParsing = $true
    }

    if ($Body) {
      $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }

    if ($Verbose) {
      Write-Info "Request: $Method $url"
      if ($Body) {
        Write-Host ($Body | ConvertTo-Json -Depth 10) -ForegroundColor Gray
      }
    }

    $response = Invoke-WebRequest @params
    $content = $response.Content | ConvertFrom-Json

    if ($Verbose) {
      Write-Info "Response:"
      Write-Host ($content | ConvertTo-Json -Depth 10) -ForegroundColor Gray
    }

    return $content
  }
  catch {
    Write-Failure "请求失败: $_"
    if ($_.Exception.Response) {
      $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
      $responseBody = $reader.ReadToEnd()
      Write-Host "Error Response: $responseBody" -ForegroundColor Red
    }
    return $null
  }
}

# 生成随机代码
function Get-RandomCode {
  param([int]$Length = 8)
  -join ((65..90) + (97..122) + (48..57) | Get-Random -Count $Length | ForEach-Object { [char]$_ })
}

Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           图床短链 API 测试脚本                              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Info "测试目标: $BaseUrl"
Write-Info "开始时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# 全局变量
$testCode1 = "test_img_$(Get-RandomCode -Length 6)"
$testCode2 = "test_img_$(Get-RandomCode -Length 6)"
$batchCodes = @()

#region 测试 1: 创建单个图床短链
Write-Section "测试 1: 创建单个图床短链"

$createData = @{
  image_url   = "https://example.com/images/test-photo.jpg"
  custom_code = $testCode1
  expire_time = 86400  # 1天
  metadata    = @{
    filename    = "test-photo.jpg"
    size        = 1024000
    type        = "image/jpeg"
    description = "测试图片"
    tags        = @("test", "sample")
    album       = "测试相册"
  }
}

Write-Info "创建图床短链 (代码: $testCode1)"
$result = Invoke-ApiRequest -Method POST -Endpoint "/api/imagebed/create" -Body $createData

if ($result -and $result.success) {
  Write-Success "成功创建图床短链"
  Write-Host "  代码: $($result.data.code)" -ForegroundColor Gray
  Write-Host "  短链: $($result.data.short_url)" -ForegroundColor Gray
  Write-Host "  原链: $($result.data.long_url)" -ForegroundColor Gray
  Write-Host "  过期: $(if ($result.data.expire_at) { [DateTimeOffset]::FromUnixTimeSeconds($result.data.expire_at).LocalDateTime } else { '永不过期' })" -ForegroundColor Gray
  Add-TestResult -TestName "创建单个图床短链" -Success $true
}
else {
  Write-Failure "创建图床短链失败"
  Add-TestResult -TestName "创建单个图床短链" -Success $false
}
#endregion

#region 测试 2: 创建短链（自动生成代码）
Write-Section "测试 2: 创建短链（自动生成代码）"

$autoData = @{
  image_url = "https://example.com/images/auto-photo.jpg"
  metadata  = @{
    filename = "auto-photo.jpg"
    size     = 2048000
  }
}

Write-Info "创建图床短链（自动代码）"
$result = Invoke-ApiRequest -Method POST -Endpoint "/api/imagebed/create" -Body $autoData

if ($result -and $result.success) {
  Write-Success "成功创建图床短链（自动代码）"
  Write-Host "  自动代码: $($result.data.code)" -ForegroundColor Gray
  $testCode2 = $result.data.code
  Add-TestResult -TestName "自动生成代码" -Success $true
}
else {
  Write-Failure "创建图床短链失败（自动代码）"
  Add-TestResult -TestName "自动生成代码" -Success $false
}
#endregion

#region 测试 3: 批量创建图床短链
Write-Section "测试 3: 批量创建图床短链"

$batchData = @{
  images      = @(
    @{
      image_url   = "https://example.com/images/batch1.jpg"
      custom_code = "batch_$(Get-RandomCode -Length 6)"
      metadata    = @{
        filename = "batch1.jpg"
        size     = 500000
      }
    },
    @{
      image_url   = "https://example.com/images/batch2.jpg"
      custom_code = "batch_$(Get-RandomCode -Length 6)"
      metadata    = @{
        filename = "batch2.jpg"
        size     = 750000
      }
    },
    @{
      image_url   = "https://example.com/images/batch3.jpg"
      custom_code = "batch_$(Get-RandomCode -Length 6)"
      metadata    = @{
        filename = "batch3.jpg"
        size     = 600000
      }
    }
  )
  expire_time = 3600  # 1小时
}

Write-Info "批量创建 $($batchData.images.Count) 个图床短链"
$result = Invoke-ApiRequest -Method POST -Endpoint "/api/imagebed/batch" -Body $batchData

if ($result -and $result.success) {
  Write-Success "批量创建成功"
  Write-Host "  总数: $($result.data.total)" -ForegroundColor Gray
  Write-Host "  成功: $($result.data.success)" -ForegroundColor Green
  Write-Host "  失败: $($result.data.failed)" -ForegroundColor $(if ($result.data.failed -gt 0) { "Red" } else { "Gray" })

  foreach ($item in $result.data.results) {
    if ($item.success) {
      $batchCodes += $item.code
      Write-Host "    ✓ $($item.code): $($item.short_url)" -ForegroundColor Green
    }
    else {
      Write-Host "    ✗ 失败: $($item.error)" -ForegroundColor Red
    }
  }

  Add-TestResult -TestName "批量创建图床短链" -Success $true -Details "成功: $($result.data.success), 失败: $($result.data.failed)"
}
else {
  Write-Failure "批量创建失败"
  Add-TestResult -TestName "批量创建图床短链" -Success $false
}
#endregion

#region 测试 4: 获取图床短链信息
Write-Section "测试 4: 获取图床短链信息"

Write-Info "获取短链信息: $testCode1"
$result = Invoke-ApiRequest -Method GET -Endpoint "/api/imagebed/info/$testCode1"

if ($result -and $result.success) {
  Write-Success "成功获取短链信息"
  Write-Host "  代码: $($result.data.code)" -ForegroundColor Gray
  Write-Host "  原链: $($result.data.long_url)" -ForegroundColor Gray
  Write-Host "  点击: $($result.data.click_count)" -ForegroundColor Gray
  Write-Host "  元数据:" -ForegroundColor Gray
  Write-Host "    类型: $($result.data.metadata.type)" -ForegroundColor Gray
  Write-Host "    创建者: $($result.data.metadata.created_by)" -ForegroundColor Gray
  Write-Host "    文件名: $($result.data.metadata.filename)" -ForegroundColor Gray
  Write-Host "    大小: $($result.data.metadata.size) bytes" -ForegroundColor Gray
  Write-Host "  缓存: $(if ($result.data.from_cache) { '是' } else { '否' })" -ForegroundColor Gray
  Add-TestResult -TestName "获取短链信息" -Success $true
}
else {
  Write-Failure "获取短链信息失败"
  Add-TestResult -TestName "获取短链信息" -Success $false
}
#endregion

#region 测试 5: 更新图床短链元数据
Write-Section "测试 5: 更新图床短链元数据"

$updateData = @{
  description  = "更新后的描述"
  tags         = @("updated", "test", "2024")
  album        = "更新后的相册"
  custom_field = "自定义值"
}

Write-Info "更新短链元数据: $testCode1"
$result = Invoke-ApiRequest -Method PUT -Endpoint "/api/imagebed/metadata/$testCode1" -Body $updateData

if ($result -and $result.success) {
  Write-Success "成功更新元数据"
  Write-Host "  代码: $($result.data.code)" -ForegroundColor Gray
  Write-Host "  元数据:" -ForegroundColor Gray
  Write-Host "    描述: $($result.data.metadata.description)" -ForegroundColor Gray
  Write-Host "    标签: $($result.data.metadata.tags -join ', ')" -ForegroundColor Gray
  Write-Host "    相册: $($result.data.metadata.album)" -ForegroundColor Gray
  Write-Host "  更新时间: $(if ($result.data.updated_at) { [DateTimeOffset]::FromUnixTimeSeconds($result.data.updated_at).LocalDateTime } else { 'N/A' })" -ForegroundColor Gray
  Add-TestResult -TestName "更新元数据" -Success $true
}
else {
  Write-Failure "更新元数据失败"
  Add-TestResult -TestName "更新元数据" -Success $false
}
#endregion

#region 测试 6: 验证元数据更新
Write-Section "测试 6: 验证元数据更新"

Write-Info "重新获取短链信息验证更新"
$result = Invoke-ApiRequest -Method GET -Endpoint "/api/imagebed/info/$testCode1"

if ($result -and $result.success) {
  $metadata = $result.data.metadata
  $isValid = ($metadata.description -eq "更新后的描述") -and
  ($metadata.album -eq "更新后的相册") -and
  ($metadata.tags -contains "updated")

  if ($isValid) {
    Write-Success "元数据更新验证成功"
    Write-Host "  描述: $($metadata.description)" -ForegroundColor Green
    Write-Host "  相册: $($metadata.album)" -ForegroundColor Green
    Write-Host "  标签: $($metadata.tags -join ', ')" -ForegroundColor Green
    Add-TestResult -TestName "验证元数据更新" -Success $true
  }
  else {
    Write-Failure "元数据更新验证失败"
    Add-TestResult -TestName "验证元数据更新" -Success $false
  }
}
else {
  Write-Failure "无法验证元数据更新"
  Add-TestResult -TestName "验证元数据更新" -Success $false
}
#endregion

#region 测试 7: 获取图床统计信息
Write-Section "测试 7: 获取图床统计信息"

Write-Info "获取图床统计信息"
$result = Invoke-ApiRequest -Method GET -Endpoint "/api/imagebed/stats"

if ($result -and $result.success) {
  Write-Success "成功获取统计信息"
  Write-Host "  图床短链总数: $($result.data.total_links)" -ForegroundColor Gray
  Write-Host "  今日创建: $($result.data.today_created)" -ForegroundColor Gray
  Write-Host "  总点击数: $($result.data.total_clicks)" -ForegroundColor Gray

  if ($result.data.top_images -and $result.data.top_images.Count -gt 0) {
    Write-Host "  热门图片 Top $($result.data.top_images.Count):" -ForegroundColor Gray
    foreach ($img in $result.data.top_images) {
      Write-Host "    - $($img.code): $($img.click_count) 次点击" -ForegroundColor Gray
    }
  }
  else {
    Write-Host "  暂无热门图片数据" -ForegroundColor Gray
  }

  Add-TestResult -TestName "获取统计信息" -Success $true
}
else {
  Write-Failure "获取统计信息失败"
  Add-TestResult -TestName "获取统计信息" -Success $false
}
#endregion

#region 测试 8: 错误处理 - 无效的图片URL
Write-Section "测试 8: 错误处理 - 无效的图片URL"

$invalidData = @{
  image_url   = "not-a-valid-url"
  custom_code = "invalid_$(Get-RandomCode -Length 6)"
}

Write-Info "测试无效的图片URL"
$result = Invoke-ApiRequest -Method POST -Endpoint "/api/imagebed/create" -Body $invalidData

if ($result -and -not $result.success) {
  Write-Success "正确处理无效URL错误"
  Write-Host "  错误信息: $($result.error)" -ForegroundColor Gray
  Add-TestResult -TestName "无效URL错误处理" -Success $true
}
else {
  Write-Failure "未能正确处理无效URL"
  Add-TestResult -TestName "无效URL错误处理" -Success $false
}
#endregion

#region 测试 9: 错误处理 - 重复的自定义代码
Write-Section "测试 9: 错误处理 - 重复的自定义代码"

$duplicateData = @{
  image_url   = "https://example.com/images/duplicate.jpg"
  custom_code = $testCode1  # 使用已存在的代码
}

Write-Info "测试重复的自定义代码"
$result = Invoke-ApiRequest -Method POST -Endpoint "/api/imagebed/create" -Body $duplicateData

if ($result -and -not $result.success) {
  Write-Success "正确处理重复代码错误"
  Write-Host "  错误信息: $($result.error)" -ForegroundColor Gray
  Add-TestResult -TestName "重复代码错误处理" -Success $true
}
else {
  Write-Failure "未能正确处理重复代码"
  Add-TestResult -TestName "重复代码错误处理" -Success $false
}
#endregion

#region 测试 10: 错误处理 - 不存在的短链
Write-Section "测试 10: 错误处理 - 不存在的短链"

$nonExistentCode = "nonexistent_$(Get-RandomCode -Length 10)"

Write-Info "测试不存在的短链: $nonExistentCode"
$result = Invoke-ApiRequest -Method GET -Endpoint "/api/imagebed/info/$nonExistentCode"

if ($result -and -not $result.success) {
  Write-Success "正确处理不存在的短链"
  Write-Host "  错误信息: $($result.error)" -ForegroundColor Gray
  Add-TestResult -TestName "不存在短链错误处理" -Success $true
}
else {
  Write-Failure "未能正确处理不存在的短链"
  Add-TestResult -TestName "不存在短链错误处理" -Success $false
}
#endregion

#region 测试 11: 批量创建 - 部分失败场景
Write-Section "测试 11: 批量创建 - 部分失败场景"

$mixedBatchData = @{
  images = @(
    @{
      image_url   = "https://example.com/images/valid1.jpg"
      custom_code = "valid_$(Get-RandomCode -Length 6)"
    },
    @{
      image_url   = "invalid-url"  # 无效URL
      custom_code = "invalid_$(Get-RandomCode -Length 6)"
    },
    @{
      image_url   = "https://example.com/images/valid2.jpg"
      custom_code = $testCode1  # 重复代码
    },
    @{
      image_url   = "https://example.com/images/valid3.jpg"
      custom_code = "valid3_$(Get-RandomCode -Length 6)"
    }
  )
}

Write-Info "测试部分成功/失败的批量创建"
$result = Invoke-ApiRequest -Method POST -Endpoint "/api/imagebed/batch" -Body $mixedBatchData

if ($result -and $result.success) {
  Write-Success "批量创建完成（部分成功）"
  Write-Host "  总数: $($result.data.total)" -ForegroundColor Gray
  Write-Host "  成功: $($result.data.success)" -ForegroundColor Green
  Write-Host "  失败: $($result.data.failed)" -ForegroundColor Yellow

  $expectedSuccess = 2
  $expectedFailed = 2

  if ($result.data.success -ge $expectedSuccess -and $result.data.failed -ge $expectedFailed) {
    Write-Success "部分失败场景处理正确"
    Add-TestResult -TestName "批量创建部分失败" -Success $true
  }
  else {
    Write-Failure "部分失败场景处理不符合预期"
    Add-TestResult -TestName "批量创建部分失败" -Success $false
  }
}
else {
  Write-Failure "批量创建测试失败"
  Add-TestResult -TestName "批量创建部分失败" -Success $false
}
#endregion

#region 测试总结
Write-Section "测试总结"

$totalTests = $testResults.Count
$passedTests = ($testResults | Where-Object { $_.Success }).Count
$failedTests = $totalTests - $passedTests
$passRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }

Write-Host "测试完成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host ""
Write-Host "总计测试: $totalTests" -ForegroundColor White
Write-Host "通过: $passedTests" -ForegroundColor Green
Write-Host "失败: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "Gray" })
Write-Host "通过率: $passRate%" -ForegroundColor $(if ($passRate -eq 100) { "Green" } elseif ($passRate -ge 80) { "Yellow" } else { "Red" })
Write-Host ""

# 详细结果表格
Write-Host "详细测试结果:" -ForegroundColor Yellow
Write-Host ("-" * 80) -ForegroundColor Gray
Write-Host ("{0,-40} {1,-10} {2}" -f "测试名称", "结果", "详情") -ForegroundColor White
Write-Host ("-" * 80) -ForegroundColor Gray

foreach ($result in $testResults) {
  $status = if ($result.Success) { "✓ 通过" } else { "✗ 失败" }
  $color = if ($result.Success) { "Green" } else { "Red" }
  Write-Host ("{0,-40} " -f $result.TestName) -NoNewline
  Write-Host ("{0,-10} " -f $status) -NoNewline -ForegroundColor $color
  Write-Host $result.Details -ForegroundColor Gray
}

Write-Host ("-" * 80) -ForegroundColor Gray
Write-Host ""

# 清理提示
if ($testCode1 -or $testCode2 -or $batchCodes.Count -gt 0) {
  Write-Info "测试创建的短链代码:"
  if ($testCode1) { Write-Host "  - $testCode1" -ForegroundColor Gray }
  if ($testCode2) { Write-Host "  - $testCode2" -ForegroundColor Gray }
  foreach ($code in $batchCodes) {
    Write-Host "  - $code" -ForegroundColor Gray
  }
  Write-Host ""
  Write-Info "如需清理测试数据，请手动删除这些短链"
}

# 建议
Write-Host ""
Write-Host "💡 建议:" -ForegroundColor Cyan
Write-Host "  1. 查看 Grafana 仪表板监控图床短链指标" -ForegroundColor Gray
Write-Host "     http://localhost:3000/d/short-link-management" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. 查看详细 API 文档" -ForegroundColor Gray
Write-Host "     docs/IMAGEBED_API.md" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. 监控 Prometheus 指标" -ForegroundColor Gray
Write-Host "     http://localhost:9090" -ForegroundColor Gray
Write-Host ""

# 退出码
if ($failedTests -gt 0) {
  exit 1
}
else {
  exit 0
}
#endregion
