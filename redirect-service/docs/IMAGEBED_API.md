# 图床短链集成 API 文档

## 📸 功能概述

图床短链集成提供了专门为图床服务优化的短链功能，支持：
- ✅ 单个/批量创建图床短链
- ✅ 自定义短链代码
- ✅ 图片元数据管理
- ✅ 过期时间控制
- ✅ 统计分析

## 🚀 快速开始

### 创建单个图床短链

```bash
curl -X POST http://localhost/api/imagebed/create \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://imagebed.example.com/uploads/photo.jpg",
    "custom_code": "summer2024",
    "expire_time": 2592000,
    "metadata": {
      "filename": "summer_vacation.jpg",
      "size": 1024000,
      "type": "image/jpeg",
      "description": "Summer vacation photo"
    }
  }'
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "code": "summer2024",
    "short_url": "https://short.example.com/summer2024",
    "long_url": "https://imagebed.example.com/uploads/photo.jpg",
    "expire_at": 1735891200,
    "created_at": 1733299200
  }
}
```

---

## 📖 API 详细说明

### 1. 创建图床短链

**端点**: `POST /api/imagebed/create`

**请求体**:
```json
{
  "image_url": "string (必需)",
  "custom_code": "string (可选)",
  "expire_time": "number (可选，秒)",
  "metadata": {
    "filename": "string (可选)",
    "size": "number (可选)",
    "type": "string (可选)",
    "description": "string (可选)",
    "tags": ["string"] "(可选)",
    "album": "string (可选)"
  }
}
```

**参数说明**:
- `image_url`: 图片的完整URL（必须以 http:// 或 https:// 开头）
- `custom_code`: 自定义短链代码（6-20个字符，字母数字）
- `expire_time`: 过期时间（秒），0 或不设置表示永不过期
- `metadata`: 图片元数据（可选）
  - `filename`: 文件名
  - `size`: 文件大小（字节）
  - `type`: MIME类型（如 image/jpeg）
  - `description`: 图片描述
  - `tags`: 标签数组
  - `album`: 相册名称

**响应示例**:
```json
{
  "success": true,
  "data": {
    "code": "abc123",
    "short_url": "https://short.example.com/abc123",
    "long_url": "https://imagebed.example.com/photo.jpg",
    "expire_at": null,
    "created_at": 1733299200
  }
}
```

---

### 2. 批量创建图床短链

**端点**: `POST /api/imagebed/batch`

**请求体**:
```json
{
  "images": [
    {
      "image_url": "https://imagebed.example.com/img1.jpg",
      "custom_code": "img1",
      "metadata": {
        "filename": "photo1.jpg",
        "size": 500000
      }
    },
    {
      "image_url": "https://imagebed.example.com/img2.jpg",
      "custom_code": "img2",
      "metadata": {
        "filename": "photo2.jpg",
        "size": 750000
      }
    }
  ],
  "expire_time": 86400
}
```

**参数说明**:
- `images`: 图片数组（最多100个）
  - 每个元素包含 `image_url`、`custom_code`（可选）、`metadata`（可选）
- `expire_time`: 统一过期时间（可选）

**响应示例**:
```json
{
  "success": true,
  "data": {
    "total": 2,
    "success": 2,
    "failed": 0,
    "results": [
      {
        "success": true,
        "code": "img1",
        "short_url": "https://short.example.com/img1",
        "long_url": "https://imagebed.example.com/img1.jpg"
      },
      {
        "success": true,
        "code": "img2",
        "short_url": "https://short.example.com/img2",
        "long_url": "https://imagebed.example.com/img2.jpg"
      }
    ]
  }
}
```

---

### 3. 获取图床短链信息

**端点**: `GET /api/imagebed/info/{code}`

**参数**:
- `code`: 短链代码（路径参数）

**响应示例**:
```json
{
  "success": true,
  "data": {
    "code": "summer2024",
    "long_url": "https://imagebed.example.com/photo.jpg",
    "metadata": {
      "type": "imagebed",
      "created_by": "imagebed_service",
      "filename": "summer_vacation.jpg",
      "size": 1024000,
      "type": "image/jpeg",
      "description": "Summer vacation photo"
    },
    "click_count": 150,
    "expire_at": 1735891200,
    "created_at": "2024-12-01 10:00:00",
    "updated_at": "2024-12-05 15:30:00",
    "from_cache": false
  }
}
```

---

### 4. 更新图床短链元数据

**端点**: `PUT /api/imagebed/metadata/{code}`

**参数**:
- `code`: 短链代码（路径参数）

**请求体**:
```json
{
  "filename": "updated_photo.jpg",
  "description": "Updated description",
  "tags": ["travel", "2024", "summer"],
  "album": "Vacation 2024"
}
```

**注意**: 不能修改 `type` 和 `created_by` 字段

**响应示例**:
```json
{
  "success": true,
  "data": {
    "code": "summer2024",
    "metadata": {
      "type": "imagebed",
      "created_by": "imagebed_service",
      "filename": "updated_photo.jpg",
      "description": "Updated description",
      "tags": ["travel", "2024", "summer"],
      "album": "Vacation 2024"
    },
    "updated_at": 1733299500
  }
}
```

---

### 5. 获取图床短链统计

**端点**: `GET /api/imagebed/stats`

**响应示例**:
```json
{
  "success": true,
  "data": {
    "total_links": 1523,
    "today_created": 45,
    "total_clicks": 25678,
    "top_images": [
      {
        "code": "popular1",
        "long_url": "https://imagebed.example.com/popular.jpg",
        "click_count": 5432,
        "created_at": "2024-11-15 08:20:00"
      }
    ]
  }
}
```

---

## 🔧 集成示例

### PHP 集成示例

```php
<?php
class ImagebedShortLink {
    private $apiBase = 'http://localhost/api/imagebed';

    public function createShortLink($imageUrl, $metadata = []) {
        $data = [
            'image_url' => $imageUrl,
            'metadata' => $metadata
        ];

        $ch = curl_init($this->apiBase . '/create');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json'
        ]);

        $response = curl_exec($ch);
        curl_close($ch);

        return json_decode($response, true);
    }

    public function batchCreate($images, $expireTime = null) {
        $data = [
            'images' => $images
        ];

        if ($expireTime) {
            $data['expire_time'] = $expireTime;
        }

        $ch = curl_init($this->apiBase . '/batch');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json'
        ]);

        $response = curl_exec($ch);
        curl_close($ch);

        return json_decode($response, true);
    }
}

// 使用示例
$shortLink = new ImagebedShortLink();

// 单个创建
$result = $shortLink->createShortLink(
    'https://imagebed.example.com/photo.jpg',
    [
        'filename' => 'photo.jpg',
        'size' => 1024000,
        'type' => 'image/jpeg'
    ]
);

echo "Short URL: " . $result['data']['short_url'];

// 批量创建
$images = [
    [
        'image_url' => 'https://imagebed.example.com/img1.jpg',
        'metadata' => ['filename' => 'img1.jpg']
    ],
    [
        'image_url' => 'https://imagebed.example.com/img2.jpg',
        'metadata' => ['filename' => 'img2.jpg']
    ]
];

$batchResult = $shortLink->batchCreate($images, 86400);
print_r($batchResult);
?>
```

---

### Python 集成示例

```python
import requests
import json

class ImagebedShortLink:
    def __init__(self, api_base='http://localhost/api/imagebed'):
        self.api_base = api_base

    def create_short_link(self, image_url, metadata=None, custom_code=None, expire_time=None):
        """创建单个图床短链"""
        data = {'image_url': image_url}

        if metadata:
            data['metadata'] = metadata
        if custom_code:
            data['custom_code'] = custom_code
        if expire_time:
            data['expire_time'] = expire_time

        response = requests.post(
            f'{self.api_base}/create',
            json=data
        )
        return response.json()

    def batch_create(self, images, expire_time=None):
        """批量创建图床短链"""
        data = {'images': images}

        if expire_time:
            data['expire_time'] = expire_time

        response = requests.post(
            f'{self.api_base}/batch',
            json=data
        )
        return response.json()

    def get_info(self, code):
        """获取短链信息"""
        response = requests.get(f'{self.api_base}/info/{code}')
        return response.json()

    def update_metadata(self, code, metadata):
        """更新元数据"""
        response = requests.put(
            f'{self.api_base}/metadata/{code}',
            json=metadata
        )
        return response.json()

    def get_stats(self):
        """获取统计信息"""
        response = requests.get(f'{self.api_base}/stats')
        return response.json()

# 使用示例
api = ImagebedShortLink()

# 创建短链
result = api.create_short_link(
    'https://imagebed.example.com/photo.jpg',
    metadata={
        'filename': 'photo.jpg',
        'size': 1024000,
        'type': 'image/jpeg',
        'description': 'My photo'
    },
    custom_code='myphoto',
    expire_time=86400
)

print(f"Short URL: {result['data']['short_url']}")

# 批量创建
images = [
    {
        'image_url': 'https://imagebed.example.com/img1.jpg',
        'metadata': {'filename': 'img1.jpg'}
    },
    {
        'image_url': 'https://imagebed.example.com/img2.jpg',
        'metadata': {'filename': 'img2.jpg'}
    }
]

batch_result = api.batch_create(images, expire_time=86400)
print(f"Created {batch_result['data']['success']} short links")

# 获取统计
stats = api.get_stats()
print(f"Total imagebed links: {stats['data']['total_links']}")
```

---

### JavaScript/Node.js 集成示例

```javascript
class ImagebedShortLink {
    constructor(apiBase = 'http://localhost/api/imagebed') {
        this.apiBase = apiBase;
    }

    async createShortLink(imageUrl, options = {}) {
        const data = {
            image_url: imageUrl,
            ...options
        };

        const response = await fetch(`${this.apiBase}/create`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });

        return await response.json();
    }

    async batchCreate(images, expireTime = null) {
        const data = { images };
        if (expireTime) {
            data.expire_time = expireTime;
        }

        const response = await fetch(`${this.apiBase}/batch`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });

        return await response.json();
    }

    async getInfo(code) {
        const response = await fetch(`${this.apiBase}/info/${code}`);
        return await response.json();
    }

    async updateMetadata(code, metadata) {
        const response = await fetch(`${this.apiBase}/metadata/${code}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(metadata)
        });

        return await response.json();
    }

    async getStats() {
        const response = await fetch(`${this.apiBase}/stats`);
        return await response.json();
    }
}

// 使用示例
const api = new ImagebedShortLink();

// 创建短链
api.createShortLink('https://imagebed.example.com/photo.jpg', {
    custom_code: 'myphoto',
    expire_time: 86400,
    metadata: {
        filename: 'photo.jpg',
        size: 1024000,
        type: 'image/jpeg'
    }
}).then(result => {
    console.log('Short URL:', result.data.short_url);
});

// 批量创建
const images = [
    {
        image_url: 'https://imagebed.example.com/img1.jpg',
        metadata: { filename: 'img1.jpg' }
    },
    {
        image_url: 'https://imagebed.example.com/img2.jpg',
        metadata: { filename: 'img2.jpg' }
    }
];

api.batchCreate(images, 86400).then(result => {
    console.log(`Created ${result.data.success} short links`);
});
```

---

## 🎯 使用场景

### 场景 1: 图床上传后自动创建短链

用户上传图片到图床后，图床服务自动调用API创建短链并返回给用户：

```python
# 图床上传处理
def handle_upload(file):
    # 1. 保存图片
    image_url = save_image(file)

    # 2. 创建短链
    api = ImagebedShortLink()
    result = api.create_short_link(
        image_url,
        metadata={
            'filename': file.filename,
            'size': file.size,
            'type': file.content_type,
            'uploader': current_user.id
        },
        expire_time=365*24*3600  # 1年
    )

    # 3. 返回短链和原链接
    return {
        'original_url': image_url,
        'short_url': result['data']['short_url'],
        'code': result['data']['code']
    }
```

### 场景 2: 批量图片管理

管理员批量处理多张图片：

```python
def batch_process_images(image_urls):
    images = []
    for url in image_urls:
        images.append({
            'image_url': url,
            'metadata': {
                'batch_id': 'batch_001',
                'processed_at': datetime.now().isoformat()
            }
        })

    api = ImagebedShortLink()
    result = api.batch_create(images, expire_time=30*24*3600)

    return result['data']['results']
```

### 场景 3: 图片分享

用户分享图片时使用短链：

```javascript
// 前端代码
async function shareImage(imageUrl) {
    const api = new ImagebedShortLink();

    const result = await api.createShortLink(imageUrl, {
        custom_code: generateCustomCode(),
        expire_time: 7 * 24 * 3600,  // 7天
        metadata: {
            shared_by: getCurrentUserId(),
            shared_at: new Date().toISOString()
        }
    });

    // 复制短链到剪贴板
    navigator.clipboard.writeText(result.data.short_url);
    alert('短链已复制到剪贴板！');
}
```

---

## 📊 监控和统计

### Grafana 仪表板

图床短链的监控指标已集成到 Grafana 仪表板中：

- **访问地址**: http://localhost:3000/d/short-link-management
- **相关面板**:
  - 短链创建趋势（过滤 `metadata.type="imagebed"`）
  - 热门图片 Top 10
  - 批量操作统计
  - API 响应时间

### Prometheus 指标

```promql
# 图床短链创建速率
rate(short_link_http_requests_total{endpoint="/api/imagebed/create"}[5m])

# 图床短链总数（需要自定义标签）
short_link_short_links_total{type="imagebed"}

# 图床API响应时间
histogram_quantile(0.95,
  rate(short_link_http_request_duration_seconds_bucket{endpoint=~"/api/imagebed/.*"}[5m])
)
```

---

## ⚠️ 注意事项

### 1. URL 验证
- 图片URL必须以 `http://` 或 `https://` 开头
- 建议验证URL的可访问性
- 建议限制允许的域名（配置白名单）

### 2. 自定义代码规则
- 长度：6-20个字符
- 字符：字母、数字、下划线、连字符
- 不能与系统保留关键字冲突
- 建议使用有意义的代码

### 3. 批量操作限制
- 单次最多100个图片
- 建议分批处理大量图片
- 注意数据库事务处理

### 4. 过期时间
- 0 或不设置表示永不过期
- 建议根据业务需求设置合理的过期时间
- 临时分享：7天
- 长期存储：1年或永久

### 5. 元数据大小
- 建议元数据总大小 <5KB
- 避免存储大量文本或二进制数据
- 使用外部存储保存详细信息

---

## 🔒 安全建议

### 1. 访问控制
```nginx
# 限制API访问（在nginx配置中）
location /api/imagebed/ {
    # IP白名单
    allow 192.168.1.0/24;
    deny all;

    # 或使用API密钥验证
    access_by_lua_block {
        local api_key = ngx.var.http_x_api_key
        if api_key ~= "your-secret-key" then
            ngx.status = 401
            ngx.say('{"error":"Unauthorized"}')
            ngx.exit(401)
        end
    }

    content_by_lua_block {
        -- API处理逻辑
    }
}
```

### 2. 速率限制
```lua
-- 在API中添加速率限制
local rate_limiter = require("utils.rate_limiter")

if not rate_limiter:check_limit("imagebed_create", 100, 60) then
    return respond_error("请求过于频繁，请稍后再试", 429)
end
```

### 3. 输入验证
```lua
-- 验证图片URL域名
local allowed_domains = {"imagebed.example.com", "cdn.example.com"}
local is_allowed = false

for _, domain in ipairs(allowed_domains) do
    if data.image_url:match(domain) then
        is_allowed = true
        break
    end
end

if not is_allowed then
    return respond_error("不允许的图片URL域名")
end
```

---

## 📚 相关文档

- [短链服务 API 文档](./API.md)
- [监控仪表板使用指南](./MANAGEMENT_DASHBOARD.md)
- [性能优化指南](./PERFORMANCE.md)

---

**最后更新**: 2025-12-05
**版本**: 1.0
**维护团队**: 短链服务团队
