# 监控和可观测性系统

## 概述

短链服务使用 Prometheus + Grafana 实现完整的监控和可观测性系统，包括：

- **指标收集**: Prometheus
- **可视化**: Grafana
- **告警**: Prometheus AlertManager
- **导出器**: Redis Exporter, MySQL Exporter

## 系统架构

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ 短链服务    │────▶│  Prometheus  │────▶│  Grafana    │
│ (OpenResty) │     │   :9090      │     │   :3000     │
└─────────────┘     └──────────────┘     └─────────────┘
       │                    ▲
       │                    │
       ▼                    │
┌─────────────┐            │
│ /metrics    │────────────┘
│  端点       │
└─────────────┘

┌─────────────┐     ┌──────────────┐
│   Redis     │────▶│Redis Exporter│
│   :6379     │     │   :9121      │────────┐
└─────────────┘     └──────────────┘        │
                                             │
┌─────────────┐     ┌──────────────┐        │
│   MySQL     │────▶│MySQL Exporter│        │
│   :3306     │     │   :9104      │────────┤
└─────────────┘     └──────────────┘        │
                                             ▼
                                    ┌──────────────┐
                                    │  Prometheus  │
                                    └──────────────┘
```

## 快速开始

### 1. 启动监控栈

```powershell
# 启动所有服务
docker-compose up -d

# 验证监控系统状态
.\scripts\check-monitoring.ps1
```

### 2. 访问监控界面

- **Prometheus**: http://localhost:9090
  - 查询指标和设置告警规则

- **Grafana**: http://localhost:3000
  - 默认账号: `admin` / `admin`
  - 首次登录会要求修改密码

- **短链服务指标**: http://localhost/metrics
  - Prometheus 格式的指标数据

### 3. Grafana 配置

Grafana 已预配置以下内容：

#### 数据源
- **Prometheus**: 已自动配置为默认数据源（http://prometheus:9090）

#### 仪表板
- **Short Link Overview**: 短链服务总览仪表板
  - 请求量和QPS
  - 错误率趋势
  - 响应时间（P50/P95/P99）
  - 缓存命中率
  - 活跃连接数
  - 短链总数
  - 速率限制触发次数

访问路径：Dashboards → Short Link Overview

## 监控指标

### HTTP 请求指标

| 指标名称 | 类型 | 说明 | 标签 |
|---------|------|------|------|
| `short_link_http_requests_total` | Counter | HTTP 请求总数 | method, endpoint, status |
| `short_link_http_request_duration_seconds` | Histogram | HTTP 请求延迟分布 | method, endpoint |

### 重定向指标

| 指标名称 | 类型 | 说明 | 标签 |
|---------|------|------|------|
| `short_link_redirect_requests_total` | Counter | 重定向请求总数 | - |
| `short_link_redirect_duration_seconds` | Histogram | 重定向延迟分布 | - |

### 缓存指标

| 指标名称 | 类型 | 说明 | 标签 |
|---------|------|------|------|
| `short_link_cache_hit_rate` | Gauge | 缓存命中率 | cache_type |

缓存类型：
- `l1`: 本地缓存（Lua shared dict）
- `l2`: Redis 缓存

### Redis 指标

| 指标名称 | 类型 | 说明 | 标签 |
|---------|------|------|------|
| `short_link_redis_operations_total` | Counter | Redis 操作总数 | operation |
| `short_link_redis_operation_duration_seconds` | Histogram | Redis 操作延迟 | operation |

Redis 操作类型：
- `get`: GET 操作
- `set`: SET 操作
- `del`: DELETE 操作

### MySQL 指标

| 指标名称 | 类型 | 说明 | 标签 |
|---------|------|------|------|
| `short_link_mysql_queries_total` | Counter | MySQL 查询总数 | query_type |
| `short_link_mysql_query_duration_seconds` | Histogram | MySQL 查询延迟 | query_type |

查询类型：
- `select`: SELECT 查询
- `insert`: INSERT 查询
- `update`: UPDATE 查询

### 业务指标

| 指标名称 | 类型 | 说明 | 标签 |
|---------|------|------|------|
| `short_link_short_links_total` | Gauge | 短链总数 | - |
| `short_link_active_connections` | Gauge | 当前活跃连接数 | - |

### 错误指标

| 指标名称 | 类型 | 说明 | 标签 |
|---------|------|------|------|
| `short_link_api_errors_total` | Counter | API 错误总数 | error_type |
| `short_link_rate_limit_exceeded_total` | Counter | 速率限制触发次数 | - |

## 告警规则

系统预配置了以下告警规则（位于 `monitoring/prometheus/rules/alerts.yml`）：

### 服务可用性告警

| 规则名称 | 严重级别 | 触发条件 | 说明 |
|---------|---------|---------|------|
| ServiceDown | critical | 服务下线超过1分钟 | 短链服务不可用 |
| HighRequestFailureRate | critical | 5分钟内失败率>10% | 请求失败率过高 |

### 性能告警

| 规则名称 | 严重级别 | 触发条件 | 说明 |
|---------|---------|---------|------|
| HighLatency | warning | P99延迟>1秒持续5分钟 | 响应时间过长 |
| SlowRedirects | warning | 重定向P99延迟>500ms持续5分钟 | 重定向速度慢 |

### 错误率告警

| 规则名称 | 严重级别 | 触发条件 | 说明 |
|---------|---------|---------|------|
| HighErrorRate | critical | 5分钟内5xx错误率>5% | 服务器错误率高 |
| High4xxRate | warning | 5分钟内4xx错误率>20% | 客户端错误率高 |

### 资源使用告警

| 规则名称 | 严重级别 | 触发条件 | 说明 |
|---------|---------|---------|------|
| HighConnectionCount | warning | 活跃连接数>5000持续5分钟 | 连接数过高 |

### 缓存性能告警

| 规则名称 | 严重级别 | 触发条件 | 说明 |
|---------|---------|---------|------|
| LowCacheHitRate | warning | 缓存命中率<70%持续10分钟 | 缓存效率低 |
| SlowRedisOperations | warning | Redis P95延迟>100ms持续5分钟 | Redis 响应慢 |

### 数据库告警

| 规则名称 | 严重级别 | 触发条件 | 说明 |
|---------|---------|---------|------|
| SlowMySQLQueries | warning | MySQL P95延迟>1秒持续5分钟 | 数据库查询慢 |
| MySQLDown | critical | MySQL 不可用超过1分钟 | 数据库不可用 |

### 业务指标告警

| 规则名称 | 严重级别 | 触发条件 | 说明 |
|---------|---------|---------|------|
| HighRateLimitRate | warning | 速率限制触发频率>100次/分钟 | 频繁触发限流 |

## 查询示例

### 在 Prometheus 中查询

#### 1. 查看当前 QPS
```promql
rate(short_link_http_requests_total[1m])
```

#### 2. 查看 P95 响应时间
```promql
histogram_quantile(0.95,
  rate(short_link_http_request_duration_seconds_bucket[5m])
)
```

#### 3. 查看错误率
```promql
sum(rate(short_link_http_requests_total{status=~"5.."}[5m])) /
sum(rate(short_link_http_requests_total[5m])) * 100
```

#### 4. 查看缓存命中率
```promql
short_link_cache_hit_rate
```

#### 5. 查看 Redis 操作延迟
```promql
histogram_quantile(0.95,
  rate(short_link_redis_operation_duration_seconds_bucket[5m])
)
```

## 自定义监控

### 添加新指标

1. 在 `lua/utils/prometheus.lua` 中定义新指标：

```lua
-- 定义新的计数器
local my_metric = prometheus:counter(
    "my_metric_total",
    "My metric description",
    {"label1", "label2"}
)

-- 在代码中使用
function _M.record_my_metric(label1, label2)
    my_metric:inc({label1, label2}, 1)
end
```

2. 在业务代码中调用：

```lua
local prometheus = require("utils.prometheus")
prometheus.record_my_metric("value1", "value2")
```

### 添加新告警规则

编辑 `monitoring/prometheus/rules/alerts.yml`：

```yaml
- alert: MyCustomAlert
  expr: my_metric_total > 100
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "自定义告警"
    description: "指标超过阈值"
```

重启 Prometheus 使配置生效：

```powershell
docker-compose restart prometheus
```

## 故障排查

### Prometheus 无法抓取指标

1. 检查服务是否运行：
```powershell
docker-compose ps
```

2. 检查指标端点：
```powershell
curl http://localhost/metrics
```

3. 查看 Prometheus 日志：
```powershell
docker logs short-link-prometheus
```

### Grafana 无数据

1. 检查数据源配置：
   - 访问 Grafana → Configuration → Data Sources
   - 确认 Prometheus 数据源 URL 正确

2. 测试数据源连接：
   - 点击 "Test" 按钮
   - 应该显示 "Data source is working"

3. 检查 Prometheus 是否有数据：
   - 访问 http://localhost:9090
   - 执行查询验证数据存在

### MySQL Exporter 无法连接

1. 检查密码配置：
```powershell
docker logs short-link-mysql-exporter
```

2. 验证 MySQL 连接：
```powershell
docker exec -it short-link-mysql mysql -uroot -p
```

3. 检查环境变量：
```powershell
docker exec short-link-mysql-exporter env | grep MYSQL
```

## 性能优化建议

### 1. 指标采集频率

默认采集间隔：
- 短链服务: 10秒
- 其他服务: 15秒

可在 `monitoring/prometheus/prometheus.yml` 中调整：

```yaml
scrape_configs:
  - job_name: 'short-link-service'
    scrape_interval: 10s  # 调整此值
```

### 2. 指标保留时间

默认保留15天。可在 `docker-compose.yml` 中调整：

```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=15d'  # 调整此值
```

### 3. 共享字典大小

如果指标数量很大，可能需要增大 `prometheus_metrics` 字典：

```nginx
lua_shared_dict prometheus_metrics 200m;  # 增大此值
```

## 生产环境建议

### 1. 启用告警通知

配置 AlertManager 发送告警到：
- Email
- Slack
- PagerDuty
- 微信

### 2. 数据持久化

确保 Prometheus 数据持久化：

```yaml
volumes:
  - prometheus-data:/prometheus
```

### 3. 访问控制

- 为 Grafana 配置 LDAP/OAuth 认证
- 使用反向代理保护 Prometheus
- 限制 /metrics 端点访问

### 4. 高可用

- 运行多个 Prometheus 实例
- 使用 Thanos 或 Cortex 实现长期存储
- 配置 Grafana 高可用集群

## 相关文档

- [Prometheus 文档](https://prometheus.io/docs/)
- [Grafana 文档](https://grafana.com/docs/)
- [lua-resty-prometheus](https://github.com/knyar/nginx-lua-prometheus)
- [MySQL Exporter](https://github.com/prometheus/mysqld_exporter)
- [Redis Exporter](https://github.com/oliver006/redis_exporter)

## 维护清单

### 每日
- [ ] 检查告警状态
- [ ] 查看错误率和延迟趋势
- [ ] 验证所有服务正常运行

### 每周
- [ ] 审查性能趋势
- [ ] 优化慢查询
- [ ] 清理过期数据

### 每月
- [ ] 更新仪表板
- [ ] 调整告警阈值
- [ ] 审查和优化指标

---

最后更新: 2025-06-05
