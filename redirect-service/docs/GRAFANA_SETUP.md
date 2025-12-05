# Grafana 仪表板使用指南

## ✅ 问题已解决

仪表板配置已修复，现在可以正常访问！

## 🎯 快速访问

### 仪表板地址
- **URL**: http://localhost:3000/d/short-link-overview
- **用户名**: `admin`
- **密码**: `admin`

### 首次登录
1. 访问 http://localhost:3000
2. 输入用户名 `admin` 和密码 `admin`
3. 系统会提示修改密码（可以点击 "Skip" 跳过）
4. 登录后，点击左侧菜单 → Dashboards → 短链服务监控总览

## 📊 仪表板面板说明

### 1. 请求总览
- **指标**: `sum(rate(http_requests_total[5m])) by (endpoint)`
- **说明**: 显示每个 API 端点的请求速率（QPS）
- **单位**: 请求/秒

### 2. 错误率
- **指标**: `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100`
- **说明**: 5xx 错误占总请求的百分比
- **告警阈值**: >5% 为严重

### 3. 响应时间
- **指标**:
  - P50: `histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))`
  - P95: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
  - P99: `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))`
- **说明**: 请求延迟的百分位数分布
- **告警阈值**: P99 >1秒为警告

### 4. 缓存命中率
- **指标**: `cache_hit_rate` (按 cache_type 分组)
- **说明**: L1 和 L2 缓存的命中率
- **告警阈值**: <70% 为警告

### 5. 活跃连接数
- **指标**: `active_connections`
- **说明**: 当前活跃的客户端连接数
- **告警阈值**: >5000 为警告

### 6. 短链总数
- **指标**: `short_links_total`
- **说明**: 系统中的短链总数量（业务指标）

### 7. 速率限制
- **指标**: `rate(rate_limit_exceeded_total[5m])`
- **说明**: 触发速率限制的频率
- **告警阈值**: >100次/分钟为警告

## 🔧 验证仪表板

运行验证脚本：
```powershell
.\scripts\check-grafana.ps1
```

预期输出：
```
✓ Grafana 状态: ok
✓ 数据源: Prometheus - prometheus (默认)
✓ 找到 1 个仪表板: 短链服务监控总览
✓ Prometheus 数据源连接成功
```

## 🎨 自定义仪表板

### 添加新面板

1. 打开仪表板
2. 点击右上角 "Add panel"
3. 选择 "Add a new panel"
4. 在查询编辑器中输入 PromQL 查询
5. 调整可视化类型和设置
6. 点击 "Save" 保存

### PromQL 查询示例

#### 查看 QPS
```promql
rate(short_link_http_requests_total[5m])
```

#### 查看错误率
```promql
sum(rate(short_link_http_requests_total{status=~"5.."}[5m]))
/
sum(rate(short_link_http_requests_total[5m])) * 100
```

#### 查看 P95 延迟
```promql
histogram_quantile(0.95,
  rate(short_link_http_request_duration_seconds_bucket[5m])
)
```

#### 查看 Redis 操作延迟
```promql
histogram_quantile(0.95,
  rate(short_link_redis_operation_duration_seconds_bucket[5m])
)
```

#### 查看缓存命中率
```promql
short_link_cache_hit_rate{cache_type="l1"}
```

## 🚨 告警配置

### 在 Grafana 中设置告警

1. 编辑面板
2. 切换到 "Alert" 选项卡
3. 点击 "Create alert rule from this panel"
4. 设置告警条件和阈值
5. 配置通知渠道

### 告警通知渠道

在 Grafana 中配置通知：
1. 左侧菜单 → Alerting → Contact points
2. 点击 "New contact point"
3. 选择通知类型：
   - Email
   - Slack
   - Webhook
   - 等

## 📈 仪表板变量

### 添加时间范围选择器

仪表板已配置自动刷新（10秒），可在右上角调整：
- 时间范围：Last 15 minutes / Last 1 hour / Last 6 hours 等
- 刷新间隔：10s / 30s / 1m 等

### 添加环境变量

可以添加变量来切换不同环境：
1. 仪表板设置 → Variables
2. 点击 "New variable"
3. 配置变量（如 environment: production, staging）
4. 在查询中使用 `$environment`

## 🔍 故障排查

### 仪表板显示 "No data"

1. **检查 Prometheus 是否有数据**
   ```powershell
   curl http://localhost:9090/api/v1/query?query=short_link_http_requests_total
   ```

2. **检查数据源连接**
   - Grafana → Configuration → Data Sources
   - 点击 Prometheus → "Test" 按钮

3. **检查指标名称**
   - 确保查询中的指标名称与实际暴露的指标匹配
   - 访问 http://localhost/metrics 查看可用指标

### 面板显示错误

1. **检查 PromQL 语法**
   - 在 Prometheus UI (http://localhost:9090) 中测试查询

2. **检查时间范围**
   - 确保选择的时间范围内有数据

3. **查看浏览器控制台**
   - 按 F12 打开开发者工具
   - 查看 Console 和 Network 标签页

## 📝 配置文件位置

```
monitoring/grafana/
├── dashboards/
│   ├── dashboard.yml              # 仪表板提供者配置
│   └── short-link-overview.json   # 仪表板定义
└── datasources/
    └── prometheus.yml             # Prometheus 数据源配置
```

## 🔄 重新加载仪表板

如果修改了仪表板 JSON 文件：

```powershell
# 重启 Grafana 容器
docker-compose restart grafana

# 等待几秒后验证
Start-Sleep -Seconds 5
.\scripts\check-grafana.ps1
```

## 📚 相关资源

- [Grafana 文档](https://grafana.com/docs/grafana/latest/)
- [PromQL 查询语言](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana 仪表板最佳实践](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)

---

**更新日期**: 2025-12-05
**状态**: ✅ 已修复并验证
