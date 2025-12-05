# 性能优化配置
# 在进行性能优化前，请先运行基准测试获取当前性能指标

## 1. OpenResty 性能优化配置

### Worker 进程配置
# 修改 conf/nginx.conf 的 worker_processes
# 建议设置为 CPU 核心数或 auto
worker_processes: auto

# Worker 连接数
# 每个 worker 进程的最大连接数
# 公式: max_clients = worker_processes * worker_connections
worker_connections: 10240

### 共享内存配置
# 在 nginx.conf 的 http 块中增加共享内存大小
lua_shared_dict:
  - rate_limit: 100m       # 速率限制（增大）
  - link_cache: 200m       # 短链缓存（增大）
  - health_check: 50m      # 健康检查
  - metrics: 100m          # 性能指标

### Lua 代码缓存
# 生产环境必须启用
lua_code_cache: on

### Keepalive 配置
# 上游连接保持
keepalive_timeout: 65
keepalive_requests: 1000

## 2. Redis 性能优化配置

### 连接池配置
redis_pool:
  size: 200              # 连接池大小（增大）
  max_idle_timeout: 30000  # 最大空闲时间（毫秒）
  timeout: 5000          # 连接超时

### Pipeline 批量操作
# 在 lua/storage/redis_client.lua 中实现 pipeline
enable_pipeline: true

### 本地缓存策略
# 使用 lua_shared_dict 作为 L1 缓存，Redis 作为 L2
local_cache:
  enabled: true
  ttl: 60               # 本地缓存 TTL（秒）
  max_entries: 10000    # 最大缓存条目

## 3. MySQL 性能优化配置

### 连接池配置
mysql_pool:
  size: 100             # 连接池大小
  max_idle_timeout: 30000
  timeout: 5000

### 读写分离（可选）
# 如果配置了主从复制
read_write_splitting:
  enabled: false
  master_host: mysql-master
  slave_hosts:
    - mysql-slave-1
    - mysql-slave-2

## 4. 系统级优化

### TCP 调优（Linux）
# 编辑 /etc/sysctl.conf
sysctl_conf: |
  # TCP 缓冲区
  net.core.rmem_max = 16777216
  net.core.wmem_max = 16777216
  net.ipv4.tcp_rmem = 4096 87380 16777216
  net.ipv4.tcp_wmem = 4096 65536 16777216

  # 连接队列
  net.core.somaxconn = 65535
  net.ipv4.tcp_max_syn_backlog = 8192

  # TIME_WAIT 快速回收
  net.ipv4.tcp_tw_reuse = 1
  net.ipv4.tcp_fin_timeout = 30

  # 连接数限制
  net.ipv4.ip_local_port_range = 10000 65535
  net.ipv4.tcp_max_tw_buckets = 400000

### 文件描述符限制
# 编辑 /etc/security/limits.conf
limits_conf: |
  * soft nofile 655350
  * hard nofile 655350

## 5. Docker 性能优化

### Docker 容器资源限制
docker_resources:
  openresty:
    cpus: "4.0"
    memory: "4g"

  redis:
    cpus: "2.0"
    memory: "4g"

  mysql:
    cpus: "2.0"
    memory: "4g"

### Docker 网络模式
# 使用 host 网络模式可以减少网络开销
network_mode: bridge  # 或 host（需要修改端口映射）

## 6. 性能监控

### 关键指标
metrics_to_monitor:
  - QPS (Queries Per Second)
  - 响应时间 (P50, P95, P99)
  - 错误率
  - CPU 使用率
  - 内存使用率
  - Redis 命中率
  - MySQL 慢查询

### 监控工具
monitoring_tools:
  - Prometheus + Grafana
  - OpenResty 内置指标
  - Redis INFO 命令
  - MySQL Performance Schema

## 7. 优化检查清单

checklist:
  - [ ] 运行基准测试获取当前性能指标
  - [ ] 优化 OpenResty Worker 配置
  - [ ] 增大共享内存大小
  - [ ] 启用 Lua 代码缓存
  - [ ] 优化 Redis 连接池
  - [ ] 实现本地缓存（shared dict）
  - [ ] 实现 Redis Pipeline
  - [ ] 优化 MySQL 连接池
  - [ ] 配置系统级 TCP 参数
  - [ ] 调整 Docker 资源限制
  - [ ] 重新运行基准测试验证优化效果
  - [ ] 对比优化前后的性能指标

## 8. 性能目标

performance_goals:
  health_check:
    qps: ">= 20000"
    p99_latency: "< 10ms"

  redirect:
    qps: ">= 10000"
    p99_latency: "< 50ms"
    error_rate: "< 0.01%"

  api_query:
    qps: ">= 5000"
    p99_latency: "< 100ms"

  mixed_workload:
    qps: ">= 8000"
    p99_latency: "< 80ms"
