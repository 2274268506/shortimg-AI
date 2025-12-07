# 短链服务管理 API 文档

## 📋 目录

- [统计查询 API](#统计查询-api)
- [批量管理 API](#批量管理-api)
- [数据清理 API](#数据清理-api)
- [错误码说明](#错误码说明)

---

## 统计查询 API

### 1. 获取总体统计

获取所有短链的总体统计信息，按服务类型和状态分组。

**端点**: `GET /api/stats/overview`

**响应示例**:
```json
{
  "success": true,
  "data": {
    "total": 1500,
    "active": 1200,
    "paused": 200,
    "deleted": 100,
    "by_service": {
      "imagebed": {
        "total": 1000,
        "active": 850,
        "paused": 100,
        "deleted": 50
      },
      "general": {
        "total": 500,
        "active": 350,
        "paused": 100,
        "deleted": 50
      }
    },
    "today_visits": 5000,
    "total_visits": 150000,
    "expiring_soon": 30,
    "expired": 10
  },
  "timestamp": 1701849600
}
```

**字段说明**:
- `total`: 短链总数
- `active`: 活跃短链数量
- `paused`: 暂停短链数量
- `deleted`: 已删除短链数量
- `by_service`: 按服务类型分组的统计
- `today_visits`: 今日访问量
- `total_visits`: 总访问量
- `expiring_soon`: 7天内即将过期的短链数量
- `expired`: 已过期但未清理的短链数量

---

### 2. 获取服务类型统计

获取特定服务类型的详细统计信息。

**端点**: `GET /api/stats/service/{service_type}`

**路径参数**:
- `service_type`: 服务类型 (imagebed, general, custom)

**响应示例**:
```json
{
  "success": true,
  "data": {
    "total": 1000,
    "active": 850,
    "paused": 100,
    "deleted": 50,
    "total_visits": 100000,
    "avg_visits": 100.5,
    "today_new": 25,
    "top_links": [
      {
        "short_code": "img-popular123",
        "visit_count": 5000,
        "created_at": "2024-12-01 10:00:00"
      }
    ],
    "trend_7days": [
      {
        "date": "2024-12-06",
        "count": 30
      },
      {
        "date": "2024-12-05",
        "count": 25
      }
    ]
  },
  "timestamp": 1701849600
}
```

---

### 3. 获取访问日志统计

获取访问日志的统计数据，支持全局或特定短链。

**端点**: `GET /api/stats/access`

**查询参数**:
- `short_code` (可选): 短链码，不提供则返回全局统计
- `days` (可选): 统计天数，默认7天，最多90天

**请求示例**:
```bash
# 全局统计（最近7天）
GET /api/stats/access?days=7

# 特定短链统计
GET /api/stats/access?short_code=img-abc123&days=30
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "short_code": "img-abc123",
    "days": 7,
    "total_visits": 1000,
    "unique_visitors": 500,
    "daily": [
      {
        "date": "2024-12-06",
        "visits": 150,
        "unique_visitors": 80
      }
    ],
    "devices": [
      {
        "device_type": "mobile",
        "count": 600
      },
      {
        "device_type": "desktop",
        "count": 400
      }
    ],
    "regions": [
      {
        "country": "中国",
        "province": "广东",
        "city": "深圳",
        "count": 300
      }
    ]
  },
  "timestamp": 1701849600
}
```

---

## 批量管理 API

### 1. 批量更新状态

批量更新短链的状态。

**端点**: `PUT /api/admin/batch/status`

**请求体**:
```json
{
  "codes": ["code1", "code2", "code3"],
  "status": "paused"
}
```

**参数说明**:
- `codes`: 短链码数组
- `status`: 目标状态 (active, paused, deleted)

**响应示例**:
```json
{
  "success": true,
  "data": {
    "total": 3,
    "success": 3,
    "failed": 0,
    "message": "成功更新 3 条短链状态"
  }
}
```

---

### 2. 批量删除短链

批量删除短链，支持软删除和永久删除。

**端点**: `POST /api/admin/batch/delete`

**请求体**:
```json
{
  "codes": ["code1", "code2", "code3"],
  "permanent": false
}
```

**参数说明**:
- `codes`: 短链码数组（最多100个）
- `permanent`: 是否永久删除（默认false，即软删除）

**响应示例**:
```json
{
  "success": true,
  "data": {
    "total": 3,
    "success": 3,
    "failed": 0,
    "permanent": false,
    "message": "成功删除 3 条短链"
  }
}
```

---

### 3. 批量更新过期时间

批量更新短链的过期时间。

**端点**: `PUT /api/admin/batch/expire`

**请求体**:
```json
{
  "codes": ["code1", "code2", "code3"],
  "expire_time": 86400
}
```

**参数说明**:
- `codes`: 短链码数组
- `expire_time`: 过期时间（秒），为null或0表示永不过期

**响应示例**:
```json
{
  "success": true,
  "data": {
    "total": 3,
    "success": 3,
    "failed": 0,
    "message": "成功更新 3 条短链过期时间"
  }
}
```

---

### 4. 查询短链列表

分页查询短链列表，支持筛选和搜索。

**端点**: `GET /api/admin/links`

**查询参数**:
- `page` (可选): 页码，默认1
- `page_size` (可选): 每页数量，默认20，最大100
- `service_type` (可选): 服务类型筛选
- `status` (可选): 状态筛选
- `search` (可选): 搜索短链码（模糊匹配）

**请求示例**:
```bash
GET /api/admin/links?page=1&page_size=20&service_type=imagebed&status=active&search=img-
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "total": 1000,
    "page": 1,
    "page_size": 20,
    "total_pages": 50,
    "links": [
      {
        "short_code": "img-abc123",
        "service_type": "imagebed",
        "status": "active",
        "visit_count": 100,
        "created_at": "2024-12-01 10:00:00",
        "updated_at": "2024-12-06 10:00:00",
        "expires_at": null
      }
    ]
  }
}
```

---

## 数据清理 API

### 1. 清理过期短链

自动清理所有已过期的短链。

**端点**: `POST /api/admin/cleanup/expired`

**响应示例**:
```json
{
  "success": true,
  "data": {
    "deleted_count": 10,
    "message": "成功删除 10 条过期短链"
  }
}
```

---

### 2. 清理访问日志

清理指定天数之前的访问日志。

**端点**: `POST /api/admin/cleanup/logs`

**查询参数**:
- `days` (可选): 保留天数，默认90天，最少7天

**请求示例**:
```bash
POST /api/admin/cleanup/logs?days=30
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "deleted_count": 50000,
    "days_kept": 30,
    "message": "成功清理 50000 条访问日志"
  }
}
```

---

## 错误码说明

所有API的错误响应格式统一如下：

```json
{
  "success": false,
  "error": {
    "code": 1001,
    "message": "缺少必需参数: codes",
    "type": "MISSING_PARAMETER"
  },
  "timestamp": 1701849600
}
```

### 错误码列表

#### 通用错误 (1000-1099)
- `1000` INVALID_REQUEST - 无效的请求
- `1001` MISSING_PARAMETER - 缺少必需参数
- `1002` INVALID_PARAMETER - 参数格式错误
- `1003` REQUEST_TOO_LARGE - 请求体过大
- `1004` JSON_PARSE_ERROR - JSON解析失败

#### 短链相关错误 (2000-2099)
- `2000` LINK_NOT_FOUND - 短链不存在
- `2001` LINK_EXPIRED - 短链已过期
- `2002` LINK_PAUSED - 短链已暂停
- `2003` LINK_DELETED - 短链已删除
- `2004` CODE_ALREADY_EXISTS - 短链码已存在
- `2005` CODE_GENERATION_FAILED - 短链码生成失败
- `2006` INVALID_URL - 无效的目标URL
- `2007` INVALID_CODE - 无效的短链码格式

#### 批量操作错误 (2100-2199)
- `2100` BATCH_TOO_LARGE - 批量操作数量超限
- `2101` BATCH_PARTIAL_FAILURE - 批量操作部分失败

#### 数据库错误 (3000-3099)
- `3000` DATABASE_ERROR - 数据库操作失败
- `3001` DATABASE_CONNECTION_ERROR - 数据库连接失败
- `3002` QUERY_ERROR - 查询执行失败

#### 安全相关错误 (4000-4099)
- `4000` FORBIDDEN - 访问被禁止
- `4001` IP_BLOCKED - IP地址已被封禁
- `4002` REFERER_DENIED - Referer验证失败
- `4003` TOKEN_INVALID - Token验证失败
- `4004` RATE_LIMIT_EXCEEDED - 请求频率超限

#### 系统错误 (5000-5099)
- `5000` INTERNAL_ERROR - 内部服务器错误
- `5001` SERVICE_UNAVAILABLE - 服务暂时不可用

---

## 使用示例

### Python 示例

```python
import requests

class ShortLinkAdmin:
    def __init__(self, base_url='http://localhost'):
        self.base_url = base_url

    def get_overview(self):
        """获取总体统计"""
        response = requests.get(f'{self.base_url}/api/stats/overview')
        return response.json()

    def cleanup_expired(self):
        """清理过期短链"""
        response = requests.post(f'{self.base_url}/api/admin/cleanup/expired')
        return response.json()

    def batch_update_status(self, codes, status):
        """批量更新状态"""
        data = {'codes': codes, 'status': status}
        response = requests.put(
            f'{self.base_url}/api/admin/batch/status',
            json=data
        )
        return response.json()

# 使用示例
admin = ShortLinkAdmin()

# 获取统计
stats = admin.get_overview()
print(f"总短链数: {stats['data']['total']}")

# 清理过期短链
result = admin.cleanup_expired()
print(f"清理了 {result['data']['deleted_count']} 条过期短链")

# 批量暂停短链
codes = ['code1', 'code2', 'code3']
result = admin.batch_update_status(codes, 'paused')
print(f"成功暂停 {result['data']['success']} 条短链")
```

### JavaScript 示例

```javascript
class ShortLinkAdmin {
    constructor(baseUrl = 'http://localhost') {
        this.baseUrl = baseUrl;
    }

    async getServiceStats(serviceType) {
        const response = await fetch(
            `${this.baseUrl}/api/stats/service/${serviceType}`
        );
        return await response.json();
    }

    async batchDelete(codes, permanent = false) {
        const response = await fetch(
            `${this.baseUrl}/api/admin/batch/delete`,
            {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({codes, permanent})
            }
        );
        return await response.json();
    }

    async listLinks(options = {}) {
        const params = new URLSearchParams(options);
        const response = await fetch(
            `${this.baseUrl}/api/admin/links?${params}`
        );
        return await response.json();
    }
}

// 使用示例
const admin = new ShortLinkAdmin();

// 获取图床服务统计
const stats = await admin.getServiceStats('imagebed');
console.log(`图床短链总数: ${stats.data.total}`);

// 查询短链列表
const links = await admin.listLinks({
    page: 1,
    page_size: 20,
    service_type: 'imagebed',
    status: 'active'
});
console.log(`找到 ${links.data.total} 条短链`);

// 批量删除
const result = await admin.batchDelete(['code1', 'code2'], false);
console.log(`删除了 ${result.data.success} 条短链`);
```

### cURL 示例

```bash
# 获取总体统计
curl http://localhost/api/stats/overview

# 获取图床服务统计
curl http://localhost/api/stats/service/imagebed

# 获取访问统计
curl "http://localhost/api/stats/access?short_code=img-abc123&days=7"

# 批量更新状态
curl -X PUT http://localhost/api/admin/batch/status \
  -H "Content-Type: application/json" \
  -d '{
    "codes": ["code1", "code2"],
    "status": "paused"
  }'

# 批量删除（软删除）
curl -X POST http://localhost/api/admin/batch/delete \
  -H "Content-Type: application/json" \
  -d '{
    "codes": ["code1", "code2"],
    "permanent": false
  }'

# 清理过期短链
curl -X POST http://localhost/api/admin/cleanup/expired

# 清理访问日志（保留30天）
curl -X POST "http://localhost/api/admin/cleanup/logs?days=30"

# 查询短链列表
curl "http://localhost/api/admin/links?page=1&page_size=20&service_type=imagebed&status=active"
```

---

## 定时任务建议

建议使用 cron 定时执行以下任务：

### 1. 每天清理过期短链
```bash
# 每天凌晨2点执行
0 2 * * * curl -X POST http://localhost/api/admin/cleanup/expired
```

### 2. 每周清理访问日志
```bash
# 每周日凌晨3点执行，保留90天日志
0 3 * * 0 curl -X POST "http://localhost/api/admin/cleanup/logs?days=90"
```

### 3. 监控统计数据
```bash
# 每小时记录一次统计数据
0 * * * * curl http://localhost/api/stats/overview >> /var/log/shortlink-stats.log
```

---

## 注意事项

1. **权限控制**: 建议为管理API添加认证中间件，限制访问权限
2. **速率限制**: 批量操作API应该设置适当的速率限制
3. **备份**: 执行永久删除前建议先备份数据
4. **监控**: 建议监控清理任务的执行结果
5. **日志保留**: 根据业务需求调整访问日志保留天数
