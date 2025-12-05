# 短链服务完整功能测试脚本 (PowerShell)

param(
  [string]$BaseUrl = "http://localhost",
  [string]$ApiKey = ""
)

$ErrorActionPreference = "Continue"

# 测试统计
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0

# 颜色输出函数
function Write-Header {
  param([string]$Message)
  Write-Host "`n========================================" -ForegroundColor Blue
  Write-Host $Message -ForegroundColor Blue
  Write-Host "========================================`n" -ForegroundColor Blue
}

function Write-Test {
  param([string]$Message)
  Write-Host "[测试] $Message" -ForegroundColor Yellow
}

function Write-Success {
  param([string]$Message)
  Write-Host "✅ $Message" -ForegroundColor Green
  $script:PassedTests++
}

function Write-Failure {
  param([string]$Message)
  Write-Host "❌ $Message" -ForegroundColor Red
  $script:FailedTests++
}

# HTTP 请求函数
function Invoke-HttpGet {
  param(
    [string]$Url,
    [hashtable]$Headers = @{}
  )

  if ($ApiKey) {
    $Headers["X-API-Key"] = $ApiKey
  }

  try {
    $response = Invoke-WebRequest -Uri $Url -Headers $Headers -UseBasicParsing
    return @{
      StatusCode = $response.StatusCode
      Content    = $response.Content
    }
  }
  catch {
    return @{
      StatusCode = $_.Exception.Response.StatusCode.value__
      Content    = $_.Exception.Message
    }
  }
}

function Invoke-HttpPost {
  param(
    [string]$Url,
    [string]$Body,
    [hashtable]$Headers = @{}
  )

  $Headers["Content-Type"] = "application/json"
  if ($ApiKey) {
    $Headers["X-API-Key"] = $ApiKey
  }

  try {
    $response = Invoke-WebRequest -Uri $Url -Method Post -Body $Body -Headers $Headers -UseBasicParsing
    return @{
      StatusCode = $response.StatusCode
      Content    = $response.Content
    }
  }
  catch {
    return @{
      StatusCode = $_.Exception.Response.StatusCode.value__
      Content    = $_.Exception.Message
    }
  }
}

function Invoke-HttpDelete {
  param([string]$Url)

  $Headers = @{}
  if ($ApiKey) {
    $Headers["X-API-Key"] = $ApiKey
  }

  try {
    $response = Invoke-WebRequest -Uri $Url -Method Delete -Headers $Headers -UseBasicParsing
    return @{
      StatusCode = $response.StatusCode
      Content    = $response.Content
    }
  }
  catch {
    return @{
      StatusCode = $_.Exception.Response.StatusCode.value__
      Content    = $_.Exception.Message
    }
  }
}

# 测试函数
function Test-Response {
  param(
    [hashtable]$Response,
    [int]$ExpectedCode,
    [string]$TestName
  )

  $script:TotalTests++

  if ($Response.StatusCode -eq $ExpectedCode) {
    Write-Success "$TestName (状态码: $($Response.StatusCode))"
    return $true
  }
  else {
    Write-Failure "$TestName (期望: $ExpectedCode, 实际: $($Response.StatusCode))"
    Write-Host "响应内容: $($Response.Content)" -ForegroundColor Gray
    return $false
  }
}

# ============================================
# 阶段 1: 健康检查测试
# ============================================
function Test-HealthChecks {
  Write-Header "阶段 1: 健康检查测试"

  # 测试 1.1: 完整健康检查
  Write-Test "1.1 完整健康检查 (/health)"
  $response = Invoke-HttpGet -Url "$BaseUrl/health"
  Test-Response -Response $response -ExpectedCode 200 -TestName "完整健康检查"

  # 测试 1.2: 活跃性检查
  Write-Test "1.2 活跃性检查 (/health/live)"
  $response = Invoke-HttpGet -Url "$BaseUrl/health/live"
  Test-Response -Response $response -ExpectedCode 200 -TestName "活跃性检查"

  # 测试 1.3: 就绪性检查
  Write-Test "1.3 就绪性检查 (/health/ready)"
  $response = Invoke-HttpGet -Url "$BaseUrl/health/ready"
  Test-Response -Response $response -ExpectedCode 200 -TestName "就绪性检查"
}

# ============================================
# 阶段 2: API 认证测试
# ============================================
function Test-ApiAuthentication {
  Write-Header "阶段 2: API 认证测试"

  # 测试 2.1: 无认证访问
  Write-Test "2.1 无认证访问管理 API（应该返回 401）"
  $oldApiKey = $script:ApiKey
  $script:ApiKey = ""
  $response = Invoke-HttpGet -Url "$BaseUrl/api/v1/stats/overview"
  $script:ApiKey = $oldApiKey
  Test-Response -Response $response -ExpectedCode 401 -TestName "无认证访问被拒绝"

  # 测试 2.2: 有效认证访问
  if ($ApiKey) {
    Write-Test "2.2 有效 API Key 访问"
    $response = Invoke-HttpGet -Url "$BaseUrl/api/v1/stats/overview"
    Test-Response -Response $response -ExpectedCode 200 -TestName "有效认证访问"
  }
  else {
    Write-Failure "未提供 API_KEY，跳过认证测试"
    $script:TotalTests++
  }
}

# ============================================
# 阶段 3: 短链管理测试
# ============================================
function Test-LinkManagement {
  Write-Header "阶段 3: 短链管理测试"

  if (-not $ApiKey) {
    Write-Failure "需要 API_KEY 进行测试，跳过短链管理测试"
    return
  }

  $testCode = "test_$(Get-Date -Format 'yyyyMMddHHmmss')"

  # 测试 3.1: 创建短链
  Write-Test "3.1 创建短链 ($testCode)"
  $createData = @{
    short_code      = $testCode
    targets         = @(
      @{
        cdn    = "north_telecom"
        path   = "/test/image.jpg"
        weight = 5
      }
    )
    strategy        = "round_robin"
    security_config = @{}
  } | ConvertTo-Json -Depth 10

  $response = Invoke-HttpPost -Url "$BaseUrl/api/v1/links" -Body $createData
  Test-Response -Response $response -ExpectedCode 200 -TestName "创建短链"

  # 测试 3.2: 查询短链
  Write-Test "3.2 查询短链 ($testCode)"
  $response = Invoke-HttpGet -Url "$BaseUrl/api/v1/links/$testCode"
  Test-Response -Response $response -ExpectedCode 200 -TestName "查询短链"

  # 测试 3.3: 访问短链（重定向）
  Write-Test "3.3 访问短链重定向 (/r/$testCode)"
  try {
    $null = Invoke-WebRequest -Uri "$BaseUrl/r/$testCode" -MaximumRedirection 0 -ErrorAction SilentlyContinue
    $statusCode = 302
  }
  catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
  }

  $script:TotalTests++
  if ($statusCode -eq 302 -or $statusCode -eq 301) {
    Write-Success "短链重定向 (状态码: $statusCode)"
    $script:PassedTests++
  }
  else {
    Write-Failure "短链重定向失败 (状态码: $statusCode)"
    $script:FailedTests++
  }

  # 测试 3.4: 删除短链
  Write-Test "3.4 删除短链"
  $response = Invoke-HttpDelete -Url "$BaseUrl/api/v1/links/$testCode"
  Test-Response -Response $response -ExpectedCode 200 -TestName "删除短链"
}

# ============================================
# 阶段 4: 批量操作测试
# ============================================
function Test-BatchOperations {
  Write-Header "阶段 4: 批量操作测试"

  if (-not $ApiKey) {
    Write-Failure "需要 API_KEY 进行测试，跳过批量操作测试"
    return
  }

  $timestamp = Get-Date -Format 'yyyyMMddHHmmss'

  # 测试 4.1: 批量创建
  Write-Test "4.1 批量创建短链（3条）"
  $batchCreateData = @{
    links = @(
      @{
        short_code = "batch1_$timestamp"
        targets    = @(@{ cdn = "north_telecom"; path = "/img1.jpg" })
        strategy   = "round_robin"
      },
      @{
        short_code = "batch2_$timestamp"
        targets    = @(@{ cdn = "south_unicom"; path = "/img2.jpg" })
        strategy   = "geo"
      },
      @{
        short_code = "batch3_$timestamp"
        targets    = @(@{ cdn = "overseas"; path = "/img3.jpg" })
        strategy   = "random"
      }
    )
  } | ConvertTo-Json -Depth 10

  $response = Invoke-HttpPost -Url "$BaseUrl/api/v1/batch/create" -Body $batchCreateData
  Test-Response -Response $response -ExpectedCode 200 -TestName "批量创建短链"

  # 测试 4.2: 批量查询
  Write-Test "4.2 批量查询短链"
  $batchQueryData = @{
    short_codes = @("batch1_$timestamp", "batch2_$timestamp", "batch3_$timestamp")
  } | ConvertTo-Json

  $response = Invoke-HttpPost -Url "$BaseUrl/api/v1/batch/query" -Body $batchQueryData
  Test-Response -Response $response -ExpectedCode 200 -TestName "批量查询短链"

  # 测试 4.3: 批量删除
  Write-Test "4.3 批量删除短链"
  $batchDeleteData = @{
    short_codes = @("batch1_$timestamp", "batch2_$timestamp", "batch3_$timestamp")
  } | ConvertTo-Json

  $response = Invoke-HttpPost -Url "$BaseUrl/api/v1/batch/delete" -Body $batchDeleteData
  Test-Response -Response $response -ExpectedCode 200 -TestName "批量删除短链"
}

# ============================================
# 阶段 5: 统计分析测试
# ============================================
function Test-Statistics {
  Write-Header "阶段 5: 统计分析测试"

  if (-not $ApiKey) {
    Write-Failure "需要 API_KEY 进行测试，跳过统计测试"
    return
  }

  # 测试 5.1: 总览统计
  Write-Test "5.1 获取总览统计"
  $response = Invoke-HttpGet -Url "$BaseUrl/api/v1/stats/overview"
  Test-Response -Response $response -ExpectedCode 200 -TestName "总览统计"
}

# ============================================
# 阶段 6: 定时任务测试
# ============================================
function Test-ScheduledTasks {
  Write-Header "阶段 6: 定时任务测试"

  if (-not $ApiKey) {
    Write-Failure "需要 API_KEY 进行测试，跳过定时任务测试"
    return
  }

  # 测试 6.1: 获取任务状态
  Write-Test "6.1 获取定时任务状态"
  $response = Invoke-HttpGet -Url "$BaseUrl/api/v1/tasks/status"
  Test-Response -Response $response -ExpectedCode 200 -TestName "获取任务状态"
}

# ============================================
# 主测试流程
# ============================================
function Main {
  Write-Header "短链服务完整功能测试"

  Write-Host "测试配置:"
  Write-Host "  BASE_URL: $BaseUrl"
  Write-Host "  API_KEY: $($ApiKey.Substring(0, [Math]::Min(10, $ApiKey.Length)))..."
  Write-Host ""

  # 检查服务是否运行
  try {
    $null = Invoke-WebRequest -Uri "$BaseUrl/health" -UseBasicParsing -TimeoutSec 5
  }
  catch {
    Write-Host "错误: 无法连接到服务 ($BaseUrl)" -ForegroundColor Red
    Write-Host "请确保服务正在运行" -ForegroundColor Red
    exit 1
  }

  # 执行所有测试
  Test-HealthChecks
  Test-ApiAuthentication
  Test-LinkManagement
  Test-BatchOperations
  Test-Statistics
  Test-ScheduledTasks

  # 输出测试结果
  Write-Header "测试结果汇总"

  Write-Host "总测试数: " -NoNewline
  Write-Host $TotalTests -ForegroundColor Blue

  Write-Host "通过数: " -NoNewline
  Write-Host $PassedTests -ForegroundColor Green

  Write-Host "失败数: " -NoNewline
  Write-Host $FailedTests -ForegroundColor Red

  if ($FailedTests -eq 0) {
    Write-Host "`n🎉 所有测试通过！`n" -ForegroundColor Green
    exit 0
  }
  else {
    Write-Host "`n⚠️  有 $FailedTests 个测试失败`n" -ForegroundColor Red
    exit 1
  }
}

# 运行主函数
Main
