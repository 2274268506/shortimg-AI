# 🎯 短链管理系统 - 快速参考

## 🚀 一分钟快速开始

```powershell
# 1. 进入目录
cd redirect-service

# 2. 运行部署脚本
.\deploy-enhancements.ps1

# 3. 访问Dashboard
http://localhost/dashboard/
```

## 📋 常用操作速查

### 批量操作
```
1. 点击 "批量操作" 按钮
2. 勾选要操作的短链
3. 选择操作: 导出 | 更新状态 | 删除
```

### 高级搜索
```
1. 点击 "高级搜索" 按钮
2. 填写条件 (可多选):
   - 短链码 (模糊)
   - 服务类型
   - 状态
   - 时间范围
   - 访问量范围
3. 点击 "搜索"
```

### 导入数据
```
1. 点击 "导入" 按钮
2. 下载模板 (CSV/JSON)
3. 填写数据
4. 上传文件
```

### 导出数据
```
方式1: 导出全部
  → 点击 "导出全部" → 选择格式

方式2: 导出筛选结果
  → 搜索 → 导出当前结果

方式3: 导出选中
  → 批量模式 → 勾选 → 导出选中
```

### 回收站
```
查看: 点击 "回收站" 按钮
恢复: 找到短链 → 点击 "恢复"
永久删除: 找到短链 → 点击 "永久删除" (二次确认)
```

## 🔌 API 快速参考

### 基础操作
```bash
# 创建短链
POST /api/v2/imagebed
{
  "image_path": "/i/abc-123",
  "short_code": "my-img"
}

# 更新短链
PUT /api/v2/imagebed/my-img
{
  "status": "paused"
}

# 删除短链 (软删除)
DELETE /api/v2/imagebed/my-img
```

### 高级功能
```bash
# 高级搜索
POST /api/v2/imagebed/search
{
  "service_type": "imagebed",
  "status": "active",
  "visit_count_min": 100
}

# 导出数据
GET /api/v2/imagebed/export?format=csv

# 导入数据
POST /api/v2/imagebed/import
{
  "links": [...]
}

# 查看回收站
GET /api/v2/imagebed/trash

# 恢复短链
POST /api/v2/imagebed/restore/my-img

# 永久删除
DELETE /api/v2/imagebed/permanent/my-img
```

## 📝 CSV 导入格式

```csv
短链码,服务类型,目标路径,访问策略,过期时间,备注
img-001,imagebed,/i/photo1,weighted,,照片1
img-002,imagebed,/i/photo2,round_robin,86400,24小时过期
img-003,imagebed,/i/photo3,random,,照片3
```

## 📊 JSON 导入格式

```json
{
  "links": [
    {
      "short_code": "img-001",
      "service_type": "imagebed",
      "image_path": "/i/photo1",
      "strategy": "weighted",
      "note": "照片1"
    }
  ]
}
```

## 🔍 搜索条件说明

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| short_code | 文本 | 短链码模糊匹配 | "img" |
| service_type | 选择 | 服务类型 | "imagebed" |
| status | 选择 | 状态 | "active" |
| date_from | 日期 | 开始日期 | "2024-01-01" |
| date_to | 日期 | 结束日期 | "2024-12-31" |
| visit_count_min | 数字 | 最小访问量 | 100 |
| visit_count_max | 数字 | 最大访问量 | 1000 |

## ⚡ 快捷键

| 快捷键 | 功能 |
|--------|------|
| Ctrl+F | 打开搜索 |
| Ctrl+B | 批量模式 |
| Ctrl+E | 导出数据 |
| Ctrl+I | 导入数据 |
| Ctrl+R | 刷新列表 |
| Esc | 关闭模态框 |

## 🎨 状态说明

| 状态 | 图标 | 说明 |
|------|------|------|
| active | 🟢 | 活跃，正常工作 |
| paused | 🟡 | 暂停，不可访问 |
| deleted | 🔴 | 已删除，在回收站 |

## ⚠️ 常见错误

### 导入失败
```
原因: CSV 格式错误
解决: 使用模板文件，检查编码(UTF-8)
```

### 搜索无结果
```
原因: 条件过于严格
解决: 放宽条件，使用部分匹配
```

### 批量操作卡住
```
原因: 选中数量过多
解决: 分批处理，每次不超过1000个
```

### 回收站为空
```
原因: 没有软删除的短链
解决: 检查是否直接永久删除
```

## 💡 最佳实践

### 1. 定期备份
```
频率: 每周
方式: 导出全部数据 → CSV/JSON
存储: 本地 + 云盘
```

### 2. 批量操作
```
单次数量: ≤ 1000
失败重试: 分批执行
验证: 操作前先测试
```

### 3. 数据清理
```
步骤:
1. 筛选过期/无效短链
2. 软删除 (进回收站)
3. 观察7天
4. 确认无误后永久删除
```

### 4. 导入数据
```
流程:
1. 下载模板
2. 小批量测试
3. 验证结果
4. 正式批量导入
```

## 📞 获取帮助

### 文档
- 📘 [功能完善计划](./ENHANCEMENT_PLAN.md)
- 📗 [功能集成说明](./FEATURES_INTEGRATION.md)
- 📙 [功能对比](./FEATURES_COMPARISON.md)
- 📕 [API 文档](./docs/ADMIN_API.md)

### 问题排查
1. 检查浏览器控制台 (F12)
2. 查看服务日志: `docker logs short-link-openresty`
3. 验证 API 可访问性: `curl http://localhost/api/v2/imagebed/trash`

### 常用命令
```bash
# 查看服务状态
docker ps | grep short-link

# 查看日志
docker logs -f short-link-openresty

# 重启服务
docker-compose restart short-link-openresty

# 进入容器
docker exec -it short-link-openresty bash
```

## 🔥 Pro Tips

💡 **批量导出技巧**: 先用高级搜索筛选，再导出结果，避免导出无关数据

💡 **导入优化**: 使用 JSON 格式导入复杂配置，CSV 用于简单数据

💡 **回收站管理**: 设置定时任务自动清理30天前的删除记录

💡 **搜索优化**: 常用搜索条件可保存为书签或浏览器预设

💡 **性能优化**: 大批量操作在低峰时段执行，避免影响业务

---

**祝使用愉快！** 🎉

_有问题随时查阅完整文档或提交 Issue_
