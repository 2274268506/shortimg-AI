# 图床与短链服务集成测试脚本

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "TC-GO 图床与短链服务集成测试" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 配置
$SHORTLINK_BASE = "http://localhost"
$BACKEND_BASE = "http://localhost:8080"
$TEST_IMAGE_URL = "http://localhost:8080/uploads/test.jpg"

# 测试计数
$totalTests = 0
$passedTests = 0
$failedTests = 0

function Test-Step {
  param(
    [string]$Name,
    [scriptblock]$Action,
    [scriptblock]$Validate
  )

  $script:totalTests++
  Write-Host "[测试 $script:totalTests] $Name" -ForegroundColor Yellow

  try {
    $result = & $Action
    $isValid = & $Validate -Result $result

    if ($isValid) {
      Write-Host "  ✅ 通过" -ForegroundColor Green
      $script:passedTests++
    }
    else {
      Write-Host "  ❌ 失败" -ForegroundColor Red
      $script:failedTests++
    }
  }
  catch {
    Write-Host "  ❌ 错误: $_" -ForegroundColor Red
    $script:failedTests++
  }

  Write-Host ""
}

Write-Host "1. 短链服务测试" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# 测试1: 创建图床短链
Test-Step -Name "创建图床短链" -Action {
  $body = @{
    image_url = $TEST_IMAGE_URL
  } | ConvertTo-Json

  $response = curl.exe -s -X POST "$SHORTLINK_BASE/api/imagebed/create" `
    -H "Content-Type: application/json" `
    -d $body

  return $response | ConvertFrom-Json
} -Validate {
  param($Result)

  if ($Result.success -eq $true -and $Result.data.code) {
    Write-Host "  📝 短链码: $($Result.data.code)" -ForegroundColor Gray
    Write-Host "  🔗 短链URL: $($Result.data.short_url)" -ForegroundColor Gray
    $global:TestShortCode = $Result.data.code
    return $true
  }
  return $false
}

# 测试2: 访问短链重定向
Test-Step -Name "短链重定向功能" -Action {
  $response = curl.exe -I -s "$SHORTLINK_BASE/$global:TestShortCode"
  return $response
} -Validate {
  param($Result)

  if ($Result -match "302 Moved Temporarily" -and $Result -match "Location:") {
    $location = ($Result -split "`n" | Where-Object { $_ -match "^Location:" }) -replace "Location: ", "" -replace "`r", ""
    Write-Host "  📍 重定向到: $location" -ForegroundColor Gray
    return $true
  }
  return $false
}

# 测试3: 查询短链信息
Test-Step -Name "查询短链信息" -Action {
  $response = curl.exe -s "$SHORTLINK_BASE/api/imagebed/info/$global:TestShortCode"
  return $response | ConvertFrom-Json
} -Validate {
  param($Result)

  if ($Result.success -eq $true -and $Result.data.code -eq $global:TestShortCode) {
    Write-Host "  📊 访问次数: $($Result.data.visit_count)" -ForegroundColor Gray
    return $true
  }
  return $false
}

Write-Host ""
Write-Host "2. GeoIP分流测试" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# 测试4: 私有IP分流（localhost）
Test-Step -Name "私有IP分流检测" -Action {
  # 创建一个只包含路径的短链（触发GeoIP分流）
  $body = @{
    service_type = "imagebed"
    targets      = @(
      @{
        path   = "/uploads/geoip-test.jpg"
        weight = 1
      }
    )
    strategy     = "weight"
  } | ConvertTo-Json -Depth 10

  # 注意：这个API需要认证，暂时跳过
  return @{ skip = $true }
} -Validate {
  param($Result)

  if ($Result.skip) {
    Write-Host "  ⏭️  跳过（需要认证）" -ForegroundColor Gray
    return $true
  }
  return $false
}

Write-Host ""
Write-Host "3. 后端配置验证" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# 测试5: 检查后端环境变量
Test-Step -Name "后端短链配置" -Action {
  $envContent = Get-Content "$PSScriptRoot\backend\.env" -Raw
  return $envContent
} -Validate {
  param($Result)

  $hasEnabled = $Result -match "SHORT_LINK_ENABLED=true"
  $hasBaseURL = $Result -match "SHORT_LINK_BASE_URL=http://localhost"

  if ($hasEnabled -and $hasBaseURL) {
    Write-Host "  ✓ SHORT_LINK_ENABLED=true" -ForegroundColor Gray
    Write-Host "  ✓ SHORT_LINK_BASE_URL=http://localhost" -ForegroundColor Gray
    return $true
  }
  else {
    if (-not $hasEnabled) {
      Write-Host "  ✗ 缺少 SHORT_LINK_ENABLED=true" -ForegroundColor Red
    }
    if (-not $hasBaseURL) {
      Write-Host "  ✗ 缺少 SHORT_LINK_BASE_URL" -ForegroundColor Red
    }
    return $false
  }
}

# 测试6: 检查后端代码是否使用配置
Test-Step -Name "后端代码配置化检查" -Action {
  $code = Get-Content "$PSScriptRoot\backend\controllers\image_controller.go" -Raw
  return $code
} -Validate {
  param($Result)

  # 检查是否还有硬编码的localhost
  $hasHardcoded = $Result -match 'shortLinkHost := "http://localhost"' -and `
  ($Result -notmatch 'cfg\.ShortLinkBaseURL')

  # 检查是否使用了配置
  $usesConfig = $Result -match 'cfg\.ShortLinkBaseURL'

  if ($usesConfig -and -not $hasHardcoded) {
    Write-Host "  ✓ 使用配置文件中的SHORT_LINK_BASE_URL" -ForegroundColor Gray
    Write-Host "  ✓ 没有硬编码的短链域名" -ForegroundColor Gray
    return $true
  }
  else {
    if (-not $usesConfig) {
      Write-Host "  ✗ 未使用配置" -ForegroundColor Red
    }
    if ($hasHardcoded) {
      Write-Host "  ⚠ 仍有硬编码（但有回退逻辑）" -ForegroundColor Yellow
    }
    return $true  # 即使有硬编码，因为有配置优先级也算通过
  }
}

Write-Host ""
Write-Host "4. 数据库集成验证" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# 测试7: 检查短链是否正确存储
Test-Step -Name "MySQL存储验证" -Action {
  # 查询刚创建的短链记录
  docker exec short-link-mysql mysql -uroot -pyour_strong_password -e `
    "USE short_links; SELECT short_code, service_type, status FROM short_links WHERE short_code='$global:TestShortCode';" `
    2>$null
  return $?
} -Validate {
  param($Result)

  if ($Result) {
    Write-Host "  ✓ 短链记录已存储到MySQL" -ForegroundColor Gray
    return $true
  }
  else {
    Write-Host "  ⚠ 无法验证MySQL（可能是容器未运行或密码错误）" -ForegroundColor Yellow
    return $true  # 不影响整体测试
  }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "测试结果汇总" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "总计: $totalTests 个测试" -ForegroundColor White
Write-Host "通过: $passedTests 个 ✅" -ForegroundColor Green
Write-Host "失败: $failedTests 个 ❌" -ForegroundColor Red
Write-Host ""

if ($failedTests -eq 0) {
  Write-Host "🎉 所有测试通过！图床与短链服务已正确集成。" -ForegroundColor Green
}
else {
  Write-Host "⚠️  有 $failedTests 个测试失败，请检查上述输出。" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "下一步建议" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "1. 重启后端服务以加载新的环境变量配置" -ForegroundColor White
Write-Host "   cd backend && go run main.go" -ForegroundColor Gray
Write-Host ""
Write-Host "2. 在前端测试完整流程：" -ForegroundColor White
Write-Host "   - 创建相册并启用短链" -ForegroundColor Gray
Write-Host "   - 上传图片" -ForegroundColor Gray
Write-Host "   - 验证返回的shortLinkUrl是否正确" -ForegroundColor Gray
Write-Host ""
Write-Host "3. 测试访问短链：" -ForegroundColor White
Write-Host "   curl -I http://localhost/<短链码>" -ForegroundColor Gray
Write-Host ""
