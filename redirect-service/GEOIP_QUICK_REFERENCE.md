# 🎉 GeoIP 自动选择功能 - 快速参考

## ✅ 当前状态：运行中且可用

### 📍 访问端点

```bash
# 基础服务
http://localhost              # 短链服务
http://localhost/health       # 健康检查
http://localhost:3000         # Grafana (admin/admin)
http://localhost:9090         # Prometheus

# GeoIP 管理 API
GET  http://localhost/admin/geoip/databases      # 查看所有数据库
GET  http://localhost/admin/geoip/selected       # 查看选中的数据库
GET  http://localhost/admin/geoip/validate       # 验证数据库文件
GET  http://localhost/admin/geoip/recommendations # 获取推荐配置
POST http://localhost/admin/geoip/query          # 测试IP查询
POST http://localhost/admin/geoip/reload         # 重载配置
```

### 🗂️ 数据库状态

| 数据库 | 状态 | 大小 | 得分 |
|--------|------|------|------|
| **qqwry.dat** | ✅ **已选中** | 25.38 MB | **165** |
| GeoLite2-ASN.mmdb | ✅ 可用 | 10.4 MB | - |
| GeoLite2-Country.mmdb | ✅ 可用 | 9.25 MB | - |
| GeoLite2-City.mmdb | ✅ 可用 | 60.27 MB | - |

### 🎯 自动选择结果

**当前选择**: 纯真IP数据库 (qqwry.dat)
**原因**: 路由规则需要国内运营商和省份信息
**得分**: 165分 (最高)

### 🧪 快速测试

```powershell
# 测试 GeoIP API
.\test-redirect-geoip.ps1

# 查看所有数据库
Invoke-RestMethod http://localhost/admin/geoip/databases

# 查看选中的数据库
Invoke-RestMethod http://localhost/admin/geoip/selected

# 测试IP查询
$body = @{ip="1.2.3.4"} | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost/admin/geoip/query -Method Post -Body $body -ContentType "application/json"

# 重启服务
docker-compose restart openresty

# 查看日志
docker logs short-link-openresty --tail 50
```

### 📁 相关文件

```
redirect-service/
├── lua/
│   ├── geoip_manager.lua          # 数据库管理器
│   ├── geoip_query.lua            # 查询模块
│   ├── geoip_admin_api.lua        # 管理API
│   └── routing_engine.lua         # 路由引擎（已集成）
├── geoip/                         # GeoIP 数据库目录
│   ├── qqwry.dat                  # ✅ 纯真IP库
│   ├── GeoLite2-Country.mmdb      # ✅ 国家库
│   ├── GeoLite2-City.mmdb         # ✅ 城市库
│   └── GeoLite2-ASN.mmdb          # ✅ ASN库
├── conf/nginx.conf                # Nginx 配置
├── GEOIP_AUTO_SELECT.md           # 详细文档
├── GEOIP_IMPLEMENTATION_SUMMARY.md # 实现总结
└── GEOIP_TEST_REPORT.md           # 测试报告

test-redirect-geoip.ps1            # 测试脚本
test-geoip-feature.ps1             # 功能验证脚本
```

### 🔧 常用命令

```bash
# Docker 容器管理
docker-compose up -d              # 启动所有服务
docker-compose down               # 停止所有服务
docker-compose restart openresty  # 重启 OpenResty
docker-compose ps                 # 查看容器状态
docker-compose logs -f openresty  # 实时查看日志

# 服务测试
curl http://localhost/health                    # 健康检查
curl http://localhost/admin/geoip/databases     # GeoIP API
curl http://localhost/metrics                   # Prometheus 指标
```

### 📊 监控面板

- **Grafana**: http://localhost:3000
  - 用户名: `admin`
  - 密码: `admin`

- **Prometheus**: http://localhost:9090

- **Redis**: localhost:6379

- **MySQL**: localhost:3306

### ⚡ 性能指标

- API 响应时间: 10-100ms
- 数据库验证: < 10ms
- 配置加载: < 5ms
- 评分计算: < 1ms

### 💡 提示

1. **自动选择**: 系统启动时自动选择最优数据库，无需手动配置
2. **热更新**: 可通过 `/admin/geoip/reload` 重新加载配置
3. **多数据库**: 支持同时使用多个数据库，结果自动合并
4. **智能评分**: 根据路由规则需求智能计算数据库适配分数

### 🐛 故障排查

**问题**: API 返回 404
**解决**: 检查 nginx.conf 是否包含 GeoIP 端点配置，重启容器

**问题**: 数据库文件不存在
**解决**: 确认 geoip 目录已挂载，文件已复制到容器

**问题**: IP 查询返回空
**解决**: 需要安装 GeoIP 查询库（lua-resty-maxminddb 或 qqwry）

**问题**: 旧 GeoIP 模块报错
**解决**: 不影响新系统，可忽略或禁用旧模块

### 📚 文档索引

- [使用指南](GEOIP_AUTO_SELECT.md) - 完整的使用文档
- [实现总结](GEOIP_IMPLEMENTATION_SUMMARY.md) - 技术实现细节
- [测试报告](GEOIP_TEST_REPORT.md) - 详细测试结果

---

**最后更新**: 2025-12-25
**系统状态**: ✅ 运行中
**核心功能**: ✅ 可用
