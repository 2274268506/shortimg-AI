# 📊 监控系统集成指南

## 🎯 方案说明

本方案将短链服务的监控集成到现有的 TC-GO 监控系统中，实现统一管理。

### ✅ 优点

- 统一监控面板，方便管理
- 节省资源（无需为每个服务部署独立的 Prometheus）
- 告警规则集中管理
- 数据关联分析更方便

---

## 📋 已完成的配置

### 1️⃣ **Prometheus 配置**（`prometheus.yml`）

添加了短链服务的抓取配置：

```yaml
scrape_configs:
  # 短链重定向服务
  - job_name: 'shortlink-service'
    static_configs:
      - targets: ['host.docker.internal:8081']
    metrics_path: '/metrics'
    scrape_interval: 10s
    scrape_timeout: 5s
```

### 2️⃣ **告警规则**（`alerts.yml`）

添加了短链服务专用告警规则组：

- ✅ 服务宕机告警
- ✅ 重定向失败率告警
- ✅ 重定向延迟告警
- ✅ 缓存命中率告警
- ✅ 404 错误率告警
- ✅ Redis/MySQL 连接失败告警
- ✅ 请求量激增告警

---

## 🚀 部署步骤

### 步骤 1：确保短链服务已部署

```bash
# 进入短链服务目录
cd redirect-service

# 确认 .env 文件中启用了监控
grep ENABLE_METRICS .env
# 应该显示: ENABLE_METRICS=true

# 启动短链服务（如果还没启动）
docker-compose -f docker-compose.prod.yml up -d
```

### 步骤 2：验证短链服务的 Metrics 端点

```bash
# 测试短链服务的监控端点
curl http://localhost:8081/metrics

# 应该看到 Prometheus 格式的指标输出，例如：
# # HELP shortlink_redirects_total Total number of redirect requests
# # TYPE shortlink_redirects_total counter
# shortlink_redirects_total{status="success"} 0
# shortlink_redirects_total{status="failed"} 0
```

### 步骤 3：重启 Prometheus 服务

```bash
# 返回项目根目录
cd ..

# 重启监控服务以加载新配置
docker-compose -f docker-compose.monitoring.yml restart prometheus

# 查看 Prometheus 日志确认配置加载成功
docker logs tc-go-prometheus
```

### 步骤 4：验证 Prometheus 抓取

访问 Prometheus Web UI：

```
http://localhost:9090
```

1. 点击 **Status** → **Targets**
2. 查找 `shortlink-service` 任务
3. 确认状态为 **UP**（绿色）

### 步骤 5：查询短链服务指标

在 Prometheus 查询框中输入：

```promql
# 查看短链服务是否在线
up{job="shortlink-service"}

# 查看重定向请求速率
rate(shortlink_redirects_total[5m])

# 查看缓存命中率
sum(rate(shortlink_cache_hits{hit="true"}[5m]))
/
sum(rate(shortlink_cache_hits[5m]))
```

---

## 📈 Grafana 仪表板配置

### 创建短链服务仪表板

1. 访问 Grafana：`http://localhost:3001`
2. 登录（默认：admin/admin）
3. 点击左侧菜单 **+** → **Create Dashboard**
4. 添加以下面板：

#### 面板 1：重定向请求速率

```promql
sum(rate(shortlink_redirects_total[5m])) by (status)
```

**可视化类型：** Graph / Time series
**图例：** {{status}}

#### 面板 2：重定向延迟（P95/P99）

```promql
# P95
histogram_quantile(0.95,
  sum(rate(shortlink_redirect_duration_seconds_bucket[5m])) by (le)
)

# P99
histogram_quantile(0.99,
  sum(rate(shortlink_redirect_duration_seconds_bucket[5m])) by (le)
)
```

**可视化类型：** Graph / Time series

#### 面板 3：缓存命中率

```promql
sum(rate(shortlink_cache_hits{hit="true"}[5m]))
/
sum(rate(shortlink_cache_hits[5m])) * 100
```

**可视化类型：** Gauge
**单位：** Percent (0-100)

#### 面板 4：错误率分布

```promql
sum(rate(shortlink_redirects_total[5m])) by (status)
```

**可视化类型：** Pie chart

#### 面板 5：活跃连接数

```promql
shortlink_active_connections
```

**可视化类型：** Stat

#### 面板 6：数据库连接状态

```promql
# Redis 连接状态
shortlink_redis_connected

# MySQL 连接状态
shortlink_mysql_connected
```

**可视化类型：** Stat
**阈值：**
- 红色：< 1（断开）
- 绿色：>= 1（已连接）

---

## 🔔 告警配置

### AlertManager 集成

告警已配置在 `alerts.yml` 中，将通过 AlertManager 发送。

#### 配置告警接收方式

编辑 `alertmanager.yml`：

```yaml
route:
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'
  routes:
    # 短链服务告警路由
    - match:
        alertname: ShortlinkServiceDown
      receiver: 'critical-alerts'
    - match:
        severity: critical
      receiver: 'critical-alerts'

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://your-webhook-url/alerts'

  - name: 'critical-alerts'
    # 企业微信
    wechat_configs:
      - api_url: 'https://qyapi.weixin.qq.com/cgi-bin/'
        corp_id: 'your_corp_id'
        agent_id: 'your_agent_id'
        api_secret: 'your_api_secret'
    # 或者邮件
    email_configs:
      - to: 'admin@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.example.com:587'
        auth_username: 'alertmanager'
        auth_password: 'password'
```

---

## 🔍 监控指标说明

### 短链服务提供的核心指标

| 指标名称 | 类型 | 说明 |
|---------|------|------|
| `shortlink_redirects_total` | Counter | 重定向请求总数（按状态分类） |
| `shortlink_redirect_duration_seconds` | Histogram | 重定向请求延迟分布 |
| `shortlink_cache_hits` | Counter | 缓存命中/未命中次数 |
| `shortlink_active_connections` | Gauge | 当前活跃连接数 |
| `shortlink_redis_connected` | Gauge | Redis 连接状态（1=已连接，0=断开） |
| `shortlink_mysql_connected` | Gauge | MySQL 连接状态 |
| `shortlink_redis_connection_errors_total` | Counter | Redis 连接错误次数 |
| `shortlink_mysql_connection_errors_total` | Counter | MySQL 连接错误次数 |

### 常用查询示例

```promql
# 1. 每秒重定向成功数
sum(rate(shortlink_redirects_total{status="success"}[5m]))

# 2. 重定向失败率
sum(rate(shortlink_redirects_total{status="failed"}[5m]))
/
sum(rate(shortlink_redirects_total[5m]))

# 3. 平均响应时间
rate(shortlink_redirect_duration_seconds_sum[5m])
/
rate(shortlink_redirect_duration_seconds_count[5m])

# 4. P95 响应时间
histogram_quantile(0.95,
  sum(rate(shortlink_redirect_duration_seconds_bucket[5m])) by (le)
)

# 5. 缓存命中率
sum(rate(shortlink_cache_hits{hit="true"}[5m]))
/
sum(rate(shortlink_cache_hits[5m]))

# 6. QPS（每秒查询数）
sum(rate(shortlink_redirects_total[1m]))

# 7. 最近 5 分钟的错误次数
increase(shortlink_redirects_total{status="failed"}[5m])

# 8. Top 10 最常访问的短链
topk(10, sum(rate(shortlink_redirects_total[1h])) by (short_code))
```

---

## 🔧 故障排查

### 问题 1：Prometheus 抓取失败

**现象：** Targets 页面显示短链服务状态为 DOWN

**检查步骤：**

```bash
# 1. 确认短链服务是否运行
docker ps | grep shortlink

# 2. 测试端口是否可访问
curl http://localhost:8081/health
curl http://localhost:8081/metrics

# 3. 检查防火墙
sudo ufw status

# 4. 查看 Prometheus 日志
docker logs tc-go-prometheus
```

**解决方案：**

- 如果短链服务在独立服务器，修改 `prometheus.yml` 中的 IP 地址
- 如果使用 Docker 网络，可能需要使用容器名称而非 `host.docker.internal`

### 问题 2：指标数据为空

**现象：** Prometheus 可以抓取，但查询没有数据

**检查：**

```bash
# 检查短链服务环境变量
docker exec shortlink-openresty-prod env | grep METRICS

# 应该显示:
# ENABLE_METRICS=true
# METRICS_PORT=9145
```

**解决：**

确保 `.env` 文件中 `ENABLE_METRICS=true`，然后重启服务。

### 问题 3：告警规则不生效

**检查：**

```bash
# 1. 检查告警规则语法
docker exec tc-go-prometheus promtool check rules /etc/prometheus/alerts.yml

# 2. 重新加载配置
curl -X POST http://localhost:9090/-/reload

# 3. 查看告警状态
# 访问 http://localhost:9090/alerts
```

---

## 📊 性能优化建议

### 1. 抓取频率优化

对于高流量场景，可以降低抓取频率：

```yaml
scrape_configs:
  - job_name: 'shortlink-service'
    scrape_interval: 30s  # 从 10s 改为 30s
```

### 2. 数据保留策略

调整 Prometheus 数据保留时间：

```yaml
command:
  - '--storage.tsdb.retention.time=30d'  # 保留 30 天
  - '--storage.tsdb.retention.size=50GB' # 或限制大小
```

### 3. 指标筛选

只抓取需要的指标：

```yaml
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'shortlink_(redirects|cache|duration).*'
    action: keep
```

---

## 🎉 验证清单

- [ ] Prometheus 能成功抓取短链服务指标
- [ ] 在 Prometheus UI 中可以查询到 `shortlink_*` 指标
- [ ] Grafana 中创建了短链服务仪表板
- [ ] 告警规则已加载并生效
- [ ] AlertManager 配置了告警接收方式
- [ ] 测试触发一条告警，确认能收到通知

---

## 📚 相关文档

- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Grafana 仪表板教程](https://grafana.com/docs/grafana/latest/dashboards/)
- [PromQL 查询语法](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [AlertManager 配置指南](https://prometheus.io/docs/alerting/latest/configuration/)

---

## 🚀 完成！

现在你的短链服务已经集成到统一监控系统中了！

**访问地址：**
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001
- AlertManager: http://localhost:9093

**下一步：**
1. 根据实际业务调整告警阈值
2. 创建更详细的 Grafana 仪表板
3. 配置 AlertManager 告警通知
4. 定期检查监控数据，优化服务性能
