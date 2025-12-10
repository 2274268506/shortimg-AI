# 服务类型分流路由配置指南

## 📋 概述

本系统支持根据**服务类型** (`service_type`) 和 **GeoIP信息** 对不同类型的短链进行智能分流，将流量路由到不同的服务器群组。

## 🎯 支持的服务类型

| 服务类型 | 前缀 | 说明 | 示例 |
|---------|------|------|------|
| `general` | 无 | 通用短链，重定向到任意URL | `abc123` |
| `imagebed` | `img-` | 图床短链，访问图片资源 | `img-xyz789` |
| `file` | `file-` | 文件短链，访问文件下载 | `file-doc123` |
| `video` | `vid-` | 视频短链，访问视频流 | `vid-movie456` |

## 🏗️ 服务器群组架构

### 1. 图床服务器群组
- **联通**: `imagebed_unicom` → `img-unicom.example.com`
- **移动**: `imagebed_mobile` → `img-mobile.example.com`
- **电信**: `imagebed_telecom` → `img-telecom.example.com`
- **海外**: `imagebed_overseas` → `img-overseas.example.com`
- **默认**: `imagebed_default` → `img-cdn.example.com`

### 2. 文件服务器群组
- **联通**: `file_unicom` → `file-unicom.example.com`
- **移动**: `file_mobile` → `file-mobile.example.com`
- **电信**: `file_telecom` → `file-telecom.example.com`
- **海外**: `file_overseas` → `file-overseas.example.com`
- **默认**: `file_default` → `file-cdn.example.com`

### 3. 视频服务器群组
- **联通**: `video_unicom` → `video-unicom.example.com`
- **移动**: `video_mobile` → `video-mobile.example.com`
- **电信**: `video_telecom` → `video-telecom.example.com`
- **海外**: `video_overseas` → `video-overseas.example.com`
- **默认**: `video_default` → `video-cdn.example.com`

### 4. 通用服务器群组
- **联通**: `general_unicom` → `cdn-unicom.example.com`
- **移动**: `general_mobile` → `cdn-mobile.example.com`
- **电信**: `general_telecom` → `cdn-telecom.example.com`
- **海外**: `general_overseas` → `cdn-overseas.example.com`
- **默认**: `general_default` → `cdn.example.com`

## 🔄 路由规则逻辑

### 优先级顺序

```
1. 内网IP (priority 10)
   └─> private CDN（所有类型统一）

2. 图床类型 (priority 20-24)
   ├─> 电信用户 → imagebed_telecom
   ├─> 联通用户 → imagebed_unicom
   ├─> 移动用户 → imagebed_mobile
   ├─> 海外用户 → imagebed_overseas
   └─> 其他用户 → imagebed_default

3. 文件类型 (priority 30-34)
   ├─> 电信用户 → file_telecom
   ├─> 联通用户 → file_unicom
   ├─> 移动用户 → file_mobile
   ├─> 海外用户 → file_overseas
   └─> 其他用户 → file_default

4. 视频类型 (priority 40-44)
   ├─> 电信用户 → video_telecom
   ├─> 联通用户 → video_unicom
   ├─> 移动用户 → video_mobile
   ├─> 海外用户 → video_overseas
   └─> 其他用户 → video_default

5. 通用类型 (priority 50-54)
   ├─> 电信用户 → general_telecom
   ├─> 联通用户 → general_unicom
   ├─> 移动用户 → general_mobile
   ├─> 海外用户 → general_overseas
   └─> 其他用户 → general_default
```

### 规则匹配示例

#### 示例 1: 北京联通用户访问图床短链
```
短链: img-abc123
用户: 北京 + 联通
匹配规则: "图床_联通" (priority 21)
目标节点: imagebed_unicom
最终URL: https://img-unicom.example.com/uploads/abc123.jpg
```

#### 示例 2: 上海电信用户访问文件短链
```
短链: file-doc456
用户: 上海 + 电信
匹配规则: "文件_电信" (priority 30)
目标节点: file_telecom
最终URL: https://file-telecom.example.com/files/doc456.pdf
```

#### 示例 3: 美国用户访问视频短链
```
短链: vid-movie789
用户: 美国 (非CN)
匹配规则: "视频_海外" (priority 43)
目标节点: video_overseas
最终URL: https://video-overseas.example.com/videos/movie789.mp4
```

## ⚙️ 环境变量配置

### .env 文件示例

```bash
# 图床服务器群组
CDN_IMAGEBED_UNICOM_DOMAIN=img-unicom.yourdomain.com
CDN_IMAGEBED_MOBILE_DOMAIN=img-mobile.yourdomain.com
CDN_IMAGEBED_TELECOM_DOMAIN=img-telecom.yourdomain.com
CDN_IMAGEBED_OVERSEAS_DOMAIN=img-overseas.yourdomain.com
CDN_IMAGEBED_DEFAULT_DOMAIN=img-cdn.yourdomain.com

# 文件服务器群组
CDN_FILE_UNICOM_DOMAIN=file-unicom.yourdomain.com
CDN_FILE_MOBILE_DOMAIN=file-mobile.yourdomain.com
CDN_FILE_TELECOM_DOMAIN=file-telecom.yourdomain.com
CDN_FILE_OVERSEAS_DOMAIN=file-overseas.yourdomain.com
CDN_FILE_DEFAULT_DOMAIN=file-cdn.yourdomain.com

# 视频服务器群组
CDN_VIDEO_UNICOM_DOMAIN=video-unicom.yourdomain.com
CDN_VIDEO_MOBILE_DOMAIN=video-mobile.yourdomain.com
CDN_VIDEO_TELECOM_DOMAIN=video-telecom.yourdomain.com
CDN_VIDEO_OVERSEAS_DOMAIN=video-overseas.yourdomain.com
CDN_VIDEO_DEFAULT_DOMAIN=video-cdn.yourdomain.com

# 通用服务器群组
CDN_GENERAL_UNICOM_DOMAIN=cdn-unicom.yourdomain.com
CDN_GENERAL_MOBILE_DOMAIN=cdn-mobile.yourdomain.com
CDN_GENERAL_TELECOM_DOMAIN=cdn-telecom.yourdomain.com
CDN_GENERAL_OVERSEAS_DOMAIN=cdn-overseas.yourdomain.com
CDN_GENERAL_DEFAULT_DOMAIN=cdn.yourdomain.com

# 协议设置（可选，默认https）
CDN_IMAGEBED_UNICOM_PROTOCOL=https
CDN_FILE_UNICOM_PROTOCOL=https
CDN_VIDEO_UNICOM_PROTOCOL=https
CDN_GENERAL_UNICOM_PROTOCOL=https
```

## 🧪 测试验证

### 1. 测试图床短链

```bash
# 创建图床短链
curl -X POST http://localhost/api/v2/imagebed \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "service_type": "imagebed",
    "targets": [{"path": "/uploads/test.jpg", "weight": 1}],
    "strategy": "geo"
  }'

# 访问短链（从不同运营商测试）
curl -L http://localhost/{short_code}
```

### 2. 测试文件短链

```bash
# 创建文件短链
curl -X POST http://localhost/api/v2/imagebed \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "service_type": "file",
    "targets": [{"path": "/files/document.pdf", "weight": 1}],
    "strategy": "geo"
  }'
```

### 3. 测试视频短链

```bash
# 创建视频短链
curl -X POST http://localhost/api/v2/imagebed \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "service_type": "video",
    "targets": [{"path": "/videos/movie.mp4", "weight": 1}],
    "strategy": "geo"
  }'
```

## 📊 降级策略

当目标CDN不可用时，按以下顺序降级：

### 图床类型降级链
```
imagebed_unicom/mobile/telecom/overseas
  ↓ (不可用)
imagebed_default
  ↓ (不可用)
general_default
  ↓ (不可用)
backup
```

### 文件类型降级链
```
file_unicom/mobile/telecom/overseas
  ↓ (不可用)
file_default
  ↓ (不可用)
general_default
  ↓ (不可用)
backup
```

### 视频类型降级链
```
video_unicom/mobile/telecom/overseas
  ↓ (不可用)
video_default
  ↓ (不可用)
general_default
  ↓ (不可用)
backup
```

## 🔧 自定义配置

### 修改路由规则

编辑 `routing_rules.yaml` 文件：

```yaml
routing_rules:
  # 添加自定义规则
  - name: VIP用户专属图床
    priority: 15  # 高优先级
    enabled: true
    conditions:
      - type: service_type
        value: imagebed
      - type: header
        name: X-User-Level
        value: VIP
    target: imagebed_vip  # 需要在 cdn_nodes 中定义
```

### 临时禁用规则

```yaml
  - name: 图床_电信
    priority: 20
    enabled: false  # 设置为 false 禁用
    conditions:
      - type: service_type
        value: imagebed
      - type: isp
        values: [China Telecom]
    target: imagebed_telecom
```

## 📝 日志查看

```bash
# 查看路由日志
docker exec short-link-openresty tail -f /usr/local/openresty/nginx/logs/access.log | grep -E "imagebed|file|video"

# 查看错误日志
docker exec short-link-openresty tail -f /usr/local/openresty/nginx/logs/error.log
```

## 🚀 性能优化建议

1. **启用规则缓存**：配置文件默认5分钟缓存
2. **关闭路由日志**：生产环境设置 `enable_routing_log: false`
3. **使用权重策略**：对于不需要地理路由的场景，使用 `weight` 策略
4. **合理设置降级链**：确保至少有2-3个备选节点

## ⚠️ 注意事项

1. 修改 `routing_rules.yaml` 后无需重启服务（5分钟内自动生效）
2. 修改 `.env` 文件后需要重启容器
3. 确保所有CDN域名解析正确
4. 定期检查各节点健康状态
5. 海外节点建议使用境外CDN服务商

## 📚 相关文档

- [路由配置快速入门](ROUTING_QUICK_START.md)
- [完整配置指南](ROUTING_CONFIG_GUIDE.md)
- [GeoIP路由说明](GEOIP_ROUTING.md)
