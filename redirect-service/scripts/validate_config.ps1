# 短链服务配置验证脚本 (PowerShell)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🔍 短链服务配置验证工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"
$SuccessCount = 0
$WarningCount = 0
$ErrorCount = 0

# 加载 .env 文件
if (!(Test-Path ".env")) {
  Write-Host "❌ 错误: .env 文件不存在" -ForegroundColor Red
  Write-Host "   请先复制 .env.example 并配置" -ForegroundColor Yellow
  exit 1
}

# 解析 .env 文件
Get-Content .env | ForEach-Object {
  if ($_ -match '^([^#][^=]+)=(.*)$') {
    $name = $matches[1].Trim()
    $value = $matches[2].Trim()
    Set-Variable -Name $name -Value $value -Scope Script
  }
}

# 检查函数
function Test-ConfigValue {
  param(
    [string]$Name,
    [string]$Value,
    [bool]$Required = $true
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    if ($Required) {
      Write-Host "❌ ${Name}: 未配置（必需）" -ForegroundColor Red
      $script:ErrorCount++
    }
    else {
      Write-Host "⚠️  ${Name}: 未配置（可选）" -ForegroundColor Yellow
      $script:WarningCount++
    }
  }
  else {
    Write-Host "✅ ${Name}: $Value" -ForegroundColor Green
    $script:SuccessCount++
  }
}

# 检查文件
function Test-ConfigFile {
  param(
    [string]$Name,
    [string]$Path,
    [bool]$Required = $true
  )

  if ([string]::IsNullOrWhiteSpace($Path)) {
    if ($Required) {
      Write-Host "❌ ${Name}: 路径未配置" -ForegroundColor Red
      $script:ErrorCount++
    }
    return
  }

  if (Test-Path $Path) {
    Write-Host "✅ ${Name}: $Path (文件存在)" -ForegroundColor Green
    $script:SuccessCount++
  }
  else {
    if ($Required) {
      Write-Host "❌ ${Name}: $Path (文件不存在)" -ForegroundColor Red
      $script:ErrorCount++
    }
    else {
      Write-Host "⚠️  ${Name}: $Path (文件不存在)" -ForegroundColor Yellow
      $script:WarningCount++
    }
  }
}

# 测试网络连接
function Test-NetworkConnection {
  param(
    [string]$Name,
    [string]$HostName,
    [int]$Port
  )

  if ([string]::IsNullOrWhiteSpace($HostName)) {
    return
  }

  Write-Host "   测试连接 ${HostName}:${Port} ... " -NoNewline

  try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $connect = $tcp.BeginConnect($HostName, $Port, $null, $null)
    $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)

    if ($wait) {
      $tcp.EndConnect($connect)
      $tcp.Close()
      Write-Host "成功" -ForegroundColor Green
      $script:SuccessCount++
    }
    else {
      $tcp.Close()
      Write-Host "失败" -ForegroundColor Red
      $script:ErrorCount++
    }
  }
  catch {
    Write-Host "失败" -ForegroundColor Red
    $script:ErrorCount++
  }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📋 第一步：基础配置检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Test-ConfigValue "短链域名" $REDIRECT_DOMAIN $true
Test-ConfigValue "短链协议" $REDIRECT_PROTOCOL $true
Test-ConfigValue "CDN路由模式" $CDN_ROUTING_MODE $true

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌐 第二步：CDN配置检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($CDN_ROUTING_MODE -eq "private" -or $CDN_ROUTING_MODE -eq "auto") {
  Test-ConfigValue "私有CDN域名" $CDN_PRIVATE_DOMAIN $true
  Test-ConfigValue "私有CDN协议" $CDN_PRIVATE_PROTOCOL $true
}

if ($CDN_ROUTING_MODE -eq "public" -or $CDN_ROUTING_MODE -eq "auto") {
  Test-ConfigValue "公网CDN域名" $CDN_PUBLIC_DOMAIN $true
  Test-ConfigValue "公网CDN协议" $CDN_PUBLIC_PROTOCOL $true
}

if ($CDN_ROUTING_MODE -eq "auto") {
  Write-Host ""
  Write-Host "🎯 智能路由模式 - 可选CDN节点:" -ForegroundColor Blue
  Test-ConfigValue "北方电信CDN" $CDN_NORTH_TELECOM_DOMAIN $false
  Test-ConfigValue "南方联通CDN" $CDN_SOUTH_UNICOM_DOMAIN $false
  Test-ConfigValue "海外CDN" $CDN_OVERSEAS_DOMAIN $false
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "💾 第三步：数据库配置检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Redis配置:" -ForegroundColor Blue
Test-ConfigValue "Redis主机" $REDIS_HOST $true
Test-ConfigValue "Redis端口" $REDIS_PORT $true
Test-ConfigValue "Redis密码" $REDIS_PASSWORD $false
Test-ConfigValue "Redis数据库" $REDIS_DATABASE $true
Test-NetworkConnection "Redis" $REDIS_HOST ([int]$REDIS_PORT)

Write-Host ""
Write-Host "MySQL配置:" -ForegroundColor Blue
Test-ConfigValue "MySQL主机" $MYSQL_HOST $true
Test-ConfigValue "MySQL端口" $MYSQL_PORT $true
Test-ConfigValue "MySQL数据库" $MYSQL_DATABASE $true
Test-ConfigValue "MySQL用户" $MYSQL_USER $true
Test-ConfigValue "MySQL密码" $MYSQL_PASSWORD $true
Test-NetworkConnection "MySQL" $MYSQL_HOST ([int]$MYSQL_PORT)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌍 第四步：GeoIP配置检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
if ($CDN_ROUTING_MODE -eq "auto") {
  Write-Host "GeoIP数据库（auto模式必需）:" -ForegroundColor Blue
  Test-ConfigFile "国家数据库" $GEOIP_COUNTRY_DB $true
  Test-ConfigFile "城市数据库" $GEOIP_CITY_DB $false
  Test-ConfigFile "ASN数据库" $GEOIP_ASN_DB $false
}
else {
  Write-Host "⚠️  当前模式($CDN_ROUTING_MODE)不需要GeoIP" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🔐 第五步：安全配置检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Test-ConfigValue "Token密钥" $DEFAULT_TOKEN_SECRET $true

if ($DEFAULT_TOKEN_SECRET -eq "change-me-in-production-use-strong-random-string") {
  Write-Host "⚠️  警告: 使用默认密钥，生产环境请修改！" -ForegroundColor Red
  $WarningCount++
}

Test-ConfigValue "Token过期时间" $TOKEN_EXPIRE $true
Test-ConfigValue "访问限流" $RATE_LIMIT_MAX $true

Write-Host ""
Write-Host "API KEY配置:" -ForegroundColor Blue
Test-ConfigValue "API KEY启用状态" $API_KEY_ENABLED $true

if ($API_KEY_ENABLED -eq "true") {
  Test-ConfigValue "API KEY" $API_KEY $true

  if ([string]::IsNullOrWhiteSpace($API_KEY)) {
    Write-Host "⚠️  错误: API_KEY_ENABLED=true 但未配置API_KEY！" -ForegroundColor Red
    $script:ErrorCount++
  }
  else {
    # 统计API KEY数量
    $Keys = $API_KEY -split ','
    $KeyCount = $Keys.Count
    Write-Host "   " -NoNewline
    Write-Host "✓" -ForegroundColor Green -NoNewline
    Write-Host " 已配置 $KeyCount 个API KEY"

    # 检查每个KEY的长度
    foreach ($key in $Keys) {
      $key = $key.Trim()
      $KeyLength = $key.Length
      if ($KeyLength -lt 16) {
        Write-Host "   ⚠️  警告: API KEY长度($KeyLength)过短，建议至少32字符" -ForegroundColor Yellow
        $script:WarningCount++
      }
    }
  }

  Test-ConfigValue "API限流上限" $API_RATE_LIMIT_MAX $true
  Test-ConfigValue "API限流窗口" $API_RATE_LIMIT_WINDOW $true
}
else {
  Write-Host "   ⚠️  API KEY认证已禁用" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "管理后台:" -ForegroundColor Blue
Test-ConfigValue "后台认证" $ADMIN_AUTH_ENABLED $true
Test-ConfigValue "管理员用户名" $ADMIN_USERNAME $true
Test-ConfigValue "管理员密码" $ADMIN_PASSWORD $true

if ($ADMIN_PASSWORD -eq "admin123") {
  Write-Host "⚠️  警告: 使用默认密码，生产环境请修改！" -ForegroundColor Red
  $WarningCount++
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "⚡ 第六步：性能配置检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Test-ConfigValue "本地缓存TTL" $CACHE_LOCAL_TTL $true
Test-ConfigValue "Redis缓存TTL" $CACHE_REDIS_TTL $true
Test-ConfigValue "日志级别" $LOG_LEVEL $true

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📊 检查结果汇总" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ 通过: $SuccessCount" -ForegroundColor Green
Write-Host "⚠️  警告: $WarningCount" -ForegroundColor Yellow
Write-Host "❌ 错误: $ErrorCount" -ForegroundColor Red

Write-Host ""
if ($ErrorCount -eq 0) {
  Write-Host "🎉 配置验证通过！" -ForegroundColor Green
  Write-Host ""
  Write-Host "建议的下一步操作:"
  Write-Host "  1. 启动服务: docker-compose up -d"
  Write-Host "  2. 查看日志: docker-compose logs -f redirect-service"
  Write-Host "  3. 测试短链: curl http://$REDIRECT_DOMAIN/test"
  exit 0
}
else {
  Write-Host "❌ 配置验证失败，请修复错误后重试" -ForegroundColor Red
  Write-Host ""
  Write-Host "常见问题排查:"
  Write-Host "  1. 检查 .env 文件中的必填项"
  Write-Host "  2. 确保数据库服务正在运行"
  Write-Host "  3. 检查GeoIP数据库文件路径"
  Write-Host "  4. 参考文档: CONFIG_WIZARD.md"
  exit 1
}
