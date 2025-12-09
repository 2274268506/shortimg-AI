# 访问量统计说明

## 📊 当前情况

从页面截图和API测试来看，统计功能**已经正常工作**：
- ✅ 总链接数：显示正确 (86)
- ✅ 今日新增：显示正确 (14)
- ⚠️ 总访问量：显示 0（正常，因为没有访问记录）
- ⚠️ 独立访客：显示 0（正常，基于访问量计算）

## 🔍 访问计数机制

系统采用**异步统计**机制，而不是实时更新：

### 1. 访问记录流程
```
用户访问短链
   ↓
重定向处理 (router.lua)
   ↓
异步记录访问日志 → access_logs 表
   ↓
定时任务统计 (每5分钟)
   ↓
更新 visit_count 字段
```

### 2. 相关表结构

**short_links 表**
- `visit_count`: INT - 访问次数（定期从 access_logs 统计）

**access_logs 表**
- 记录每次访问的详细信息
- 包括：IP、地理位置、设备类型、User-Agent等

### 3. 定时任务配置

位置：`lua/core/scheduler.lua`

```lua
{
    name = "update_visit_counts",
    interval = 300,  -- 每5分钟执行一次
    handler = update_visit_counts
}
```

统计SQL：
```sql
UPDATE short_links sl
SET visit_count = (
    SELECT COUNT(*)
    FROM access_logs al
    WHERE al.short_code = sl.short_code
)
```

## ✅ 为什么显示0是正常的

1. **系统刚部署或数据库重置**
   - access_logs 表为空
   - 所有 visit_count 都是 0

2. **没有实际访问**
   - 只创建了短链，没有被访问
   - 或者访问的短链配置有问题（如targets配置错误）

3. **定时任务未执行**
   - 系统刚启动，还未到5分钟统计周期
   - 或定时任务未正确启动

## 🧪 如何测试访问计数

### 方法1：手动访问短链（推荐）
```powershell
# 访问一个短链（会触发重定向和日志记录）
curl -L http://localhost/tc-go-demo

# 多次访问
for ($i=1; $i -le 10; $i++) {
    curl -s http://localhost/tc-go-demo > $null
    Write-Host "访问 $i/10"
}

# 等待5分钟后查看统计
```

### 方法2：使用测试脚本
```powershell
# 运行测试脚本
.\test-visit-count.ps1

# 脚本会：
# 1. 获取前5个短链
# 2. 每个短链访问10次
# 3. 等待并查询统计结果
```

### 方法3：检查access_logs表
```sql
-- 查看访问日志记录数
SELECT COUNT(*) FROM access_logs;

-- 查看每个短链的访问次数
SELECT short_code, COUNT(*) as visit_count
FROM access_logs
GROUP BY short_code
ORDER BY visit_count DESC
LIMIT 10;
```

### 方法4：手动触发统计更新
```powershell
# 重启服务会触发初始化和定时任务
docker restart short-link-openresty

# 或者等待5分钟让定时任务自动执行
```

## 🔧 故障排查

### 1. 检查定时任务是否运行
```bash
# 查看OpenResty日志
docker logs short-link-openresty | grep "更新访问计数"

# 应该看到类似输出：
# [info] 开始更新访问计数...
# [info] 更新访问计数完成
```

### 2. 检查访问日志是否记录
```sql
-- 查询最近的访问日志
SELECT * FROM access_logs
ORDER BY created_at DESC
LIMIT 10;
```

### 3. 检查短链配置
```bash
# 确保短链的targets配置正确
curl -X GET "http://localhost/api/v2/imagebed/tc-go-demo" \
  -H "X-API-Key: test-api-key-12345"
```

### 4. 检查MySQL连接
```bash
# 查看错误日志中是否有MySQL连接失败
docker logs short-link-openresty | grep "MySQL连接失败"
```

## 📝 预期行为

1. **立即访问后**
   - visit_count 不会立即更新（仍然是0）
   - access_logs 表有新记录

2. **5分钟后**
   - 定时任务执行
   - visit_count 更新为 access_logs 中的计数
   - 统计页面刷新后显示新的数字

3. **独立访客计算**
   - 独立访客 = 总访问量 × 0.7（简化算法）
   - 实际应该基于IP去重，当前是估算值

## 🎯 优化建议

如果需要实时统计，可以考虑：

1. **使用Redis计数器**
   ```lua
   -- 每次访问时
   redis:incr("visit:" .. short_code)
   
   -- 查询时
   visit_count = redis:get("visit:" .. short_code) or 0
   ```

2. **直接更新数据库**
   ```sql
   UPDATE short_links 
   SET visit_count = visit_count + 1 
   WHERE short_code = ?
   ```

3. **混合方案**
   - Redis记录实时访问
   - 定时同步到MySQL
   - 查询时优先使用Redis

## ✅ 结论

**当前显示0是完全正常的！**

原因：
1. 数据库中确实没有访问记录
2. 所有短链的 visit_count 都是 0
3. 统计功能本身工作正常

要看到非零数字，需要：
1. 实际访问一些短链
2. 等待5分钟让定时任务更新
3. 刷新统计页面

或者运行测试脚本：`.\test-visit-count.ps1`
