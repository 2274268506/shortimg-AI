# 短链服务分流配置

## 📖 配置文件

短链服务使用 YAML 配置文件管理所有分流规则：

- **routing_rules.yaml** - 分流规则配置（主配置文件）
- **.env** - CDN节点环境变量（域名、协议、端口）

## ⚡ 快速开始

### 1. 配置CDN节点

编辑 `.env` 文件：

```bash
# 私有网络（内网/开发）
CDN_PRIVATE_DOMAIN=localhost
CDN_PRIVATE_PROTOCOL=http

# 公共网络（生产默认）
CDN_PUBLIC_DOMAIN=cdn.example.com
CDN_PUBLIC_PROTOCOL=https
```

### 2. 配置分流规则

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

  # 外网用户
  - name: 公网路由
    priority: 100
    enabled: true
    conditions: []
    target: public
```

### 3. 验证和应用

```bash
# 验证配置
lua scripts/validate_routing.lua

# 重启服务
docker-compose restart redirect-service
```

## 📚 文档

- **[快速入门](ROUTING_QUICK_START.md)** - 5分钟快速配置指南
- **[完整指南](ROUTING_CONFIG_GUIDE.md)** - 详细的配置说明和示例
- **[配置向导](CONFIG_WIZARD.md)** - 分步骤配置向导

## 🎯 支持的分流条件

| 条件类型 | 说明 | 示例 |
|---------|------|------|
| ip_range | IP地址段 | 192.168.0.0/16 |
| province | 省份 | 北京、上海 |
| isp | 运营商 | 电信、联通 |
| country | 国家 | CN、US |
| asn | 自治系统号 | 4134 |
| path_prefix | URL路径 | /img/, /api/ |
| time_range | 时间段 | 2-6点 |
| percentage | 百分比 | 20% |
| header | HTTP头 | X-User-Level: VIP |
| query_param | URL参数 | ?cdn=new |

## 💡 典型场景

### 内外网分流

```yaml
- name: 内网
  conditions:
    - type: ip_range
      ranges: [192.168.0.0/16]
  target: private

- name: 外网
  conditions: []
  target: public
```

### 运营商分流

```yaml
- name: 电信用户
  conditions:
    - type: isp
      values: [China Telecom]
  target: telecom_cdn

- name: 联通用户
  conditions:
    - type: isp
      values: [China Unicom]
  target: unicom_cdn
```

### 海外分流

```yaml
- name: 海外用户
  conditions:
    - type: country
      operator: not_equals
      value: CN
  target: overseas_cdn
```

### 灰度发布

```yaml
- name: 新CDN灰度
  conditions:
    - type: percentage
      value: 20  # 20%流量
  target: new_cdn
```

## 🔧 配置验证

```bash
# 验证语法和逻辑
lua scripts/validate_routing.lua

# 完整配置检查
./scripts/validate_config.sh
```

## 🔄 热更新

修改 `routing_rules.yaml` 后会自动生效（缓存5分钟）：

```bash
# 修改配置
vi routing_rules.yaml

# 无需重启，等待生效
# 或查看日志确认
docker-compose logs -f redirect-service | grep RoutingEngine
```

## 📊 最佳实践

1. **优先级规划**
   - 1-10: 关键规则（VIP、测试）
   - 11-50: 地理位置规则
   - 51-100: 功能性规则
   - 101+: 兜底规则

2. **规则命名**
   - ✅ 使用清晰描述性名称
   - ❌ 避免模糊命名（如"规则1"）

3. **测试策略**
   - 使用 `enabled: false` 暂停规则
   - 使用 URL参数测试新CDN

4. **降级策略**
   - 配置多级 fallback_chain
   - 确保至少2个可用CDN

## 🐛 故障排查

### 分流不生效

```bash
# 查看路由日志
docker-compose logs -f redirect-service | grep RoutingEngine

# 检查规则是否启用
grep "enabled: true" routing_rules.yaml

# 验证配置
lua scripts/validate_routing.lua
```

### 配置语法错误

```bash
# 使用验证脚本
lua scripts/validate_routing.lua

# 在线验证
# https://www.yamllint.com/
```

### CDN不可达

```bash
# 测试连通性
curl -I https://your-cdn.com

# 查看降级日志
docker-compose logs redirect-service | grep fallback
```

## 📞 获取帮助

- 查看 [ROUTING_QUICK_START.md](ROUTING_QUICK_START.md)
- 查看 [ROUTING_CONFIG_GUIDE.md](ROUTING_CONFIG_GUIDE.md)
- 运行验证脚本：`lua scripts/validate_routing.lua`
