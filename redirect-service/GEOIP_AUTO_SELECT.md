# GeoIP 自动选择功能文档

## 概述

短链服务现在支持根据路由分流规则自动选择最合适的 GeoIP 数据库。系统会分析您的路由配置需求，智能选择 `qqwry.dat`（纯真IP库）或 `GeoLite2-*.mmdb`（MaxMind数据库）。

## 支持的 GeoIP 数据库

### 1. qqwry.dat (纯真IP数据库)
- **路径**: `/usr/local/openresty/nginx/geoip/qqwry.dat`
- **类型**: 国内IP数据库
- **优势**:
  - 包含详细的中国省份、城市信息
  - 精确的运营商识别（电信、联通、移动等）
  - 体积小，查询速度快
  - 专门针对中国IP优化
- **适用场景**:
  - 国内三网分流（电信/联通/移动）
  - 省份级别路由
  - 城市级别路由
  - 运营商识别

### 2. GeoLite2-Country.mmdb
- **路径**: `/usr/local/openresty/nginx/geoip/GeoLite2-Country.mmdb`
- **类型**: 全球国家级数据库
- **优势**:
  - 全球覆盖
  - 体积小（~6MB）
  - 查询速度快
- **适用场景**:
  - 国家级分流（国内/海外）
  - 快速国家识别
  - 低内存环境

### 3. GeoLite2-City.mmdb
- **路径**: `/usr/local/openresty/nginx/geoip/GeoLite2-City.mmdb`
- **类型**: 全球城市级数据库
- **优势**:
  - 全球城市级精度
  - 包含经纬度、时区
  - 最详细的地理信息
- **适用场景**:
  - 需要详细地理位置
  - 距离计算
  - 高精度分流

### 4. GeoLite2-ASN.mmdb
- **路径**: `/usr/local/openresty/nginx/geoip/GeoLite2-ASN.mmdb`
- **类型**: ASN/运营商数据库
- **优势**:
  - 精确的ASN识别
  - 运营商组织信息
- **适用场景**:
  - ASN路由
  - 运营商精确识别

## 自动选择机制

### 工作原理

系统会分析您的路由规则中的条件类型，并根据需求自动选择合适的数据库：

```lua
-- 路由规则示例
{
    name = "国内电信用户",
    conditions = {
        {type = "country", value = "CN"},      -- 需要国家信息
        {type = "isp", values = {"China Telecom"}}  -- 需要运营商信息
    }
}
```

### 选择策略

1. **需要国内运营商信息** → 优先选择 `qqwry.dat`
   ```lua
   {type = "isp", values = {"China Telecom", "China Unicom", "China Mobile"}}
   ```

2. **需要省份信息** → 优先选择 `qqwry.dat`
   ```lua
   {type = "province", values = {"北京", "上海", "广东"}}
   ```

3. **仅需要国家信息** → 选择 `GeoLite2-Country.mmdb`
   ```lua
   {type = "country", value = "CN"}
   ```

4. **需要ASN信息** → 选择 `GeoLite2-ASN.mmdb`
   ```lua
   {type = "asn", values = {"4134", "4837"}}
   ```

5. **需要城市级精度** → 选择 `GeoLite2-City.mmdb`
   ```lua
   {type = "city", values = {"Beijing", "Shanghai"}}
   ```

### 评分系统

每个数据库会根据以下因素计算得分：
- **优先级** (priority): 数字越小优先级越高
- **功能匹配**: 满足路由需求的能力
- **专用数据库加分**: 针对特定需求的数据库（如 qqwry.dat 针对中国IP）
- **全球覆盖加分**: 支持全球查询的数据库

## 使用示例

### 示例 1: 国内三网分流

```lua
-- routing_config_simple.lua
routing_rules = {
    {
        name = "图床_电信",
        enabled = true,
        conditions = {
            {type = "service_type", value = "imagebed"},
            {type = "isp", values = {"China Telecom"}}
        },
        target = "imagebed_telecom"
    },
    {
        name = "图床_联通",
        enabled = true,
        conditions = {
            {type = "service_type", value = "imagebed"},
            {type = "isp", values = {"China Unicom"}}
        },
        target = "imagebed_unicom"
    }
}
```

**自动选择**: `qqwry.dat` (得分最高，包含详细的运营商信息)

### 示例 2: 国内外分流

```lua
routing_rules = {
    {
        name = "国内用户",
        conditions = {
            {type = "country", value = "CN"}
        },
        target = "china_cdn"
    },
    {
        name = "海外用户",
        conditions = {
            {type = "country", operator = "not_equals", value = "CN"}
        },
        target = "overseas_cdn"
    }
}
```

**自动选择**: `GeoLite2-Country.mmdb` (体积小，全球覆盖，适合快速国家识别)

### 示例 3: 省份级分流

```lua
routing_rules = {
    {
        name = "华北地区",
        conditions = {
            {type = "province", values = {"北京", "河北", "天津"}}
        },
        target = "north_cdn"
    }
}
```

**自动选择**: `qqwry.dat` (包含详细的省份信息)

### 示例 4: ASN 路由

```lua
routing_rules = {
    {
        name = "电信骨干网",
        conditions = {
            {type = "asn", values = {"4134", "4809"}}
        },
        target = "chinanet_cdn"
    }
}
```

**自动选择**: `GeoLite2-ASN.mmdb` (专门的ASN数据库)

## 管理 API

### 1. 查看所有可用数据库

```bash
GET /admin/geoip/databases
```

响应示例:
```json
{
  "success": true,
  "data": {
    "databases": [
      {
        "id": "qqwry",
        "name": "纯真IP数据库",
        "path": "/usr/local/openresty/nginx/geoip/qqwry.dat",
        "type": "qqwry",
        "description": "国内IP数据库，包含详细的省份、城市、运营商信息",
        "exists": true,
        "priority": 10
      },
      {
        "id": "geolite2_country",
        "name": "GeoLite2 Country",
        "path": "/usr/local/openresty/nginx/geoip/GeoLite2-Country.mmdb",
        "type": "maxmind",
        "exists": true,
        "priority": 20
      }
    ],
    "total": 4
  }
}
```

### 2. 查看当前选中的数据库

```bash
GET /admin/geoip/selected
```

响应示例:
```json
{
  "success": true,
  "data": {
    "selected": [
      {
        "id": "qqwry",
        "path": "/usr/local/openresty/nginx/geoip/qqwry.dat",
        "type": "qqwry",
        "name": "纯真IP数据库",
        "score": 145
      },
      {
        "id": "geolite2_country",
        "path": "/usr/local/openresty/nginx/geoip/GeoLite2-Country.mmdb",
        "type": "maxmind",
        "name": "GeoLite2 Country",
        "score": 110
      }
    ],
    "total": 2
  }
}
```

### 3. 验证数据库文件

```bash
GET /admin/geoip/validate
```

响应示例:
```json
{
  "success": true,
  "data": {
    "validation": [
      {
        "id": "qqwry",
        "name": "纯真IP数据库",
        "path": "/usr/local/openresty/nginx/geoip/qqwry.dat",
        "exists": true,
        "readable": true,
        "size": 8388608
      }
    ]
  }
}
```

### 4. 获取推荐配置

```bash
GET /admin/geoip/recommendations
```

响应示例:
```json
{
  "success": true,
  "data": {
    "requirements": {
      "need_country": true,
      "need_province": true,
      "need_isp": true,
      "need_asn": false
    },
    "selected_databases": [...],
    "summary": "根据您的路由规则分析：\n- 建议使用 qqwry.dat 用于国内IP的运营商和省份识别\n- 建议使用 GeoLite2-Country.mmdb 用于快速的国家级分流"
  }
}
```

### 5. 测试IP查询

```bash
POST /admin/geoip/query
Content-Type: application/json

{
  "ip": "1.2.3.4"
}
```

响应示例:
```json
{
  "success": true,
  "data": {
    "ip": "1.2.3.4",
    "country": "China",
    "country_code": "CN",
    "province": "福建省",
    "city": "福州市",
    "isp": "China Telecom",
    "sources": ["qqwry", "maxmind"]
  }
}
```

### 6. 重载配置

```bash
POST /admin/geoip/reload
```

响应示例:
```json
{
  "success": true,
  "message": "配置已重载",
  "data": {
    "selected_databases": [...]
  }
}
```

## 性能优化

### 数据库加载策略

1. **延迟加载**: 数据库在首次查询时才加载到内存
2. **缓存**: 已加载的数据库会缓存在内存中
3. **组合查询**: 多个数据库并行查询，结果合并

### 内存占用

- `qqwry.dat`: ~8MB
- `GeoLite2-Country.mmdb`: ~6MB
- `GeoLite2-City.mmdb`: ~70MB
- `GeoLite2-ASN.mmdb`: ~5MB

### 查询性能

- `qqwry.dat`: ~0.1ms (国内IP)
- `GeoLite2-Country.mmdb`: ~0.05ms
- `GeoLite2-City.mmdb`: ~0.2ms
- `GeoLite2-ASN.mmdb`: ~0.05ms

## 最佳实践

### 1. 针对业务场景选择

- **纯国内业务**: 只使用 `qqwry.dat`
- **国内外业务**: `qqwry.dat` + `GeoLite2-Country.mmdb`
- **全球业务**: `GeoLite2-City.mmdb` + `GeoLite2-ASN.mmdb`

### 2. 数据库更新

定期更新数据库以获取最新的IP分配信息：

```bash
# 下载最新的 qqwry.dat
wget http://update.cz88.net/soft/qqwry.rar

# 下载最新的 GeoLite2 数据库
wget https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&suffix=tar.gz
```

### 3. 监控和日志

系统会在启动时记录选中的数据库：

```
[RoutingEngine] 配置已加载
[RoutingEngine] 已选择 2 个 GeoIP 数据库
[RoutingEngine]   - 纯真IP数据库 (得分: 145)
[RoutingEngine]   - GeoLite2 Country (得分: 110)
```

### 4. 故障排查

如果 GeoIP 查询失败：

1. 检查数据库文件是否存在
2. 验证文件权限
3. 查看错误日志
4. 使用验证 API 检查数据库状态

## 故障排除

### 问题: 数据库未找到

```
[GeoIPQuery] 无法打开数据库: /path/to/geoip.dat
```

**解决方案**:
1. 检查文件路径是否正确
2. 确认文件已下载
3. 检查文件权限: `chmod 644 /path/to/geoip.dat`

### 问题: 查询返回空结果

**解决方案**:
1. 确认IP地址格式正确
2. 检查数据库是否过期
3. 使用多个数据库提高覆盖率

### 问题: 性能问题

**解决方案**:
1. 优先选择较小的数据库（Country vs City）
2. 使用缓存减少重复查询
3. 监控数据库加载时间

## 总结

GeoIP 自动选择功能可以：

✅ **自动分析**路由规则需求
✅ **智能选择**最合适的数据库组合
✅ **优化性能**减少不必要的数据库加载
✅ **提高准确性**使用专用数据库提升识别精度
✅ **简化配置**无需手动指定数据库

系统会根据您的实际路由规则，自动在 `qqwry.dat` 和 `GeoLite2-*.mmdb` 之间智能选择，确保最佳的分流效果和查询性能。
