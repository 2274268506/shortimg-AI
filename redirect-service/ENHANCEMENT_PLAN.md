# 短链管理系统功能完善计划

## 📋 当前功能状态

### ✅ 已实现功能

#### 1. 核心短链功能
- ✅ 创建短链 (单个)
- ✅ 批量创建短链
- ✅ 更新短链
- ✅ 删除短链 (软删除)
- ✅ 获取短链信息
- ✅ 短链重定向

#### 2. Web 管理界面
- ✅ Dashboard 首页
- ✅ 短链列表管理
- ✅ 创建/编辑/删除操作
- ✅ 统计分析面板
- ✅ 批量操作入口
- ✅ 定时任务管理
- ✅ API Key 登录

#### 3. 统计功能
- ✅ 总体统计
- ✅ 服务类型统计
- ✅ 访问日志统计
- ✅ 实时访问量

## 🚀 待完善功能

### 1. 搜索和筛选增强 ⭐⭐⭐⭐⭐

#### 当前问题
- Dashboard 有搜索框但功能不完整
- 缺少高级筛选选项
- 没有保存筛选条件

#### 改进方案
```javascript
// 高级搜索功能
- 按短链码搜索 ✓
- 按创建时间范围搜索
- 按访问量范围筛选
- 按状态筛选 (活跃/暂停/已删除)
- 按服务类型筛选
- 组合搜索条件
- 保存常用搜索
```

### 2. 批量操作完善 ⭐⭐⭐⭐⭐

#### 当前问题
- 批量操作入口存在但功能未实现
- 没有批量编辑功能
- 缺少批量导入/导出

#### 改进方案
```javascript
// 批量操作功能
- 批量创建 (CSV/JSON 导入) ⚠️ 待实现
- 批量删除 (选中多个) ⚠️ 待实现
- 批量更新状态 ⚠️ 待实现
- 批量修改过期时间 ⚠️ 待实现
- 批量导出数据 ⚠️ 待实现
```

### 3. 短链恢复功能 ⭐⭐⭐⭐

#### 当前问题
- 只有软删除，没有恢复功能
- 删除的短链无法查看和恢复

#### 改进方案
```javascript
// 回收站功能
- 查看已删除短链
- 恢复已删除短链
- 永久删除功能
- 自动清理(30天后)
```

### 4. 数据导入导出 ⭐⭐⭐⭐

#### 当前问题
- 统计数据导出功能存在但不完整
- 没有短链数据导入功能

#### 改进方案
```javascript
// 导入导出功能
- CSV 格式导入短链
- Excel 格式导入
- JSON 批量导入
- 导出所有短链数据
- 导出筛选结果
- 导出模板下载
```

### 5. 访问日志详情 ⭐⭐⭐⭐

#### 当前问题
- 只有统计数据，没有详细日志
- 无法查看具体访问记录

#### 改进方案
```javascript
// 访问日志功能
- 查看每次访问记录
- IP 地址记录
- User-Agent 记录
- 访问时间记录
- 来源页面记录
- 地理位置显示
```

### 6. 短链分组管理 ⭐⭐⭐

#### 当前问题
- 短链都是平铺的
- 没有分组或标签功能

#### 改进方案
```javascript
// 分组管理
- 创建分组/标签
- 短链添加到分组
- 按分组筛选
- 分组统计
```

### 7. 权限管理 ⭐⭐⭐

#### 当前问题
- 只有单一 API Key
- 没有用户角色区分

#### 改进方案
```javascript
// 多用户权限
- 管理员账户
- 普通用户账户
- 只读账户
- API Key 权限级别
- 操作日志记录
```

### 8. 短链模板 ⭐⭐

#### 当前问题
- 每次创建都要配置
- 没有模板复用

#### 改进方案
```javascript
// 模板功能
- 保存常用配置为模板
- 从模板快速创建
- 模板管理
```

### 9. 预警和通知 ⭐⭐⭐

#### 当前问题
- 没有自动预警功能
- 异常需手动发现

#### 改进方案
```javascript
// 预警系统
- 短链即将过期提醒
- 访问量异常提醒
- 错误率过高提醒
- 邮件/Webhook 通知
```

### 10. 数据分析增强 ⭐⭐⭐⭐

#### 当前问题
- 统计功能基础
- 缺少深度分析

#### 改进方案
```javascript
// 高级分析
- 访问趋势图表 (按小时/天/周/月)
- 地理位置分布
- 设备类型统计
- 浏览器统计
- 来源分析
- 热力图显示
```

## 🎯 实施优先级

### P0 (必须实现)
1. ✅ 搜索和筛选增强
2. ✅ 批量操作完善
3. ✅ 短链恢复功能
4. ✅ 数据导入导出

### P1 (重要)
5. ✅ 访问日志详情
6. ✅ 数据分析增强

### P2 (可选)
7. 短链分组管理
8. 权限管理
9. 短链模板
10. 预警和通知

## 📝 实施步骤

### 第一阶段：核心功能完善 (P0)

#### 任务1: 搜索筛选增强
```javascript
// 文件: html/dashboard/dashboard.js

// 1. 添加高级搜索UI
function showAdvancedSearch() {
  // 创建高级搜索模态框
  // 支持多条件组合搜索
}

// 2. 实现筛选逻辑
function applyFilters(filters) {
  // 应用筛选条件
  // 刷新列表
}

// 3. 保存搜索历史
function saveSearchPreset(name, filters) {
  // 保存到 localStorage
}
```

#### 任务2: 批量操作实现
```javascript
// 文件: html/dashboard/dashboard.js

// 1. 批量选择UI
function toggleBatchMode() {
  // 显示复选框
  // 显示批量操作栏
}

// 2. 批量删除
async function batchDelete(codes) {
  // 调用批量删除API
  // 显示进度
}

// 3. 批量导入
async function importFromCSV(file) {
  // 解析CSV文件
  // 批量创建短链
}
```

#### 任务3: 回收站功能
```javascript
// 文件: lua/api/imagebed_v2.lua

// 1. 查询已删除短链
function _M.list_deleted()
  -- 查询 status = 'deleted' 的记录
  -- 返回分页结果
end

// 2. 恢复短链
function _M.restore()
  -- 更新 status = 'active'
  -- 清除缓存
end

// 3. 永久删除
function _M.permanent_delete()
  -- 物理删除记录
  -- 删除相关统计
end
```

#### 任务4: 导入导出
```javascript
// 文件: html/dashboard/dashboard.js

// 1. CSV导出
async function exportToCSV(filters) {
  // 获取数据
  // 生成CSV
  // 下载文件
}

// 2. CSV导入
async function importCSV(file) {
  // 解析文件
  // 验证数据
  // 批量创建
}

// 3. 模板下载
function downloadTemplate() {
  // 生成标准CSV模板
}
```

### 第二阶段：增强功能 (P1)

#### 任务5: 访问日志
```lua
-- 文件: lua/api/imagebed_v2.lua

-- 1. 记录访问日志
function log_access(short_code, client_info)
    -- 记录到 access_logs 表
    -- IP, User-Agent, Referer, 时间戳
end

-- 2. 查询访问日志
function _M.access_logs()
    -- 分页查询日志
    -- 支持时间范围筛选
end
```

#### 任务6: 数据分析
```javascript
// 文件: html/dashboard/dashboard.js

// 1. 趋势图表
function renderTrendChart(data) {
  // 使用 Chart.js 绘制
  // 支持多种时间粒度
}

// 2. 地理位置分布
function renderGeoMap(data) {
  // 使用地图组件
  // 显示访问分布
}

// 3. 设备统计
function renderDeviceStats(data) {
  // 饼图显示设备类型
}
```

## 💻 技术实现

### 数据库表结构扩展

```sql
-- 访问日志表
CREATE TABLE IF NOT EXISTS access_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    short_code VARCHAR(50) NOT NULL,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    referer VARCHAR(500),
    country VARCHAR(50),
    region VARCHAR(50),
    city VARCHAR(50),
    device_type VARCHAR(20),
    browser VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_short_code (short_code),
    INDEX idx_created_at (created_at)
);

-- 短链分组表
CREATE TABLE IF NOT EXISTS short_link_groups (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_name (name)
);

-- 短链分组关联表
CREATE TABLE IF NOT EXISTS short_link_group_items (
    short_code VARCHAR(50) NOT NULL,
    group_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (short_code, group_id),
    FOREIGN KEY (group_id) REFERENCES short_link_groups(id)
);

-- 预警规则表
CREATE TABLE IF NOT EXISTS alert_rules (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    rule_type VARCHAR(50),
    condition_json TEXT,
    notification_method VARCHAR(50),
    enabled TINYINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### API 端点扩展

```lua
-- 新增 API 端点

-- 回收站相关
GET  /api/v2/imagebed/trash          -- 获取已删除短链
POST /api/v2/imagebed/restore/:code  -- 恢复短链
DELETE /api/v2/imagebed/permanent/:code  -- 永久删除

-- 访问日志
GET /api/v2/imagebed/:code/logs      -- 获取访问日志
GET /api/v2/imagebed/:code/analytics -- 获取分析数据

-- 分组管理
GET    /api/v2/groups                -- 获取分组列表
POST   /api/v2/groups                -- 创建分组
PUT    /api/v2/groups/:id            -- 更新分组
DELETE /api/v2/groups/:id            -- 删除分组
POST   /api/v2/groups/:id/links      -- 添加短链到分组

-- 导入导出
POST /api/v2/imagebed/import         -- 导入短链
GET  /api/v2/imagebed/export         -- 导出短链
GET  /api/v2/imagebed/template       -- 下载导入模板
```

## 🎨 UI 改进

### Dashboard 布局优化

```
┌─────────────────────────────────────────────┐
│ 🎯 短链管理系统           [API Key] [退出]  │
├─────────────────────────────────────────────┤
│ 📊 统计卡片                                  │
│ ┌────────┬────────┬────────┬────────┐       │
│ │总链接  │今日访问│总访问量│独立访客│       │
│ │ 1,234  │  567   │ 89,012 │ 45,678 │       │
│ └────────┴────────┴────────┴────────┘       │
├─────────────────────────────────────────────┤
│ 🔍 搜索和筛选                                │
│ ┌─────────────────────────────────────────┐ │
│ │ [搜索框] [高级筛选▼] [批量操作▼] [导出] │ │
│ └─────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ 📋 短链列表                                  │
│ ┌───────────────────────────────────────┐   │
│ │☐ 短链码 │类型│状态│访问量│操作       │   │
│ │☐ abc123 │图床│活跃│ 1234 │[编辑删除] │   │
│ │☐ def456 │通用│暂停│  567 │[编辑删除] │   │
│ └───────────────────────────────────────┘   │
│ [上一页] [下一页]                            │
└─────────────────────────────────────────────┘
```

## 📦 开发计划

### Week 1: P0 功能
- [x] Day 1-2: 搜索筛选增强
- [x] Day 3-4: 批量操作实现
- [x] Day 5: 回收站功能

### Week 2: P0 + P1 功能
- [x] Day 1-2: 导入导出功能
- [x] Day 3-4: 访问日志记录
- [x] Day 5: 数据分析图表

### Week 3: P2 功能 (可选)
- [ ] Day 1-2: 分组管理
- [ ] Day 3-4: 权限系统
- [ ] Day 5: 预警通知

## ✅ 验收标准

### 功能完整性
- [ ] 所有P0功能100%实现
- [ ] P1功能80%实现
- [ ] UI响应流畅，无明显卡顿
- [ ] 批量操作支持1000+记录

### 性能标准
- [ ] 列表加载 < 500ms
- [ ] 搜索响应 < 200ms
- [ ] 批量导入1000条 < 5s
- [ ] 图表渲染 < 1s

### 用户体验
- [ ] 操作流程直观
- [ ] 错误提示清晰
- [ ] 支持键盘快捷键
- [ ] 响应式设计兼容移动端

## 📚 相关文档

- API 文档: `docs/ADMIN_API.md`
- Dashboard 使用: `docs/DASHBOARD_USAGE.md`
- 测试指南: `TESTING_GUIDE.md`
