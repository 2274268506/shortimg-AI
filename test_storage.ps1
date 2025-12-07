# WebDAV和SFTP存储测试脚本 (PowerShell)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "TC-GO 存储测试工具" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 创建测试文件
$testFile = "test_image.txt"
"This is a test file for storage verification." | Out-File -FilePath $testFile -Encoding UTF8

Write-Host "请选择要测试的存储类型:"
Write-Host "1. WebDAV (坚果云)"
Write-Host "2. SFTP (SSH服务器)"
$choice = Read-Host "请输入选项 (1/2)"

switch ($choice) {
  "1" {
    Write-Host ""
    Write-Host "=== WebDAV 连接测试 ===" -ForegroundColor Yellow
    $webdavUrl = Read-Host "WebDAV URL (例: https://dav.jianguoyun.com/dav/)"
    $webdavUser = Read-Host "用户名/邮箱"
    $webdavPass = Read-Host "密码 (应用密码)" -AsSecureString

    # 转换安全字符串为明文（仅用于测试）
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($webdavPass)
    $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    Write-Host "正在测试连接..." -ForegroundColor Yellow

    # 创建认证头
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${webdavUser}:${plainPass}"))
    $headers = @{
      Authorization = "Basic $base64AuthInfo"
    }

    try {
      # 测试PROPFIND请求
      $response = Invoke-WebRequest -Uri $webdavUrl -Method PROPFIND -Headers $headers -ErrorAction Stop

      if ($response.StatusCode -eq 207 -or $response.StatusCode -eq 200) {
        Write-Host "✅ WebDAV连接成功 (HTTP $($response.StatusCode))" -ForegroundColor Green

        # 测试文件上传
        Write-Host "正在测试文件上传..." -ForegroundColor Yellow
        $uploadUrl = $webdavUrl.TrimEnd('/') + "/$testFile"
        $fileContent = Get-Content $testFile -Raw

        try {
          $uploadResponse = Invoke-WebRequest -Uri $uploadUrl -Method PUT -Headers $headers -Body $fileContent -ErrorAction Stop

          if ($uploadResponse.StatusCode -eq 201 -or $uploadResponse.StatusCode -eq 204) {
            Write-Host "✅ 文件上传成功 (HTTP $($uploadResponse.StatusCode))" -ForegroundColor Green

            # 清理测试文件
            Write-Host "正在清理测试文件..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $uploadUrl -Method DELETE -Headers $headers -ErrorAction SilentlyContinue | Out-Null
            Write-Host "✅ 测试完成" -ForegroundColor Green
          }
        }
        catch {
          Write-Host "❌ 文件上传失败: $($_.Exception.Message)" -ForegroundColor Red
        }
      }
    }
    catch {
      Write-Host "❌ WebDAV连接失败: $($_.Exception.Message)" -ForegroundColor Red
      Write-Host "提示: 坚果云需要使用应用密码，不是登录密码" -ForegroundColor Yellow
      Write-Host "获取应用密码: 坚果云网页版 → 账户信息 → 安全选项 → 添加应用" -ForegroundColor Yellow
    }
    finally {
      # 清理敏感数据
      [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
  }

  "2" {
    Write-Host ""
    Write-Host "=== SFTP 连接测试 ===" -ForegroundColor Yellow
    Write-Host "注意: PowerShell需要安装Posh-SSH模块" -ForegroundColor Yellow
    Write-Host "安装命令: Install-Module -Name Posh-SSH -Force" -ForegroundColor Cyan

    # 检查是否安装了Posh-SSH
    if (!(Get-Module -ListAvailable -Name Posh-SSH)) {
      Write-Host "❌ 未安装Posh-SSH模块" -ForegroundColor Red
      Write-Host "请运行以下命令安装 (需要管理员权限):" -ForegroundColor Yellow
      Write-Host "Install-Module -Name Posh-SSH -Force" -ForegroundColor Cyan
      exit
    }

    Import-Module Posh-SSH

    $sftpHost = Read-Host "服务器地址"
    $sftpPort = Read-Host "端口 (默认22)"
    if ([string]::IsNullOrWhiteSpace($sftpPort)) { $sftpPort = 22 }
    $sftpUser = Read-Host "用户名"
    $authType = Read-Host "认证方式 (1=密码, 2=密钥)"

    if ($authType -eq "1") {
      # 密码认证
      $sftpPass = Read-Host "密码" -AsSecureString
      $credential = New-Object System.Management.Automation.PSCredential ($sftpUser, $sftpPass)

      Write-Host "正在测试SSH连接 (密码认证)..." -ForegroundColor Yellow

      try {
        $session = New-SFTPSession -ComputerName $sftpHost -Port $sftpPort -Credential $credential -AcceptKey -ErrorAction Stop
        Write-Host "✅ SFTP连接成功" -ForegroundColor Green

        # 测试文件上传
        Write-Host "正在测试文件上传..." -ForegroundColor Yellow
        Set-SFTPItem -SessionId $session.SessionId -Path $testFile -Destination "./$testFile" -ErrorAction Stop
        Write-Host "✅ SFTP文件上传成功" -ForegroundColor Green

        # 清理
        Remove-SFTPItem -SessionId $session.SessionId -Path "./$testFile" -ErrorAction SilentlyContinue
        Remove-SFTPSession -SessionId $session.SessionId | Out-Null
        Write-Host "✅ 测试完成" -ForegroundColor Green
      }
      catch {
        Write-Host "❌ SFTP测试失败: $($_.Exception.Message)" -ForegroundColor Red
      }
    }
    else {
      # 密钥认证
      $keyPath = Read-Host "私钥路径 (例: C:\Users\Admin\.ssh\id_rsa)"

      if (!(Test-Path $keyPath)) {
        Write-Host "❌ 私钥文件不存在: $keyPath" -ForegroundColor Red
        exit
      }

      Write-Host "正在测试SSH连接 (密钥认证)..." -ForegroundColor Yellow

      try {
        $session = New-SFTPSession -ComputerName $sftpHost -Port $sftpPort -Credential $sftpUser -KeyFile $keyPath -AcceptKey -ErrorAction Stop
        Write-Host "✅ SFTP连接成功" -ForegroundColor Green

        # 测试文件上传
        Write-Host "正在测试文件上传..." -ForegroundColor Yellow
        Set-SFTPItem -SessionId $session.SessionId -Path $testFile -Destination "./$testFile" -ErrorAction Stop
        Write-Host "✅ SFTP文件上传成功" -ForegroundColor Green

        # 清理
        Remove-SFTPItem -SessionId $session.SessionId -Path "./$testFile" -ErrorAction SilentlyContinue
        Remove-SFTPSession -SessionId $session.SessionId | Out-Null
        Write-Host "✅ 测试完成" -ForegroundColor Green
      }
      catch {
        Write-Host "❌ SFTP测试失败: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "请检查:" -ForegroundColor Yellow
        Write-Host "  1. 公钥是否已添加到服务器 ~/.ssh/authorized_keys" -ForegroundColor Yellow
        Write-Host "  2. 服务器防火墙是否开放端口 $sftpPort" -ForegroundColor Yellow
      }
    }
  }

  default {
    Write-Host "❌ 无效选项" -ForegroundColor Red
    exit
  }
}

# 清理本地测试文件
Remove-Item $testFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "测试结束" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
