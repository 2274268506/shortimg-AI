# ========================================
# 📖 分流配置指南
# ========================================

## 目录
1. [快速开始](#快速开始)
2. [配置结构](#配置结构)
3. [CDN节点配置](#cdn节点配置)
4. [路由规则配置](#路由规则配置)
5. [条件类型说明](#条件类型说明)
6. [实战案例](#实战案例)
7. [最佳实践](#最佳实践)
8. [故障排查](#故障排查)

---

## 快速开始

### 1. 基础配置

编辑 `routing_rules.yaml` 文件：

```yaml
# 1. 定义你的CDN节点
cdn_nodes:
  - id: my_cdn
    domain_env: MY_CDN_DOMAIN
    protocol_env: MY_CDN_PROTOCOL
    default_domain: cdn.example.com
    default_protocol: https

# 2. 添加路由规则
routing_rules:
  - name: 我的第一条规则
    priority: 10
    enabled: true
    conditions:
      - type: country
        value: CN
    target: my_cdn
```

### 2. 应用配置

```bash
# 1. 验证配置语法
docker-compose exec redirect-service lua /path/to/validate_routing.lua

# 2. 重启服务
docker-compose restart redirect-service

# 3. 查看日志
docker-compose logs -f redirect-service
```

---

## 配置结构

```yaml
routing_rules.yaml
├── cdn_nodes          # CDN节点定义
│   ├── id             # 节点唯一标识
│   ├── name           # 节点名称
│   ├── domain_env     # 域名环境变量名
│   ├── protocol_env   # 协议环境变量名
│   └── default_*      # 默认值
│
├── routing_rules      # 路由规则列表
│   ├── name           # 规则名称
│   ├── priority       # 优先级（越小越优先）
│   ├── enabled        # 是否启用
│   ├── conditions     # 匹配条件（AND逻辑）
│   └── target         # 目标CDN节点ID
│
├── default_routing    # 默认路由
│   ├── target         # 默认目标
│   └── fallback_chain # 降级链
│
└── advanced           # 高级配置
    ├── enable_rule_cache
    ├── enable_routing_log
    └── enable_health_check
```

---

## CDN节点配置

### 节点定义

```yaml
cdn_nodes:
  - id: my_cdn                      # 必需：唯一标识符
    name: 我的CDN节点                # 必需：显示名称
    domain_env: MY_CDN_DOMAIN        # 必需：环境变量名
    protocol_env: MY_CDN_PROTOCOL    # 必需：协议环境变量
    port_env: MY_CDN_PORT            # 可选：端口环境变量
    default_domain: cdn.example.com  # 必需：默认域名
    default_protocol: https          # 必需：默认协议
    default_port: "8080"             # 可选：默认端口
```

### 环境变量配置

在 `.env` 文件中：

```bash
MY_CDN_DOMAIN=cdn.mysite.com
MY_CDN_PROTOCOL=https
MY_CDN_PORT=443
```

### 预定义节点

系统预定义了以下节点：
- `private` - 私有网络
- `public` - 公共网络
- `north_telecom` - 北方电信
- `south_unicom` - 南方联通
- `overseas` - 海外节点
- `tc_go_primary` - TC-GO主服务器
- `tc_go_backup` - TC-GO备份服务器
- `fallback` - 降级服务器

---

## 路由规则配置

### 基本规则结构

```yaml
routing_rules:
  - name: 规则名称              # 必需：便于识别
    priority: 10                # 必需：优先级（1-999）
    enabled: true               # 必需：是否启用
    conditions:                 # 必需：条件列表
      - type: condition_type    # 条件类型
        # 其他条件参数...
    target: cdn_node_id         # 必需：目标节点ID
```

### 优先级说明

- **1-10**: 最高优先级（关键规则）
- **11-50**: 高优先级（地理/运营商规则）
- **51-100**: 中等优先级（路径/时间规则）
- **101+**: 低优先级（实验性规则）

### 多条件匹配

条件之间是 **AND** 关系，必须全部满足：

```yaml
- name: 北京电信用户
  conditions:
    - type: province
      values: [北京]
    - type: isp
      values: [China Telecom]
  target: beijing_telecom_cdn
```

---

## 条件类型说明

### 1. IP范围匹配 (ip_range)

根据客户端IP地址匹配。

```yaml
- type: ip_range
  ranges:
    - 10.0.0.0/8
    - 172.16.0.0/12
    - 192.168.0.0/16
    - 127.0.0.0/8
```

**适用场景：**
- 内网用户分流
- 特定网段隔离
- VPN用户识别

---

### 2. 省份匹配 (province)

根据客户端所在省份匹配。

```yaml
- type: province
  values:
    - 北京
    - 上海
    - 广东
```

**适用场景：**
- 区域性CDN部署
- 就近访问优化
- 合规要求（数据本地化）

---

### 3. 运营商匹配 (isp)

根据客户端运营商匹配。

```yaml
- type: isp
  values:
    - China Telecom
    - China Unicom
    - China Mobile
    - ChinaNet
```

**适用场景：**
- 运营商专线优化
- 避免跨网访问
- 成本优化

---

### 4. 国家匹配 (country)

根据客户端所在国家匹配。

```yaml
# 匹配中国
- type: country
  value: CN

# 匹配非中国（海外）
- type: country
  operator: not_equals
  value: CN
```

**适用场景：**
- 国内外分流
- 合规要求
- CDN成本控制

---

### 5. ASN匹配 (asn)

根据自治系统号匹配。

```yaml
- type: asn
  values:
    - 4134   # China Telecom
    - 4837   # China Unicom
    - 9808   # China Mobile
```

**适用场景：**
- 精确运营商识别
- 专线网络优化
- 高级流量工程

---

### 6. 路径前缀匹配 (path_prefix)

根据URL路径前缀匹配。

```yaml
- type: path_prefix
  values:
    - /img/
    - /image/
    - /upload/
    - /static/
```

**适用场景：**
- 不同资源类型分流
- 图床/视频分离
- API与静态资源分离

---

### 7. 时间段匹配 (time_range)

根据访问时间匹配（24小时制）。

```yaml
# 工作时间（9:00-18:00）
- type: time_range
  start_hour: 9
  end_hour: 18

# 夜间时段（22:00-次日6:00）
- type: time_range
  start_hour: 22
  end_hour: 6
```

**适用场景：**
- 峰谷分流
- 夜间维护
- 成本优化

---

### 8. 百分比分流 (percentage)

按百分比分配流量。

```yaml
# 20%的流量
- type: percentage
  value: 20
```

**适用场景：**
- A/B测试
- 灰度发布
- 渐进式迁移

---

### 9. HTTP Header匹配 (header)

根据HTTP请求头匹配。

```yaml
- type: header
  name: X-CDN-Prefer
  value: backup
```

**适用场景：**
- 客户端指定CDN
- 调试/测试
- 高级用户优化

---

### 10. URL参数匹配 (query_param)

根据URL查询参数匹配。

```yaml
- type: query_param
  name: cdn
  value: overseas
```

**适用场景：**
- 动态CDN切换
- 调试功能
- 用户自选节点

---

## 实战案例

### 案例1: 基础内外网分流

```yaml
routing_rules:
  # 内网用户使用本地CDN
  - name: 内网访问
    priority: 10
    enabled: true
    conditions:
      - type: ip_range
        ranges:
          - 192.168.0.0/16
    target: private

  # 外网用户使用公网CDN
  - name: 外网访问
    priority: 20
    enabled: true
    conditions:
      - type: ip_range
        ranges:
          - 0.0.0.0/0
    target: public
```

---

### 案例2: 电信联通分流优化

```yaml
routing_rules:
  # 电信用户
  - name: 电信用户优化
    priority: 10
    enabled: true
    conditions:
      - type: isp
        values:
          - China Telecom
          - ChinaNet
    target: telecom_cdn

  # 联通用户
  - name: 联通用户优化
    priority: 20
    enabled: true
    conditions:
      - type: isp
        values:
          - China Unicom
    target: unicom_cdn

  # 其他用户
  - name: 默认路由
    priority: 100
    enabled: true
    conditions: []
    target: public
```

---

### 案例3: 图床与API分离

```yaml
routing_rules:
  # 图片走图床CDN
  - name: 图片资源
    priority: 10
    enabled: true
    conditions:
      - type: path_prefix
        values:
          - /img/
          - /upload/
    target: image_cdn

  # API走主CDN
  - name: API请求
    priority: 20
    enabled: true
    conditions:
      - type: path_prefix
        values:
          - /api/
    target: api_cdn
```

---

### 案例4: 海外访问优化

```yaml
routing_rules:
  # 海外用户
  - name: 海外访问
    priority: 10
    enabled: true
    conditions:
      - type: country
        operator: not_equals
        value: CN
    target: overseas_cdn

  # 国内用户
  - name: 国内访问
    priority: 20
    enabled: true
    conditions:
      - type: country
        value: CN
    target: china_cdn
```

---

### 案例5: 灰度发布（20%新CDN）

```yaml
routing_rules:
  # 20%流量到新CDN
  - name: 灰度测试
    priority: 10
    enabled: true
    conditions:
      - type: percentage
        value: 20
    target: new_cdn

  # 80%流量到旧CDN
  - name: 稳定版本
    priority: 100
    enabled: true
    conditions: []
    target: old_cdn
```

---

### 案例6: 夜间维护窗口

```yaml
routing_rules:
  # 凌晨2-6点使用备份CDN
  - name: 夜间维护
    priority: 10
    enabled: true
    conditions:
      - type: time_range
        start_hour: 2
        end_hour: 6
    target: backup_cdn

  # 其他时间使用主CDN
  - name: 正常时段
    priority: 100
    enabled: true
    conditions: []
    target: primary_cdn
```

---

### 案例7: VIP用户专线

```yaml
routing_rules:
  # VIP用户专属CDN
  - name: VIP用户
    priority: 5
    enabled: true
    conditions:
      - type: header
        name: X-User-Level
        value: VIP
    target: vip_cdn

  # 普通用户
  - name: 普通用户
    priority: 100
    enabled: true
    conditions: []
    target: public
```

---

## 最佳实践

### 1. 优先级设置建议

```yaml
# ✅ 推荐：清晰的优先级分层
- priority: 10   # 关键业务规则
- priority: 20   # 地理位置规则
- priority: 30   # 运营商规则
- priority: 40   # 路径规则
- priority: 100  # 默认规则

# ❌ 避免：混乱的优先级
- priority: 15
- priority: 16
- priority: 17
```

---

### 2. 规则命名规范

```yaml
# ✅ 推荐：清晰描述性的名称
- name: 北京电信用户-主CDN
- name: 图片资源-图床CDN
- name: 海外用户-海外CDN

# ❌ 避免：模糊的名称
- name: 规则1
- name: test
- name: aaa
```

---

### 3. 测试策略

```yaml
# 添加测试规则（URL参数触发）
- name: 测试-新CDN
  priority: 1  # 最高优先级
  enabled: true
  conditions:
    - type: query_param
      name: test_cdn
      value: new
  target: new_cdn
```

访问时添加 `?test_cdn=new` 即可测试新CDN。

---

### 4. 降级策略

```yaml
default_routing:
  target: public
  fallback_chain:
    - primary_cdn
    - backup_cdn
    - public
    - fallback
```

当目标CDN不可用时，自动尝试降级链中的下一个。

---

### 5. 日志监控

```yaml
advanced:
  enable_routing_log: true  # 开发环境开启
  enable_routing_log: false # 生产环境关闭（性能优化）
```

---

## 故障排查

### 问题1: 规则不生效

**症状：** 配置了规则但流量没有分流

**检查步骤：**
1. 确认规则 `enabled: true`
2. 检查优先级是否被其他规则覆盖
3. 验证条件是否正确匹配
4. 查看日志：`docker-compose logs redirect-service | grep RoutingEngine`

---

### 问题2: 配置语法错误

**症状：** 服务启动失败或无法加载配置

**检查步骤：**
1. 验证YAML语法：https://www.yamllint.com/
2. 检查缩进（必须使用空格，不能使用Tab）
3. 检查特殊字符是否正确转义

---

### 问题3: CDN节点无法访问

**症状：** 匹配规则后返回502/504错误

**检查步骤：**
1. 确认环境变量正确配置
2. 测试CDN节点可达性：`curl -v https://cdn.example.com`
3. 检查降级链配置
4. 启用健康检查：`enable_health_check: true`

---

### 问题4: 性能问题

**症状：** 配置规则后响应变慢

**优化方案：**
1. 启用规则缓存：`enable_rule_cache: true`
2. 减少复杂条件（如正则表达式）
3. 合并相似规则
4. 关闭路由日志：`enable_routing_log: false`

---

### 问题5: GeoIP数据不准确

**症状：** 地理位置判断错误

**解决方案：**
1. 更新GeoIP数据库：
   ```bash
   cd /path/to/geoip
   wget https://git.io/GeoLite2-Country.mmdb
   ```
2. 使用IP段匹配代替省份匹配
3. 添加Header或参数覆盖机制

---

## 调试技巧

### 1. 启用调试日志

```yaml
advanced:
  enable_routing_log: true
```

### 2. 测试特定规则

```bash
# 添加测试参数
curl "http://short.example.com/abc?test_cdn=backup"
```

### 3. 查看匹配日志

```bash
# 实时查看日志
docker-compose logs -f redirect-service | grep "匹配规则"

# 查看最近100条
docker-compose logs --tail=100 redirect-service | grep "RoutingEngine"
```

### 4. 强制重载配置

```lua
-- 在Lua中调用
local routing_engine = require "routing_engine"
routing_engine.reload()
```

---

## 配置模板

### 模板1: 简单内外网分流

```yaml
cdn_nodes:
  - id: internal
    domain_env: INTERNAL_CDN_DOMAIN
    default_domain: cdn.internal.com
    default_protocol: http
  - id: external
    domain_env: EXTERNAL_CDN_DOMAIN
    default_domain: cdn.example.com
    default_protocol: https

routing_rules:
  - name: 内网
    priority: 10
    enabled: true
    conditions:
      - type: ip_range
        ranges: [192.168.0.0/16]
    target: internal
  - name: 外网
    priority: 100
    enabled: true
    conditions: []
    target: external

default_routing:
  target: external
```

---

### 模板2: 完整生产环境配置

参见 `routing_rules.yaml` 默认配置。

---

## 总结

通过灵活的配置系统，你可以：

✅ 自由添加/删除/修改分流规则
✅ 支持10+种条件类型组合
✅ 热更新配置无需重启
✅ 完善的降级和容错机制
✅ 详细的日志和监控支持

**开始使用：** 复制 `routing_rules.yaml.example` → `routing_rules.yaml`，根据需求修改配置！
