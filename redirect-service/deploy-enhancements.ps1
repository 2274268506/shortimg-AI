# 短链管理系统功能完善 - 快速部署脚本
# 文件: deploy-enhancements.ps1
# 用途: 一键部署所有增强功能

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  短链管理系统 - 功能完善部署向导" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查必要文件
Write-Host "📋 检查文件..." -ForegroundColor Yellow

$requiredFiles = @(
    "lua/api/admin_features.lua",
    "html/dashboard/enhanced-features.js",
    "html/dashboard/enhanced-ui.html"
)

$allFilesExist = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $file (缺失)" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host ""
    Write-Host "❌ 缺少必要文件，请先确保所有文件已创建" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  步骤 1: 数据库更新" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 数据库更新SQL
$sqlUpdates = @"
-- 添加 deleted_at 字段支持软删除
ALTER TABLE short_links 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP NULL 
AFTER updated_at;

-- 创建访问日志表（可选）
CREATE TABLE IF NOT EXISTS access_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    short_code VARCHAR(50) NOT NULL,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    referer VARCHAR(500),
    country VARCHAR(50),
    region VARCHAR(50),
    city VARCHAR(50),
    device_type VARCHAR(20),
    browser VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_short_code (short_code),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
"@

$sqlUpdates | Out-File -FilePath "sql/enhancements.sql" -Encoding UTF8
Write-Host "✅ SQL 更新脚本已生成: sql/enhancements.sql" -ForegroundColor Green

Write-Host ""
Write-Host "请执行以下命令更新数据库:" -ForegroundColor Yellow
Write-Host "  docker exec -i shortimg-mysql mysql -u root -p[密码] short_links < sql/enhancements.sql" -ForegroundColor White
Write-Host ""

$response = Read-Host "是否已完成数据库更新? (y/n)"
if ($response -ne 'y') {
    Write-Host "请先完成数据库更新后再继续" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  步骤 2: 更新 Nginx 配置" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 生成 Nginx location 配置
$nginxConfig = @"

# ========================================
# 增强功能 API 路由
# ========================================

# 回收站相关
location ~ ^/api/v2/imagebed/trash {
    content_by_lua_block {
        local admin_features = require "api.admin_features"
        admin_features.handle()
    }
}

location ~ ^/api/v2/imagebed/restore/ {
    content_by_lua_block {
        local admin_features = require "api.admin_features"
        admin_features.handle()
    }
}

location ~ ^/api/v2/imagebed/permanent/ {
    content_by_lua_block {
        local admin_features = require "api.admin_features"
        admin_features.handle()
    }
}

# 高级搜索
location = /api/v2/imagebed/search {
    content_by_lua_block {
        local admin_features = require "api.admin_features"
        admin_features.handle()
    }
}

# 导入导出和模板
location ~ ^/api/v2/imagebed/(export|import|template) {
    content_by_lua_block {
        local admin_features = require "api.admin_features"
        admin_features.handle()
    }
}
"@

$nginxConfig | Out-File -FilePath "conf/enhanced-routes.conf" -Encoding UTF8
Write-Host "✅ Nginx 路由配置已生成: conf/enhanced-routes.conf" -ForegroundColor Green

Write-Host ""
Write-Host "请在 conf/nginx.conf 的 server 块中添加:" -ForegroundColor Yellow
Write-Host "  include /usr/local/openresty/nginx/conf/enhanced-routes.conf;" -ForegroundColor White
Write-Host ""

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  步骤 3: 集成前端组件" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 检查 index.html
if (Test-Path "html/dashboard/index.html") {
    $indexContent = Get-Content "html/dashboard/index.html" -Raw
    
    # 检查是否已包含增强功能脚本
    if ($indexContent -notmatch "enhanced-features.js") {
        Write-Host "  需要在 index.html 中添加增强功能脚本引用" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  在 </head> 标签前添加:" -ForegroundColor White
        Write-Host '  <script src="enhanced-features.js"></script>' -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host "  ✅ 增强功能脚本已引用" -ForegroundColor Green
    }
    
    # 检查是否已包含增强UI
    if ($indexContent -notmatch "batch-action-bar") {
        Write-Host "  需要在 index.html 中添加增强UI组件" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  在主内容区域后添加 enhanced-ui.html 的内容" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "  ✅ 增强UI组件已添加" -ForegroundColor Green
    }
} else {
    Write-Host "  ⚠️  未找到 html/dashboard/index.html" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  步骤 4: 重启服务" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host ""
$restart = Read-Host "是否重启短链服务? (y/n)"

if ($restart -eq 'y') {
    Write-Host ""
    Write-Host "正在重启服务..." -ForegroundColor Yellow
    
    # 检查使用哪个 docker-compose 文件
    if (Test-Path "../docker-compose.mysql-test.yml") {
        docker-compose -f ../docker-compose.mysql-test.yml restart short-link-openresty
    } elseif (Test-Path "docker-compose.yml") {
        docker-compose restart short-link-openresty
    } else {
        Write-Host "  ⚠️  未找到 docker-compose 配置文件" -ForegroundColor Yellow
        Write-Host "  请手动重启 OpenResty 容器" -ForegroundColor White
    }
    
    Write-Host "✅ 服务重启完成" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  步骤 5: 功能测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "请访问以下地址测试功能:" -ForegroundColor Yellow
Write-Host "  Dashboard: http://localhost/dashboard/" -ForegroundColor White
Write-Host ""

Write-Host "测试清单:" -ForegroundColor Yellow
Write-Host "  □ 批量选择模式" -ForegroundColor White
Write-Host "  □ 高级搜索功能" -ForegroundColor White
Write-Host "  □ 导入 CSV/JSON" -ForegroundColor White
Write-Host "  □ 导出数据" -ForegroundColor White
Write-Host "  □ 回收站功能" -ForegroundColor White
Write-Host "  □ 批量删除" -ForegroundColor White
Write-Host "  □ 批量更新状态" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  API 端点清单" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$apiEndpoints = @"

新增 API 端点:

回收站相关:
  GET    /api/v2/imagebed/trash           - 查看已删除短链
  POST   /api/v2/imagebed/restore/:code   - 恢复短链
  DELETE /api/v2/imagebed/permanent/:code - 永久删除

搜索功能:
  POST   /api/v2/imagebed/search          - 高级搜索

导入导出:
  GET    /api/v2/imagebed/export          - 导出数据
  POST   /api/v2/imagebed/import          - 导入数据
  GET    /api/v2/imagebed/template        - 下载模板

"@

Write-Host $apiEndpoints -ForegroundColor Gray

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  快速测试命令" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$testCommands = @"

# 1. 查看回收站
curl http://localhost/api/v2/imagebed/trash

# 2. 高级搜索
curl -X POST http://localhost/api/v2/imagebed/search \
  -H "Content-Type: application/json" \
  -d '{"service_type":"imagebed","status":"active"}'

# 3. 导出数据
curl http://localhost/api/v2/imagebed/export?format=csv > export.csv

# 4. 下载模板
curl http://localhost/api/v2/imagebed/template?format=csv > template.csv

"@

Write-Host $testCommands -ForegroundColor Gray

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  🎉 部署完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host ""
Write-Host "📚 相关文档:" -ForegroundColor Cyan
Write-Host "  - 功能集成说明: FEATURES_INTEGRATION.md" -ForegroundColor White
Write-Host "  - 功能完善计划: ENHANCEMENT_PLAN.md" -ForegroundColor White
Write-Host "  - API 文档: docs/ADMIN_API.md" -ForegroundColor White
Write-Host ""

Write-Host "💡 提示:" -ForegroundColor Yellow
Write-Host "  - 首次使用建议先查看 FEATURES_INTEGRATION.md" -ForegroundColor White
Write-Host "  - 遇到问题请查看 logs/ 目录下的日志" -ForegroundColor White
Write-Host "  - API 测试可使用 Postman 或 curl" -ForegroundColor White
Write-Host ""
