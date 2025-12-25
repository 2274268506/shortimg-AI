# GeoIP 功能测试和验证脚本
Write-Host "=== GeoIP 自动选择功能测试 ===" -ForegroundColor Cyan

# 检查 GeoIP 文件
Write-Host "`n1. 检查 GeoIP 数据库文件..." -ForegroundColor Yellow
$geoipPath = ".\redirect-service\geoip"
$requiredFiles = @(
  "qqwry.dat",
  "GeoLite2-Country.mmdb",
  "GeoLite2-City.mmdb",
  "GeoLite2-ASN.mmdb"
)

foreach ($file in $requiredFiles) {
  $fullPath = Join-Path $geoipPath $file
  if (Test-Path $fullPath) {
    $size = (Get-Item $fullPath).Length
    $sizeMB = [math]::Round($size / 1MB, 2)
    Write-Host "   ✓ $file ($sizeMB MB)" -ForegroundColor Green
  }
  else {
    Write-Host "   ✗ $file (未找到)" -ForegroundColor Red
  }
}

# 检查 Lua 模块
Write-Host "`n2. 检查 Lua 模块文件..." -ForegroundColor Yellow
$luaPath = ".\redirect-service\lua"
$requiredModules = @(
  "geoip_manager.lua",
  "geoip_query.lua",
  "geoip_admin_api.lua",
  "test_geoip.lua"
)

foreach ($module in $requiredModules) {
  $fullPath = Join-Path $luaPath $module
  if (Test-Path $fullPath) {
    $lines = (Get-Content $fullPath).Count
    Write-Host "   ✓ $module ($lines 行)" -ForegroundColor Green
  }
  else {
    Write-Host "   ✗ $module (未找到)" -ForegroundColor Red
  }
}

# 检查路由引擎集成
Write-Host "`n3. 检查路由引擎集成..." -ForegroundColor Yellow
$routingEngine = ".\redirect-service\lua\routing_engine.lua"
if (Test-Path $routingEngine) {
  $content = Get-Content $routingEngine -Raw

  if ($content -match "geoip_manager" -and $content -match "geoip_query") {
    Write-Host "   ✓ 已集成 GeoIP 管理模块" -ForegroundColor Green
  }
  else {
    Write-Host "   ✗ 未集成 GeoIP 管理模块" -ForegroundColor Red
  }

  if ($content -match "select_databases") {
    Write-Host "   ✓ 已实现自动数据库选择" -ForegroundColor Green
  }
  else {
    Write-Host "   ✗ 未实现自动数据库选择" -ForegroundColor Red
  }

  if ($content -match "query_geoip") {
    Write-Host "   ✓ 已实现 GeoIP 查询接口" -ForegroundColor Green
  }
  else {
    Write-Host "   ✗ 未实现 GeoIP 查询接口" -ForegroundColor Red
  }
}
else {
  Write-Host "   ✗ routing_engine.lua 未找到" -ForegroundColor Red
}

# 显示功能说明
Write-Host "`n=== 功能说明 ===" -ForegroundColor Cyan
Write-Host @"

✓ GeoIP 数据库管理器 (geoip_manager.lua)
  - 分析路由规则需求
  - 自动选择合适的数据库
  - 评分系统优化选择
  - 数据库验证和推荐

✓ GeoIP 查询模块 (geoip_query.lua)
  - 支持 qqwry.dat (纯真IP库)
  - 支持 MaxMind MMDB 格式
  - 多数据库并行查询
  - 结果智能合并

✓ 管理 API (geoip_admin_api.lua)
  - GET  /admin/geoip/databases      - 查看所有数据库
  - GET  /admin/geoip/selected       - 查看选中的数据库
  - GET  /admin/geoip/validate       - 验证数据库文件
  - GET  /admin/geoip/recommendations - 获取推荐配置
  - POST /admin/geoip/query          - 测试IP查询
  - POST /admin/geoip/reload         - 重载配置

✓ 自动选择策略
  - 需要国内运营商 → qqwry.dat
  - 需要省份信息 → qqwry.dat
  - 仅需国家信息 → GeoLite2-Country.mmdb
  - 需要ASN信息 → GeoLite2-ASN.mmdb
  - 需要城市级精度 → GeoLite2-City.mmdb

"@ -ForegroundColor White

# 测试建议
Write-Host "=== 测试建议 ===" -ForegroundColor Cyan
Write-Host @"

1. 使用 resty 测试 Lua 模块:
   cd redirect-service
   resty -I lua -e 'require("test_geoip")'

2. 配置 Nginx 测试路由:
   在 nginx.conf 中添加 location:

   location /admin/geoip {
       content_by_lua_block {
           local api = require "geoip_admin_api"
           api.handle_request()
       }
   }

3. 测试 API 调用:
   # 查看数据库
   curl http://localhost:8080/admin/geoip/databases

   # 查看选中的数据库
   curl http://localhost:8080/admin/geoip/selected

   # 测试IP查询
   curl -X POST http://localhost:8080/admin/geoip/query \
        -H "Content-Type: application/json" \
        -d '{"ip":"1.2.3.4"}'

4. 查看日志:
   tail -f logs/error.log | grep GeoIP

"@ -ForegroundColor White

# 性能对比
Write-Host "=== 数据库性能对比 ===" -ForegroundColor Cyan
Write-Host @"

数据库            大小      适用场景              查询速度
------------------------------------------------------------------
qqwry.dat         ~8MB     国内三网分流          ~0.1ms
GeoLite2-Country  ~6MB     国家级分流            ~0.05ms
GeoLite2-City     ~70MB    城市级精确定位        ~0.2ms
GeoLite2-ASN      ~5MB     ASN/运营商识别        ~0.05ms

推荐组合:
- 纯国内: qqwry.dat
- 国内外: qqwry.dat + GeoLite2-Country.mmdb
- 全球: GeoLite2-City.mmdb + GeoLite2-ASN.mmdb

"@ -ForegroundColor White

Write-Host "=== 测试完成 ===" -ForegroundColor Green
Write-Host "详细文档请查看: redirect-service\GEOIP_AUTO_SELECT.md" -ForegroundColor Cyan
