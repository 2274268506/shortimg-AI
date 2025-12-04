# 监控系统文档

## 概述

TC-GO 使用 Prometheus 进行系统监控，提供丰富的性能指标和运行时数据。

## 访问地址

- **Prometheus 指标端点**: http://localhost:8080/metrics
- **Swagger API 文档**: http://localhost:8080/swagger/index.html
- **健康检查端点**: http://localhost:8080/health

## 可用指标

### 1. HTTP 请求指标

#### http_requests_total
- **类型**: Counter
- **描述**: HTTP 请求总数
- **标签**:
  - `method`: HTTP 方法 (GET, POST, PUT, DELETE)
  - `path`: 请求路径
  - `status`: HTTP 状态码

**示例查询**:
```promql
# 查看所有请求总数
sum(http_requests_total)

# 按状态码分组的请求数
sum(http_requests_total) by (status)

# 5分钟内的请求速率
rate(http_requests_total[5m])
```

#### http_request_duration_seconds
- **类型**: Histogram
- **描述**: HTTP 请求延迟（秒）
- **标签**:
  - `method`: HTTP 方法
  - `path`: 请求路径

**示例查询**:
```promql
# 平均响应时间
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])

# P95 延迟
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, path))

# P99 延迟
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, path))
```

#### http_request_size_bytes
- **类型**: Histogram
- **描述**: HTTP 请求大小（字节）
- **标签**:
  - `method`: HTTP 方法
  - `path`: 请求路径

#### http_response_size_bytes
- **类型**: Histogram
- **描述**: HTTP 响应大小（字节）
- **标签**:
  - `method`: HTTP 方法
  - `path`: 请求路径

#### http_requests_active
- **类型**: Gauge
- **描述**: 当前活跃的 HTTP 请求数

**示例查询**:
```promql
# 当前活跃请求数
http_requests_active

# 活跃请求数趋势
avg_over_time(http_requests_active[5m])
```

### 2. 业务指标

#### image_uploads_total
- **类型**: Counter
- **描述**: 图片上传总数
- **标签**:
  - `format`: 图片格式 (jpg, png, gif, webp)
  - `status`: 上传状态 (success, failed)

**示例查询**:
```promql
# 上传成功率
sum(rate(image_uploads_total{status="success"}[5m])) / sum(rate(image_uploads_total[5m])) * 100

# 按格式统计上传量
sum(image_uploads_total) by (format)
```

#### cache_hits_total
- **类型**: Counter
- **描述**: 缓存命中总数
- **标签**:
  - `cache_type`: 缓存类型 (redis, memory)
  - `hit`: 命中状态 (hit, miss)

**示例查询**:
```promql
# 缓存命中率
sum(rate(cache_hits_total{hit="hit"}[5m])) / sum(rate(cache_hits_total[5m])) * 100

# 按缓存类型统计命中率
sum(rate(cache_hits_total{hit="hit"}[5m])) by (cache_type) / sum(rate(cache_hits_total[5m])) by (cache_type) * 100
```

## 如何使用

### 1. 在代码中记录指标

#### 记录图片上传
```go
import "imagebed/middleware"

// 上传成功
middleware.RecordImageUpload("jpg", "success")

// 上传失败
middleware.RecordImageUpload("png", "failed")
```

#### 记录缓存命中
```go
import "imagebed/middleware"

// 缓存命中
middleware.RecordCacheHit("redis", true)

// 缓存未命中
middleware.RecordCacheHit("memory", false)
```

### 2. 配置 Prometheus

创建 `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'tc-go'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
```

启动 Prometheus:
```bash
prometheus --config.file=prometheus.yml
```

### 3. 配置 Grafana 可视化

#### 添加数据源
1. 打开 Grafana (默认 http://localhost:3000)
2. Configuration → Data Sources → Add data source
3. 选择 Prometheus
4. URL: http://localhost:9090
5. Save & Test

#### 创建仪表板

**请求监控面板**:
- QPS: `rate(http_requests_total[1m])`
- 平均响应时间: `rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])`
- 错误率: `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))`

**业务监控面板**:
- 图片上传速率: `rate(image_uploads_total{status="success"}[5m])`
- 上传成功率: `sum(rate(image_uploads_total{status="success"}[5m])) / sum(rate(image_uploads_total[5m]))`
- 缓存命中率: `sum(rate(cache_hits_total{hit="hit"}[5m])) / sum(rate(cache_hits_total[5m]))`

## 告警规则

创建 `alerts.yml`:

```yaml
groups:
  - name: tc-go-alerts
    interval: 30s
    rules:
      # 高错误率告警
      - alert: HighErrorRate
        expr: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }}"

      # 高延迟告警
      - alert: HighLatency
        expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency detected"
          description: "P95 latency is {{ $value }}s"

      # 上传失败率告警
      - alert: HighUploadFailureRate
        expr: sum(rate(image_uploads_total{status="failed"}[5m])) / sum(rate(image_uploads_total[5m])) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High upload failure rate"
          description: "Upload failure rate is {{ $value | humanizePercentage }}"

      # 缓存命中率低告警
      - alert: LowCacheHitRate
        expr: sum(rate(cache_hits_total{hit="hit"}[5m])) / sum(rate(cache_hits_total[5m])) < 0.7
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Low cache hit rate"
          description: "Cache hit rate is {{ $value | humanizePercentage }}"
```

## Docker Compose 部署

创建 `docker-compose.monitoring.yml`:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: tc-go-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alerts.yml:/etc/prometheus/alerts.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'

  grafana:
    image: grafana/grafana:latest
    container_name: tc-go-grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - prometheus

volumes:
  prometheus-data:
  grafana-data:
```

启动监控栈:
```bash
docker-compose -f docker-compose.monitoring.yml up -d
```

## 性能考虑

1. **指标基数**: 避免使用高基数标签（如用户 ID、请求 ID）
2. **采样率**: 根据流量调整 Prometheus 的 `scrape_interval`
3. **数据保留**: 配置合适的数据保留策略
4. **聚合**: 使用 recording rules 预聚合常用查询

## 最佳实践

1. ✅ 使用有意义的指标名称
2. ✅ 选择合适的指标类型（Counter, Gauge, Histogram, Summary）
3. ✅ 保持标签基数可控
4. ✅ 使用标准化的标签名称
5. ✅ 添加注释说明指标用途
6. ✅ 定期审查和清理未使用的指标

## 故障排查

### 指标未显示
1. 检查 `/metrics` 端点是否可访问
2. 验证 Prometheus 配置中的 target
3. 查看 Prometheus 日志

### 性能问题
1. 减少高基数标签
2. 增加 `scrape_interval`
3. 使用 recording rules

### 数据不准确
1. 检查时钟同步
2. 验证查询语句
3. 确认数据保留策略

## 参考资源

- [Prometheus 官方文档](https://prometheus.io/docs/)
- [Grafana 官方文档](https://grafana.com/docs/)
- [PromQL 查询语言](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Prometheus 最佳实践](https://prometheus.io/docs/practices/)
