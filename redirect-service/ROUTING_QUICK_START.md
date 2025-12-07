# 🎯 分流配置快速入门

## 📋 概述

短链服务使用 `routing_rules.yaml` 统一配置所有分流规则，支持：
- ✅ 10种条件类型组合（IP/地域/运营商/时间/路径等）
- ✅ 优先级控制（灵活的规则顺序）
- ✅ 热更新支持（修改配置自动生效）
- ✅ 降级容错机制（多级CDN故障切换）
- ✅ A/B测试和灰度发布

---

## ⚡ 5分钟快速开始

### 第一步：配置CDN节点

编辑 `.env` 文件，配置CDN节点的域名和协议：

```bash
# 私有网络（内网/开发）
CDN_PRIVATE_DOMAIN=localhost
CDN_PRIVATE_PROTOCOL=http

# 公共网络（生产默认）
CDN_PUBLIC_DOMAIN=cdn.example.com
CDN_PUBLIC_PROTOCOL=https
CDN_PUBLIC_PORT=443

# 其他CDN节点...
```

### 第二步：配置分流规则

编辑 `routing_rules.yaml` 文件：

```yaml
routing_rules:
  # 内网用户
  - name: 内网路由
    priority: 10
    enabled: true
    conditions:
      - type: ip_range
        ranges: [192.168.0.0/16]
    target: private

  # 外网用户（默认）
  - name: 公网路由
    priority: 100
    enabled: true
    conditions: []  # 无条件，匹配所有
    target: public
```

### 第三步：验证配置

```bash
# Linux/macOS
./scripts/validate_config.sh

# Windows
.\scripts\validate_config.ps1

# 或使用Lua验证脚本
docker-compose exec redirect-service lua scripts/validate_routing.lua
```

### 第四步：应用配置

```bash
# 重启服务
docker-compose restart redirect-service

# 查看日志
docker-compose logs -f redirect-service
```

**完成！** 🎉 配置已生效，修改 `routing_rules.yaml` 后会自动热更新。

---

## 📚 常见场景配置

### 场景1: 内外网分流

```yaml
routing_rules:
  - name: 内网
    priority: 10
    enabled: true
    conditions:
      - type: ip_range
        ranges: [192.168.0.0/16, 10.0.0.0/8]
    target: private

  - name: 外网
    priority: 100
    enabled: true
    conditions: []
    target: public
```

### 场景2: 运营商分流

```yaml
routing_rules:
  - name: 电信用户
    priority: 20
    enabled: true
    conditions:
      - type: isp
        values: [China Telecom, ChinaNet]
    target: telecom_cdn

  - name: 联通用户
    priority: 30
    enabled: true
    conditions:
      - type: isp
        values: [China Unicom]
    target: unicom_cdn
```

### 场景3: 海外分流

```yaml
routing_rules:
  - name: 海外用户
    priority: 10
    enabled: true
    conditions:
      - type: country
        operator: not_equals
        value: CN
    target: overseas_cdn
```

### 场景4: 图床分流

```yaml
routing_rules:
  - name: 图片资源
    priority: 10
    enabled: true
    conditions:
      - type: path_prefix
        values: [/img/, /upload/]
    target: image_cdn
```

---

## 🔧 高级功能

### 1. 规则优先级

规则按 `priority` 从小到大匹配：

```yaml
routing_rules:
  - name: VIP用户专线
    priority: 5      # 最高优先级
    conditions:
      - type: header
        name: X-User-Level
        value: VIP
    target: vip_cdn

  - name: 普通用户
    priority: 100    # 较低优先级
    conditions: []
    target: public
```

### 2. 条件组合

多个条件是 **AND** 关系，必须全部满足：

```yaml
- name: 北京电信用户
  conditions:
    - type: province
      values: [北京]
    - type: isp
      values: [China Telecom]
  target: beijing_telecom_cdn
```

### 3. 灰度发布

使用百分比分流逐步切换CDN：

```yaml
# 第一阶段：10%流量
- name: 新CDN灰度
  priority: 10
  enabled: true
  conditions:
    - type: percentage
      value: 10
  target: new_cdn

# 第二阶段：改为50%
# 第三阶段：改为100%，禁用旧CDN规则
```

### 4. 热更新

修改 `routing_rules.yaml` 后，配置会在下次请求时自动生效：

```bash
# 修改配置文件
vi routing_rules.yaml

# 无需重启，等待缓存过期（默认5分钟）
# 或者手动重载（如果实现了reload接口）
```

### 5. 调试模式

临时测试特定CDN：

```yaml
# 添加调试规则（最高优先级）
- name: 调试-测试新CDN
  priority: 1
  enabled: true
  conditions:
    - type: query_param
      name: debug_cdn
      value: new
  target: new_cdn
```

使用方式：`http://short.domain.com/abc?debug_cdn=new`

---

## 🔍 故障排查

### 问题1: 分流不生效

**检查：**
```bash
# 1. 查看路由日志
docker-compose logs -f redirect-service | grep RoutingEngine

# 2. 验证配置文件
lua scripts/validate_routing.lua

# 3. 检查规则是否启用
# routing_rules.yaml 中确认 enabled: true

# 4. 检查优先级顺序
# 优先级小的规则先匹配
```

### 问题2: 配置语法错误

**解决：**
```bash
# 1. 使用验证脚本
docker-compose exec redirect-service lua scripts/validate_routing.lua

# 2. 在线验证YAML语法
# https://www.yamllint.com/

# 3. 常见错误：
#    - 缩进必须使用空格（不能用Tab）
#    - 冒号后面必须有空格
#    - 字符串包含特殊字符需要引号
```

### 问题3: CDN不可达

**检查：**
```bash
# 1. 测试CDN连通性
curl -I https://your-cdn.com

# 2. 检查环境变量
docker-compose exec redirect-service env | grep CDN

# 3. 查看降级日志
docker-compose logs redirect-service | grep fallback

# 4. 确认降级链配置
# routing_rules.yaml -> default_routing -> fallback_chain
```

### 问题4: 性能下降

**优化：**
```yaml
# routing_rules.yaml
advanced:
  enable_rule_cache: true      # 启用缓存
  cache_ttl: 300               # 缓存5分钟
  enable_routing_log: false    # 生产环境关闭日志
```

### 问题5: 规则匹配不符合预期

**调试：**
```yaml
# 临时启用路由日志
advanced:
  enable_routing_log: true

# 查看日志输出
docker-compose logs -f redirect-service | grep "匹配规则"
```

---

## 📊 最佳实践

### 1. 优先级规划

```yaml
# 1-10:   关键规则（VIP、测试）
- priority: 5
  name: VIP用户专线

# 11-50:  地理位置规则
- priority: 20
  name: 北方电信用户

# 51-100: 功能性规则
- priority: 60
  name: 图床路径路由

# 101+:   兜底规则
- priority: 999
  name: 默认路由
```

### 2. 规则命名规范

```yaml
# ✅ 推荐：清晰描述性
- name: 北京电信用户-主CDN
- name: 图片资源-图床CDN
- name: 海外用户-海外CDN

# ❌ 避免：模糊命名
- name: 规则1
- name: test
- name: aaa
```

### 3. 测试策略

```yaml
# 方法1：使用 enabled: false 暂停规则
- name: 实验性规则
  enabled: false  # 暂时禁用，不删除

# 方法2：使用 URL参数测试
- name: 测试新CDN
  priority: 1
  conditions:
    - type: query_param
      name: test
      value: new
  target: new_cdn
```

### 4. 降级策略

```yaml
# 配置多级降级
default_routing:
  target: public
  fallback_chain:
    - primary_cdn      # 首选
    - backup_cdn       # 备选
    - public           # 再次备选
    - fallback         # 兜底
```

### 5. 灰度发布流程

```yaml
# 阶段1：10%流量（观察1周）
- name: 新CDN灰度
  enabled: true
  conditions:
    - type: percentage
      value: 10
  target: new_cdn

# 阶段2：改为50%（观察3天）
# 阶段3：改为100%（全量切换）
# 阶段4：禁用旧CDN规则
```

---

## 📖 下一步

- 📚 [完整配置指南](ROUTING_CONFIG_GUIDE.md) - 详细的配置说明和案例
- 🔧 [配置向导](CONFIG_WIZARD.md) - 分步骤配置指导
- 🔑 [API KEY指南](API_KEY_GUIDE.md) - API认证配置

---

## 💬 获取帮助
```bash
# 测试CDN连通性
curl -I https://your-cdn.com

# 查看降级日志
docker-compose logs redirect-service | grep fallback
```

---

## 性能优化建议

### 简单模式优化
- ✅ 适合单一分流规则
- ✅ 性能最优（无额外解析开销）
- ✅ 推荐用于高QPS场景

### 高级模式优化
- ✅ 启用规则缓存：`enable_rule_cache: true`
- ✅ 减少规则数量，合并相似规则
- ✅ 将常用规则设置高优先级
- ✅ 生产环境关闭路由日志：`enable_routing_log: false`

---

## 下一步

- 📖 [完整配置指南](ROUTING_CONFIG_GUIDE.md)
- 🎯 [10种条件类型详解](ROUTING_CONFIG_GUIDE.md#条件类型说明)
- 💡 [7个实战案例](ROUTING_CONFIG_GUIDE.md#实战案例)
- 🔧 [故障排查手册](ROUTING_CONFIG_GUIDE.md#故障排查)

---

## 获取帮助

遇到问题？
1. 查看详细文档：`ROUTING_CONFIG_GUIDE.md`
2. 验证配置：`lua scripts/validate_routing.lua`
3. 查看示例：`routing_rules.yaml` 中的注释
