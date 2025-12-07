# 🌐 CDN节点配置说明

## 📋 节点列表

短链服务提供8个CDN节点，可根据实际情况配置使用：

| 节点ID | 名称 | 用途 | 优先级建议 |
|-------|------|------|-----------|
| `private` | 私有网络CDN | 内网/开发环境 | 最高（10） |
| `unicom` | 联通CDN | 联通用户优化 | 高（20-30） |
| `mobile` | 移动CDN | 移动用户优化 | 高（30-40） |
| `telecom` | 电信CDN | 电信用户优化 | 高（20-30） |
| `china` | 国内CDN | 国内通用节点 | 中（50-60） |
| `overseas` | 国外CDN | 海外用户优化 | 中（50-60） |
| `backup` | 备用CDN | 备份/灰度 | 低（70+） |
| `default` | 默认CDN | 兜底节点 | 兜底（降级链） |

## ⚙️ 配置方式

### 1. 环境变量配置（.env）

```bash
# 节点配置格式
CDN_{节点ID大写}_DOMAIN=域名
CDN_{节点ID大写}_PROTOCOL=协议
CDN_{节点ID大写}_PORT=端口（可选）

# 示例：配置电信CDN
CDN_TELECOM_DOMAIN=cdn-ct.example.com
CDN_TELECOM_PROTOCOL=https
CDN_TELECOM_PORT=443
```

### 2. 路由规则配置（routing_rules.yaml）

```yaml
cdn_nodes:
  - id: telecom              # 节点ID
    name: 电信CDN            # 显示名称
    domain_env: CDN_TELECOM_DOMAIN
    protocol_env: CDN_TELECOM_PROTOCOL
    port_env: CDN_TELECOM_PORT
    default_domain: cdn-telecom.example.com
    default_protocol: https
```

## 🎯 典型使用场景

### 场景1: 单CDN部署（最简单）

只使用一个CDN，所有流量都指向它：

```bash
# .env
CDN_DEFAULT_DOMAIN=cdn.example.com
CDN_DEFAULT_PROTOCOL=https
```

```yaml
# routing_rules.yaml
routing_rules:
  - name: 所有流量
    priority: 10
    enabled: true
    conditions: []
    target: default
```

### 场景2: 内外网分流

区分内网和外网用户：

```bash
# .env
CDN_PRIVATE_DOMAIN=192.168.1.100
CDN_PRIVATE_PROTOCOL=http

CDN_CHINA_DOMAIN=cdn.example.com
CDN_CHINA_PROTOCOL=https
```

```yaml
# routing_rules.yaml
routing_rules:
  - name: 内网
    priority: 10
    conditions:
      - type: ip_range
        ranges: [192.168.0.0/16]
    target: private

  - name: 外网
    priority: 100
    conditions: []
    target: china
```

### 场景3: 三大运营商分流（推荐）

针对电信、联通、移动用户优化：

```bash
# .env
CDN_TELECOM_DOMAIN=cdn-ct.example.com
CDN_UNICOM_DOMAIN=cdn-cu.example.com
CDN_MOBILE_DOMAIN=cdn-cm.example.com
CDN_CHINA_DOMAIN=cdn.example.com
```

```yaml
# routing_rules.yaml
routing_rules:
  - name: 电信用户
    priority: 20
    conditions:
      - type: isp
        values: [China Telecom, ChinaNet]
    target: telecom

  - name: 联通用户
    priority: 30
    conditions:
      - type: isp
        values: [China Unicom]
    target: unicom

  - name: 移动用户
    priority: 40
    conditions:
      - type: isp
        values: [China Mobile]
    target: mobile

  - name: 其他用户
    priority: 100
    conditions: []
    target: china
```

### 场景4: 国内外分流

区分国内和海外用户：

```bash
# .env
CDN_CHINA_DOMAIN=cdn-cn.example.com
CDN_OVERSEAS_DOMAIN=cdn-global.example.com
```

```yaml
# routing_rules.yaml
routing_rules:
  - name: 海外用户
    priority: 10
    conditions:
      - type: country
        operator: not_equals
        value: CN
    target: overseas

  - name: 国内用户
    priority: 100
    conditions: []
    target: china
```

### 场景5: 多级容灾（完整配置）

所有节点都配置，实现多级容灾：

```bash
# .env
CDN_PRIVATE_DOMAIN=192.168.1.100
CDN_TELECOM_DOMAIN=cdn-ct.example.com
CDN_UNICOM_DOMAIN=cdn-cu.example.com
CDN_MOBILE_DOMAIN=cdn-cm.example.com
CDN_CHINA_DOMAIN=cdn-cn.example.com
CDN_OVERSEAS_DOMAIN=cdn-global.example.com
CDN_BACKUP_DOMAIN=cdn-backup.example.com
CDN_DEFAULT_DOMAIN=cdn.example.com
```

```yaml
# routing_rules.yaml
routing_rules:
  - name: 内网
    priority: 10
    conditions:
      - type: ip_range
        ranges: [192.168.0.0/16]
    target: private

  - name: 电信
    priority: 20
    conditions:
      - type: isp
        values: [China Telecom]
    target: telecom

  - name: 联通
    priority: 30
    conditions:
      - type: isp
        values: [China Unicom]
    target: unicom

  - name: 移动
    priority: 40
    conditions:
      - type: isp
        values: [China Mobile]
    target: mobile

  - name: 海外
    priority: 50
    conditions:
      - type: country
        operator: not_equals
        value: CN
    target: overseas

  - name: 国内其他
    priority: 100
    conditions: []
    target: china

default_routing:
  target: default
  fallback_chain:
    - china
    - backup
    - default
```

## 💡 节点配置建议

### 最小配置（开发环境）

只需配置2个节点：

```bash
CDN_PRIVATE_DOMAIN=localhost      # 开发环境
CDN_DEFAULT_DOMAIN=cdn.example.com  # 默认CDN
```

### 标准配置（生产环境）

配置4-5个节点：

```bash
CDN_PRIVATE_DOMAIN=...    # 内网
CDN_CHINA_DOMAIN=...      # 国内
CDN_OVERSEAS_DOMAIN=...   # 海外
CDN_BACKUP_DOMAIN=...     # 备份
CDN_DEFAULT_DOMAIN=...    # 默认
```

### 完整配置（高性能需求）

配置所有8个节点：

```bash
CDN_PRIVATE_DOMAIN=...    # 内网
CDN_TELECOM_DOMAIN=...    # 电信
CDN_UNICOM_DOMAIN=...     # 联通
CDN_MOBILE_DOMAIN=...     # 移动
CDN_CHINA_DOMAIN=...      # 国内通用
CDN_OVERSEAS_DOMAIN=...   # 海外
CDN_BACKUP_DOMAIN=...     # 备份
CDN_DEFAULT_DOMAIN=...    # 默认
```

## 🔧 节点域名示例

### 使用相同域名不同端口

```bash
CDN_TELECOM_DOMAIN=cdn.example.com
CDN_TELECOM_PORT=8001

CDN_UNICOM_DOMAIN=cdn.example.com
CDN_UNICOM_PORT=8002

CDN_MOBILE_DOMAIN=cdn.example.com
CDN_MOBILE_PORT=8003
```

### 使用不同子域名

```bash
CDN_TELECOM_DOMAIN=ct.cdn.example.com
CDN_UNICOM_DOMAIN=cu.cdn.example.com
CDN_MOBILE_DOMAIN=cm.cdn.example.com
```

### 使用不同域名

```bash
CDN_TELECOM_DOMAIN=cdn-ct.example.com
CDN_UNICOM_DOMAIN=cdn-cu.example.com
CDN_MOBILE_DOMAIN=cdn-cm.example.com
```

## 🔍 验证配置

### 1. 验证语法

```bash
lua scripts/validate_routing.lua
```

### 2. 测试连通性

```bash
# 测试各CDN节点
curl -I https://cdn-ct.example.com
curl -I https://cdn-cu.example.com
curl -I https://cdn-cm.example.com
```

### 3. 查看日志

```bash
# 查看路由决策
docker-compose logs -f redirect-service | grep RoutingEngine
```

## 📊 性能对比

| 配置方案 | 节点数 | 配置难度 | 性能 | 容灾能力 |
|---------|-------|---------|------|---------|
| 单CDN | 1 | ⭐ | ⭐⭐ | ⭐ |
| 内外网分流 | 2 | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| 三大运营商 | 3-4 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| 完整配置 | 8 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

## ❓ 常见问题

### Q1: 必须配置所有8个节点吗？

**A:** 不需要。只配置你实际使用的节点即可。最少只需配置1个默认节点。

### Q2: 节点名称可以自定义吗？

**A:** 节点ID（如 `telecom`、`unicom`）不能改，但显示名称（`name`字段）可以自定义。

### Q3: 如何临时禁用某个节点？

**A:** 在 `routing_rules.yaml` 中将使用该节点的规则设置为 `enabled: false`。

### Q4: 多个CDN使用同一个域名可以吗？

**A:** 可以，通过不同端口区分即可（如8001、8002、8003）。

### Q5: 如何测试新CDN节点？

**A:** 添加一个高优先级规则，使用 URL参数触发：

```yaml
- name: 测试新CDN
  priority: 1
  enabled: true
  conditions:
    - type: query_param
      name: test_cdn
      value: new
  target: backup
```

访问：`http://short.domain.com/abc?test_cdn=new`

---

## 🔧 节点增减操作指南

### ➕ 添加新CDN节点

**示例：添加"视频加速CDN"节点**

#### 步骤1: 修改 `routing_rules.yaml`

在 `cdn_nodes` 部分添加节点定义：

```yaml
cdn_nodes:
  # ... 现有节点 ...

  # 视频加速CDN（媒体内容优化）
  - id: video
    name: 视频加速CDN
    domain_env: CDN_VIDEO_DOMAIN
    protocol_env: CDN_VIDEO_PROTOCOL
    port_env: CDN_VIDEO_PORT
    default_domain: cdn-video.example.com
    default_protocol: https
```

#### 步骤2: 配置 `.env` 环境变量

```bash
# 视频加速CDN配置
CDN_VIDEO_DOMAIN=video-cdn.yourdomain.com
CDN_VIDEO_PROTOCOL=https
CDN_VIDEO_PORT=443
```

#### 步骤3: 添加路由规则（可选）

```yaml
routing_rules:
  # 视频内容使用视频CDN
  - name: 视频内容分流
    priority: 25
    enabled: true
    conditions:
      - type: path_prefix
        value: "/video/"
    target: video
```

#### 步骤4: 验证配置

```bash
# Linux/Mac
lua scripts/validate_routing.lua

# Windows PowerShell
lua scripts\validate_routing.lua
```

---

### ➖ 删除CDN节点

**示例：删除"备用CDN"节点**

#### 步骤1: 检查依赖

确认该节点没有被以下地方引用：
- ✅ `routing_rules` 中的 `target` 字段
- ✅ `default_routing.fallback_chain` 降级链

#### 步骤2: 修改 `routing_rules.yaml`

```yaml
# 删除或注释掉整个节点配置
cdn_nodes:
  # - id: backup
  #   name: 备用CDN
  #   domain_env: CDN_BACKUP_DOMAIN
  #   protocol_env: CDN_BACKUP_PROTOCOL
  #   port_env: CDN_BACKUP_PORT
  #   default_domain: cdn-backup.example.com
  #   default_protocol: https
```

#### 步骤3: 删除相关路由规则

```yaml
routing_rules:
  # 删除所有 target: backup 的规则
  # - name: 某规则
  #   target: backup  # 删除此规则
```

#### 步骤4: 更新降级链

```yaml
default_routing:
  target: default
  fallback_chain:
    - china
    # - backup  # 删除此行
    - default
```

#### 步骤5: 清理 `.env`（可选）

```bash
# 删除或注释掉相关环境变量
# CDN_BACKUP_DOMAIN=...
# CDN_BACKUP_PROTOCOL=...
# CDN_BACKUP_PORT=...
```

---

### 🔄 快速启用/禁用节点

**无需删除节点，只需禁用相关规则：**

```yaml
routing_rules:
  - name: 移动用户分流
    priority: 40
    enabled: false  # 改为 false 即可禁用
    conditions:
      - type: isp
        value: mobile
    target: mobile
```

**优点：**
- ✅ 保留配置，随时可恢复
- ✅ 无需修改环境变量
- ✅ 降级链依然可用

---

### ⚠️ 注意事项

1. **节点ID唯一性**
   - 新节点的 `id` 不能与现有节点重复
   - 建议使用小写字母和下划线

2. **环境变量命名**
   - 格式：`CDN_{节点ID大写}_DOMAIN/PROTOCOL/PORT`
   - 示例：`CDN_VIDEO_DOMAIN`

3. **降级链完整性**
   - 删除节点前检查 `fallback_chain`
   - 确保降级链中至少有一个可用节点

4. **配置验证**
   - 修改后运行验证脚本
   - 查看日志确认配置加载成功

5. **热更新**
   - 配置修改后自动生效（默认5分钟缓存）
   - 无需重启服务

---

## 📖 相关文档

- [快速入门](ROUTING_QUICK_START.md)
- [完整配置指南](ROUTING_CONFIG_GUIDE.md)
- [路由规则说明](ROUTING_README.md)
