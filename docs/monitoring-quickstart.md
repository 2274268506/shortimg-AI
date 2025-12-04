# TC-GO 监控系统快速启动指南

## 🚀 5 分钟快速开始

### 1. 启动后端服务
```bash
# 确保后端正在运行
cd backend
go run main.go
```

后端应该运行在 http://localhost:8080

### 2. 验证指标端点
```bash
# Windows PowerShell
curl http://localhost:8080/metrics

# 或者在浏览器打开
# http://localhost:8080/metrics
```

你应该能看到类似这样的输出：
```
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/health",status="200"} 42
...
```

### 3. 启动监控栈
```bash
# 在项目根目录执行
make monitoring-up

# 或者直接使用 docker-compose
docker-compose -f docker-compose.monitoring.yml up -d
```

### 4. 访问监控界面

#### Prometheus (数据收集)
- 地址: http://localhost:9090
- 查询示例:
  - `http_requests_total` - 总请求数
  - `rate(http_requests_total[5m])` - 每秒请求数
  - `http_requests_active` - 活跃请求数

#### Grafana (数据可视化)
- 地址: http://localhost:3001
- 默认账号: `admin` / `admin`
- 首次登录会要求修改密码（可跳过）

#### AlertManager (告警管理)
- 地址: http://localhost:9093
- 查看当前告警和告警历史

---

## 📊 配置 Grafana 仪表板

### 第一步：添加 Prometheus 数据源

1. 登录 Grafana (http://localhost:3001)
2. 点击左侧菜单 ⚙️ Configuration → Data Sources
3. 点击 "Add data source"
4. 选择 "Prometheus"
5. 配置如下：
   - **Name**: Prometheus
   - **URL**: http://prometheus:9090
   - **Access**: Server (default)
6. 点击 "Save & Test"，应该显示绿色 ✅ "Data source is working"

### 第二步：导入预设仪表板

#### 方法 A: 使用 Grafana 官方仪表板
1. 点击左侧 ➕ → Import
2. 输入仪表板 ID: `14997` (Go Metrics)
3. 选择 Prometheus 数据源
4. 点击 Import

#### 方法 B: 创建自定义仪表板

创建新仪表板并添加以下面板：

##### 面板 1: QPS (每秒请求数)
```promql
sum(rate(http_requests_total[1m]))
```

##### 面板 2: 平均响应时间
```promql
rate(http_request_duration_seconds_sum[5m]) 
/ 
rate(http_request_duration_seconds_count[5m])
```

##### 面板 3: 错误率
```promql
sum(rate(http_requests_total{status=~"5.."}[5m])) 
/ 
sum(rate(http_requests_total[5m])) * 100
```

##### 面板 4: P95 延迟
```promql
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)
```

##### 面板 5: 活跃请求数
```promql
http_requests_active
```

##### 面板 6: 图片上传成功率
```promql
sum(rate(image_uploads_total{status="success"}[5m])) 
/ 
sum(rate(image_uploads_total[5m])) * 100
```

##### 面板 7: 缓存命中率
```promql
sum(rate(cache_hits_total{hit="hit"}[5m])) 
/ 
sum(rate(cache_hits_total[5m])) * 100
```

##### 面板 8: 请求状态码分布
```promql
sum(rate(http_requests_total[5m])) by (status)
```

---

## 🧪 测试告警

### 1. 触发高错误率告警
```bash
# 生成一些错误请求
for i in {1..20}; do
  curl http://localhost:8080/api/nonexistent
done
```

### 2. 查看告警
访问 http://localhost:9093 查看 AlertManager

### 3. 在 Grafana 中查看
在 Grafana 仪表板中可以看到错误率上升

---

## 📈 常用 PromQL 查询

### 性能监控
```promql
# QPS (每秒请求数)
rate(http_requests_total[1m])

# 按路径分组的 QPS
sum(rate(http_requests_total[1m])) by (path)

# 平均响应时间
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])

# P50 延迟
histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# P95 延迟
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# P99 延迟
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```

### 错误监控
```promql
# 5xx 错误率
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# 4xx 错误率
sum(rate(http_requests_total{status=~"4.."}[5m])) / sum(rate(http_requests_total[5m]))

# 按状态码分组
sum(rate(http_requests_total[5m])) by (status)
```

### 业务监控
```promql
# 图片上传速率
rate(image_uploads_total[5m])

# 上传成功率
sum(rate(image_uploads_total{status="success"}[5m])) / sum(rate(image_uploads_total[5m]))

# 缓存命中率
sum(rate(cache_hits_total{hit="hit"}[5m])) / sum(rate(cache_hits_total[5m]))
```

---

## 🛠️ 故障排查

### 问题 1: Prometheus 无法抓取指标
**症状**: Prometheus Targets 页面显示 "Down"

**解决方案**:
```bash
# 检查后端是否运行
curl http://localhost:8080/health

# 检查指标端点
curl http://localhost:8080/metrics

# 查看 Prometheus 日志
docker logs tc-go-prometheus
```

### 问题 2: Grafana 无法连接 Prometheus
**症状**: Grafana 显示 "Connection refused"

**解决方案**:
1. 确保数据源 URL 是 `http://prometheus:9090` (Docker 网络内部地址)
2. 不要使用 `http://localhost:9090`
3. 检查 Prometheus 容器是否运行: `docker ps`

### 问题 3: 没有数据显示
**症状**: Grafana 面板显示 "No data"

**解决方案**:
1. 检查时间范围（右上角）
2. 确保后端有请求流量
3. 生成一些测试流量:
   ```bash
   # 生成测试请求
   for i in {1..100}; do
     curl http://localhost:8080/health
     sleep 0.1
   done
   ```

### 问题 4: 告警未触发
**症状**: AlertManager 没有告警

**解决方案**:
1. 检查 Prometheus Rules: http://localhost:9090/rules
2. 查看 Alerts: http://localhost:9090/alerts
3. 验证告警条件是否满足
4. 检查 `alerts.yml` 配置

---

## 🔧 高级配置

### 自定义抓取间隔
编辑 `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'tc-go-backend'
    scrape_interval: 5s  # 改为 5 秒
```

### 添加告警通知渠道

#### 邮件通知
编辑 `alertmanager.yml`:
```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-email@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'

receivers:
  - name: 'critical'
    email_configs:
      - to: 'admin@example.com'
```

#### Slack 通知
```yaml
receivers:
  - name: 'critical'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
```

---

## 📚 下一步

1. **创建自定义仪表板**: 根据业务需求设计
2. **配置告警通知**: 接入邮件、Slack 等
3. **优化告警规则**: 减少误报，提高准确性
4. **长期数据保留**: 配置 Prometheus 远程存储
5. **性能调优**: 根据监控数据优化系统

---

## 🎯 监控目标

建议的监控指标目标：

| 指标 | 目标值 | 告警阈值 |
|-----|-------|---------|
| 可用性 | > 99.9% | < 99.5% |
| P95 延迟 | < 500ms | > 1s |
| P99 延迟 | < 1s | > 2s |
| 错误率 | < 0.1% | > 1% |
| 上传成功率 | > 99% | < 95% |
| 缓存命中率 | > 80% | < 70% |

---

## 📞 获取帮助

- 📖 [完整监控文档](monitoring.md)
- 🔗 [Prometheus 官方文档](https://prometheus.io/docs/)
- 🔗 [Grafana 官方文档](https://grafana.com/docs/)
- 🔗 [PromQL 教程](https://prometheus.io/docs/prometheus/latest/querying/basics/)

---

**祝你监控愉快！** 📊✨
