# TC-GO 图床短链功能快速参考

## ✅ 适配状态

**检查时间**: 2025-12-06
**测试结果**: ✅ 所有测试通过（7/7）

---

## 📋 已完成的修复

### 1. 后端环境变量配置
**文件**: `backend/.env`

```bash
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://localhost
SHORT_LINK_EXPIRE=0
```

### 2. 后端代码去硬编码
**文件**: `backend/controllers/image_controller.go`

✅ GetImages 函数 - 使用 `cfg.ShortLinkBaseURL`
✅ GetImage 函数 - 使用 `cfg.ShortLinkBaseURL`

---

## 🚀 使用指南

### 创建带短链的图片

#### 方式1: 相册级别启用

```bash
# 1. 创建启用短链的相册
POST /api/albums
{
  "name": "我的相册",
  "enableShortLink": true  # ← 关键
}

# 2. 上传图片（自动生成短链）
POST /api/images/upload
- file: 图片文件
- albumId: 相册ID
```

#### 方式2: 单次上传启用

```bash
POST /api/images/upload
- file: 图片文件
- albumId: 相册ID
- enableShortLink: true  # ← 关键（覆盖相册设置）
```

### 返回数据示例

```json
{
  "data": {
    "id": 123,
    "url": "/uploads/abc123.jpg",
    "shortLinkCode": "img-woNn4gWn4VhY",
    "shortLinkUrl": "http://localhost/img-woNn4gWn4VhY"
  }
}
```

### 访问短链

```bash
# 直接访问短链
http://localhost/img-woNn4gWn4VhY

# 自动302重定向到
http://localhost:8080/uploads/abc123.jpg
```

---

## 🌍 GeoIP分流规则

### 私有IP → localhost

| IP范围 | 目标 |
|--------|------|
| 10.0.0.0/8 | http://localhost |
| 172.16.0.0/12 | http://localhost |
| 192.168.0.0/16 | http://localhost |
| 127.0.0.0/8 | http://localhost |

### 公网IP → 生产CDN

| IP类型 | 目标 |
|--------|------|
| 其他所有IP | https://dxy.oxvxo.net:18443 |

**注意**: GeoIP分流仅对"仅路径"模式的target生效，完整URL模式不走CDN分流。

---

## 🔧 短链服务API

### 创建图床短链

```bash
POST http://localhost/api/imagebed/create
Content-Type: application/json

{
  "image_url": "http://localhost:8080/uploads/test.jpg",
  "custom_code": "my-pic",  # 可选，自定义短链码
  "expire_time": 2592000    # 可选，过期时间（秒）
}
```

**响应**:
```json
{
  "success": true,
  "data": {
    "code": "img-woNn4gWn4VhY",
    "short_url": "http://localhost/img-woNn4gWn4VhY",
    "long_url": "http://localhost:8080/uploads/test.jpg",
    "created_at": 1765033543
  }
}
```

### 批量创建

```bash
POST http://localhost/api/imagebed/batch
Content-Type: application/json

{
  "images": [
    {"image_url": "http://..."},
    {"image_url": "http://..."}
  ],
  "expire_time": 0
}
```

### 查询短链信息

```bash
GET http://localhost/api/imagebed/info/{code}
```

**响应**:
```json
{
  "success": true,
  "data": {
    "code": "img-woNn4gWn4VhY",
    "long_url": "http://localhost:8080/uploads/test.jpg",
    "visit_count": 5,
    "created_at": "2025-12-06 23:00:00"
  }
}
```

---

## 🗄️ 数据库结构

### short_links 表

```sql
CREATE TABLE short_links (
  id INT PRIMARY KEY AUTO_INCREMENT,
  short_code VARCHAR(32) UNIQUE,      -- 短链码
  targets JSON,                        -- 目标URL数组
  strategy VARCHAR(20),                -- 分流策略
  service_type VARCHAR(50),            -- 服务类型（imagebed）
  visit_count INT DEFAULT 0,           -- 访问次数
  status VARCHAR(20) DEFAULT 'active', -- 状态
  expires_at DATETIME,                 -- 过期时间
  created_at DATETIME,
  updated_at DATETIME
);
```

### images 表（图床）

```sql
ALTER TABLE images ADD COLUMN short_link_code VARCHAR(32);
CREATE INDEX idx_short_link_code ON images(short_link_code);
```

---

## 📊 统计查询

### 查询图床短链统计

```bash
GET http://localhost/api/imagebed/stats
```

**响应**:
```json
{
  "total": 1234,           // 总短链数
  "today": 56,             // 今日新增
  "total_clicks": 98765,   // 总访问数
  "top_images": [...]      // TOP10热门图片
}
```

---

## ⚙️ 配置文件

### 开发环境

**后端** (`backend/.env`):
```bash
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://localhost
SHORT_LINK_EXPIRE=0
```

**短链服务** (`redirect-service/.env`):
```bash
REDIRECT_DOMAIN=localhost
REDIRECT_PROTOCOL=http
CDN_PRIVATE_DOMAIN=localhost
CDN_PUBLIC_DOMAIN=dxy.oxvxo.net
CDN_PUBLIC_PORT=18443
```

### 生产环境

**后端**:
```bash
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=https://s.yourdomain.com
SHORT_LINK_EXPIRE=0
```

**短链服务**:
```bash
REDIRECT_DOMAIN=s.yourdomain.com
REDIRECT_PROTOCOL=https
CDN_PRIVATE_DOMAIN=localhost
CDN_PUBLIC_DOMAIN=cdn.yourdomain.com
CDN_PUBLIC_PORT=443
```

---

## 🧪 测试命令

### 运行集成测试

```powershell
cd C:\Users\DXY\Documents\TC-GO
.\test-integration.ps1
```

### 手动测试短链创建

```powershell
$body = @{image_url="http://localhost:8080/uploads/test.jpg"} | ConvertTo-Json
curl.exe -X POST http://localhost/api/imagebed/create -H "Content-Type: application/json" -d $body
```

### 测试重定向

```powershell
curl.exe -I http://localhost/img-woNn4gWn4VhY
```

---

## ❓ 常见问题

### Q: 上传图片时没有生成短链？

**A**: 检查以下配置：
1. `backend/.env` 中 `SHORT_LINK_ENABLED=true`
2. 相册设置了 `enableShortLink=true` 或上传时指定 `enableShortLink=true`
3. 后端已重启加载新配置

### Q: 短链URL显示为空？

**A**: 可能原因：
1. 图片列表API返回前未拼接短链URL
2. `SHORT_LINK_BASE_URL` 未配置
3. 后端代码未使用配置（已修复）

### Q: 访问短链显示404？

**A**: 检查：
1. 短链服务是否运行（`docker ps`）
2. 短链码是否正确
3. MySQL中是否有该记录

### Q: GeoIP分流不生效？

**A**:
1. GeoIP分流仅对"仅路径"模式生效
2. 完整URL（`{url: "http://..."}`）不走CDN分流
3. 需要创建 `{path: "/uploads/xxx.jpg"}` 格式的target

---

## 📝 开发日志

### 2025-12-06
- ✅ 修复后端环境变量缺失
- ✅ 去除硬编码的短链域名
- ✅ 实现GeoIP智能分流
- ✅ 完成集成测试（7/7通过）
- ✅ 创建文档和测试脚本

---

## 🔗 相关文档

- [集成检查报告](./INTEGRATION_CHECK.md) - 详细的适配检查
- [GeoIP分流实现](./redirect-service/GEOIP_ROUTING.md) - 分流逻辑说明
- [测试脚本](./test-integration.ps1) - 自动化测试

---

**维护者**: GitHub Copilot
**最后更新**: 2025-12-06
