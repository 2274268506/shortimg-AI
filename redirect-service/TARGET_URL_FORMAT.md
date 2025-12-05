# 目标URL配置格式说明

## 概述

短链重定向服务支持两种目标URL配置方式，推荐使用**方式2（CDN标识 + 路径）**以获得更好的灵活性和可维护性。

---

## 方式1：完整URL（向后兼容）

### 数据格式

```json
{
  "targets": [
    {
      "url": "https://cdn-north.example.com/uploads/image.jpg",
      "region": "cn-north",
      "isp": "telecom",
      "weight": 5
    }
  ]
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `url` | string | ✅ | 完整的目标URL（包含协议和域名） |
| `region` | string | ❌ | 地理区域（用于geo策略） |
| `isp` | string | ❌ | 运营商（用于ISP策略） |
| `weight` | number | ❌ | 权重（用于权重策略，默认1） |

### 优点
- ✅ 简单直观
- ✅ 向后兼容旧数据

### 缺点
- ❌ 域名硬编码，难以修改
- ❌ CDN域名变更需要更新数据库
- ❌ 不支持多环境配置

---

## 方式2：CDN标识 + 路径（推荐）

### 数据格式

```json
{
  "targets": [
    {
      "cdn": "north_telecom",
      "path": "/uploads/2024/12/image.jpg",
      "region": "cn-north",
      "isp": "telecom",
      "weight": 5
    }
  ]
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `cdn` | string | ✅ | CDN标识符（对应config.lua中的配置） |
| `path` | string | ✅ | 资源路径（以/开头） |
| `region` | string | ❌ | 地理区域（用于geo策略） |
| `isp` | string | ❌ | 运营商（用于ISP策略） |
| `weight` | number | ❌ | 权重（用于权重策略，默认1） |
| `ip_ranges` | array | ❌ | IP段列表（用于IP策略） |

### CDN标识符列表

系统预定义的CDN标识符（在 `conf/config.lua` 中配置）：

| CDN标识 | 环境变量 | 默认域名 | 用途 |
|---------|----------|----------|------|
| `north_telecom` | `CDN_NORTH_TELECOM_DOMAIN` | `cdn-north.example.com` | 北方电信CDN |
| `south_unicom` | `CDN_SOUTH_UNICOM_DOMAIN` | `cdn-south.example.com` | 南方联通CDN |
| `overseas` | `CDN_OVERSEAS_DOMAIN` | `cdn-overseas.example.com` | 海外CDN |
| `tc_go_primary` | `TC_GO_PRIMARY_DOMAIN` | `imagebed.example.com` | TC-GO主服务器 |
| `tc_go_backup` | `TC_GO_BACKUP_DOMAIN` | `imagebed-backup.example.com` | TC-GO备份服务器 |
| `fallback` | `CDN_FALLBACK_DOMAIN` | `cdn-fallback.example.com` | 降级服务器 |

### URL生成过程

```
输入: {
  "cdn": "north_telecom",
  "path": "/uploads/2024/12/image.jpg"
}

查找配置:
cdn_servers.north_telecom = {
  domain: "cdn-bj.example.com",
  protocol: "https"
}

生成URL:
https://cdn-bj.example.com/uploads/2024/12/image.jpg
```

### 优点
- ✅ 域名在配置文件中统一管理
- ✅ 可通过环境变量灵活配置
- ✅ 支持多环境（开发/测试/生产）
- ✅ CDN域名变更只需修改配置文件
- ✅ 便于CDN提供商切换

### 缺点
- ❌ 需要预先定义CDN标识符

---

## 完整示例

### 示例1：图片多CDN分发

```json
{
  "short_code": "img-photo-001",
  "targets": [
    {
      "cdn": "north_telecom",
      "path": "/uploads/2024/12/05/photo.jpg",
      "region": "cn-north",
      "isp": "telecom",
      "weight": 5
    },
    {
      "cdn": "south_unicom",
      "path": "/uploads/2024/12/05/photo.jpg",
      "region": "cn-south",
      "isp": "unicom",
      "weight": 3
    },
    {
      "cdn": "overseas",
      "path": "/uploads/2024/12/05/photo.jpg",
      "region": "overseas",
      "weight": 2
    }
  ],
  "strategy": "geo+weight",
  "security_config": {
    "referer_whitelist": ["*.example.com", "localhost"],
    "token_secret": "your-secret-key"
  }
}
```

**访问流程**：
```
用户访问: https://s.example.com/r/img-photo-001

北京电信用户 → https://cdn-bj.example.com/uploads/2024/12/05/photo.jpg
广州联通用户 → https://cdn-gz.example.com/uploads/2024/12/05/photo.jpg
美国用户     → https://cdn-us.example.com/uploads/2024/12/05/photo.jpg
```

### 示例2：TC-GO图床集成

```json
{
  "short_code": "tcgo-uuid-abc123",
  "targets": [
    {
      "cdn": "tc_go_primary",
      "path": "/uploads/albums/travel/IMG_001.jpg",
      "weight": 5
    },
    {
      "cdn": "tc_go_backup",
      "path": "/uploads/albums/travel/IMG_001.jpg",
      "weight": 3
    }
  ],
  "strategy": "weight",
  "security_config": {
    "referer_whitelist": ["*.yourdomain.com"],
    "rate_limit": {
      "enabled": true,
      "max_requests": 100,
      "window": 60
    }
  }
}
```

### 示例3：混合使用（兼容模式）

```json
{
  "short_code": "mixed-example",
  "targets": [
    {
      "cdn": "north_telecom",
      "path": "/uploads/image.jpg",
      "region": "cn-north",
      "weight": 5
    },
    {
      "url": "https://legacy-cdn.example.com/uploads/image.jpg",
      "region": "cn-south",
      "weight": 3
    }
  ],
  "strategy": "geo+weight"
}
```

**说明**：系统会自动识别并处理两种格式，优先使用CDN标识方式。

---

## 数据库操作

### 插入新短链

```sql
INSERT INTO short_links (short_code, targets, strategy, security_config) VALUES (
  'img-abc123',
  '[
    {
      "cdn": "north_telecom",
      "path": "/uploads/2024/12/image.jpg",
      "region": "cn-north",
      "isp": "telecom",
      "weight": 5
    },
    {
      "cdn": "south_unicom",
      "path": "/uploads/2024/12/image.jpg",
      "region": "cn-south",
      "isp": "unicom",
      "weight": 3
    }
  ]',
  'geo+weight',
  '{
    "referer_whitelist": ["*.example.com"]
  }'
);
```

### 更新目标列表

```sql
UPDATE short_links
SET targets = '[
  {
    "cdn": "north_telecom",
    "path": "/uploads/2024/12/new-image.jpg",
    "region": "cn-north",
    "weight": 5
  }
]'
WHERE short_code = 'img-abc123';
```

### 查询短链配置

```sql
SELECT
  short_code,
  JSON_EXTRACT(targets, '$[0].cdn') as cdn,
  JSON_EXTRACT(targets, '$[0].path') as path,
  strategy
FROM short_links
WHERE short_code = 'img-abc123';
```

---

## API调用示例

### 创建短链（方式2）

```bash
curl -X POST http://localhost/api/v1/links \
  -H "Content-Type: application/json" \
  -d '{
    "short_code": "img-test",
    "targets": [
      {
        "cdn": "north_telecom",
        "path": "/uploads/test.jpg",
        "region": "cn-north",
        "weight": 5
      }
    ],
    "strategy": "weight"
  }'
```

### 更新短链

```bash
curl -X PUT http://localhost/api/v1/links/img-test \
  -H "Content-Type: application/json" \
  -d '{
    "targets": [
      {
        "cdn": "south_unicom",
        "path": "/uploads/test.jpg",
        "region": "cn-south",
        "weight": 3
      }
    ]
  }'
```

---

## 配置域名

在 `.env` 文件中配置CDN域名：

```bash
# 北方电信CDN
CDN_NORTH_TELECOM_DOMAIN=cdn-bj.yourdomain.com
CDN_NORTH_TELECOM_PROTOCOL=https

# 南方联通CDN
CDN_SOUTH_UNICOM_DOMAIN=cdn-gz.yourdomain.com
CDN_SOUTH_UNICOM_PROTOCOL=https

# 海外CDN
CDN_OVERSEAS_DOMAIN=cdn-us.yourdomain.com
CDN_OVERSEAS_PROTOCOL=https

# TC-GO图床
TC_GO_PRIMARY_DOMAIN=img.yourdomain.com
TC_GO_PRIMARY_PROTOCOL=https
```

---

## 迁移指南

### 从方式1迁移到方式2

**旧数据**：
```json
{
  "targets": [
    {"url": "https://cdn-bj.example.com/uploads/image.jpg", "weight": 5}
  ]
}
```

**新数据**：
```json
{
  "targets": [
    {
      "cdn": "north_telecom",
      "path": "/uploads/image.jpg",
      "weight": 5
    }
  ]
}
```

**迁移SQL**：
```sql
-- 需要根据实际URL手动转换
UPDATE short_links
SET targets = JSON_REPLACE(
  targets,
  '$[0]',
  JSON_OBJECT(
    'cdn', 'north_telecom',
    'path', '/uploads/image.jpg',
    'weight', JSON_EXTRACT(targets, '$[0].weight')
  )
)
WHERE short_code = 'your-short-code';
```

---

## 最佳实践

1. **新项目使用方式2**：获得最大灵活性
2. **域名统一管理**：所有CDN域名在 `.env` 中配置
3. **环境隔离**：开发、测试、生产使用不同的域名配置
4. **安全配置**：启用Referer白名单和限流
5. **监控日志**：定期检查访问日志和错误日志
6. **降级策略**：配置备用服务器应对故障

---

## 常见问题

### Q1: 可以同时使用两种方式吗？
A: 可以。系统会自动识别并处理，优先使用CDN标识方式。

### Q2: 如何添加新的CDN标识？
A: 在 `conf/config.lua` 的 `cdn_servers` 中添加新配置，并在 `.env` 中设置对应的环境变量。

### Q3: 域名变更后需要重启吗？
A: 建议重启，或调用热更新API：`POST /api/reload`

### Q4: 路径必须以/开头吗？
A: 不是必须的，系统会自动添加。但建议统一使用 `/` 开头的绝对路径。

### Q5: 支持通配符路径吗？
A: 目前不支持。每个短链对应固定的资源路径。

---

## 相关文档

- [配置指南](CONFIG_GUIDE.md) - 详细的配置说明
- [快速开始](QUICKSTART.md) - 实际使用示例
- [部署指南](DEPLOYMENT.md) - 部署步骤
- [API文档](README.md#api文档) - API接口说明
