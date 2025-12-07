# 前端创建短链逻辑优化

## 📝 需求说明

根据服务类型优化短链创建逻辑：

1. **通用服务类型（general）**：填写完整URL（如 `https://www.baidu.com`）
2. **其他服务类型（imagebed、cdn、file、video）**：只填写路径（如 `/uploads/image.jpg`），域名由后端CDN分流处理
3. **删除前端的CDN选择器和分流策略选项**

## ✅ 已完成的修改

### 1. 修改创建表单UI（index.html）

#### 步骤2：目标配置
**修改前**：
- 简单模式/高级模式切换
- JSON配置编辑器
- CDN快速模板

**修改后**：
```html
<!-- 通用服务类型 -->
<div id="general-target">
  <input type="url" id="target_url" placeholder="https://www.example.com/page.html">
  <small>输入完整的目标URL地址</small>
</div>

<!-- 其他服务类型 -->
<div id="cdn-target" style="display: none;">
  <input type="text" id="target_path" placeholder="/uploads/2025/12/image.jpg">
  <small>输入资源路径，域名将由后端根据CDN分流规则自动处理</small>
  <div class="info-box">
    CDN分流由后端自动处理，会根据用户地理位置、运营商等信息选择最优CDN节点
  </div>
</div>
```

#### 步骤3：高级选项
**删除内容**：
- 服务类型选择器（已移到步骤1）
- 分流策略下拉框
- 过期时间等字段

**保留内容**：
- 过期时间（datetime-local）
- 启用缓存（checkbox）

### 2. 修改JavaScript逻辑

#### modal-functions.js
增强 `updateServiceHelp()` 函数：
```javascript
function updateServiceHelp() {
  const serviceType = document.getElementById('service_type')?.value;

  // 根据服务类型切换显示
  if (serviceType === 'general') {
    // 显示 URL 输入框
    generalTarget.style.display = 'block';
    cdnTarget.style.display = 'none';
  } else {
    // 显示路径输入框
    generalTarget.style.display = 'none';
    cdnTarget.style.display = 'block';
  }
}
```

#### dashboard.js
修改表单提交逻辑：
```javascript
// 根据服务类型构建targets
let targets;

if (serviceType === 'general') {
  // 通用类型：使用完整URL
  const url = $('#target_url').value.trim();
  targets = [{
    url: url,
    weight: 1
  }];
} else {
  // 其他类型：使用路径
  const path = $('#target_path').value.trim();
  const normalizedPath = path.startsWith('/') ? path : '/' + path;
  targets = [{
    path: normalizedPath,
    weight: 1
  }];
}

const data = {
  short_code: shortCode,
  service_type: serviceType,
  targets: targets,
  strategy: 'weight', // 固定使用权重策略
  security_config: {
    enable_cache: enableCache
  }
};
```

**删除的函数**：
- `switchMode()` - 切换简单/高级模式
- `updateTargetsFromSimple()` - 从简单模式更新targets
- `showTargetHelp()` - 显示帮助信息
- `useTemplate()` - 使用快速模板

### 3. 添加样式（index.html）

```css
.info-box {
  background: #e6f7ff;
  border: 1px solid #91d5ff;
  border-radius: 4px;
  padding: 12px;
  margin-top: 12px;
  font-size: 13px;
  color: #0050b3;
  display: flex;
  align-items: flex-start;
  gap: 8px;
}

.target-config {
  margin-top: 12px;
}
```

## 🧪 测试场景

### 场景1：创建通用短链

**步骤**：
1. 点击"创建短链"
2. 步骤1：选择服务类型 = `general`（通用短链）
3. 步骤2：输入目标URL = `https://www.baidu.com`
4. 步骤3：设置过期时间（可选）
5. 提交

**预期结果**：
```json
{
  "short_code": "testgeneral1",
  "service_type": "general",
  "targets": [
    {"url": "https://www.baidu.com", "weight": 1}
  ],
  "strategy": "weight"
}
```

### 场景2：创建图床短链

**步骤**：
1. 点击"创建短链"
2. 步骤1：选择服务类型 = `imagebed`（图床服务）
3. 步骤2：输入资源路径 = `/uploads/2025/12/image.jpg`
4. 步骤3：设置过期时间（可选）
5. 提交

**预期结果**：
```json
{
  "short_code": "testimgbed01",
  "service_type": "imagebed",
  "targets": [
    {"path": "/uploads/2025/12/image.jpg", "weight": 1}
  ],
  "strategy": "weight"
}
```

后端会根据用户地理位置、运营商等信息，将`path`与合适的CDN域名组合。

### 场景3：验证UI切换

**步骤**：
1. 打开创建表单
2. 选择服务类型 = `general`
3. 观察：显示"目标 URL"输入框
4. 切换服务类型 = `imagebed`
5. 观察：显示"资源路径"输入框 + 蓝色info提示框

## 🔍 后端CDN分流逻辑（参考）

后端router.lua会这样处理：

```lua
if target.url then
  -- 通用类型：直接使用URL
  target_url = target.url
elseif target.path then
  -- 其他类型：根据service_type选择CDN
  local cdn_name = select_cdn_by_service_type(service_type, client_info)
  target_url = config.get_cdn_url(cdn_name, target.path)
end
```

## 📊 数据流对比

### 修改前
```
用户 → 选择CDN(north_telecom) → 输入路径(/image.jpg)
     → 后端拼接URL(https://cdn-north.example.com/image.jpg)
```

### 修改后

**通用类型**：
```
用户 → 输入完整URL(https://www.baidu.com)
     → 后端直接302跳转
```

**其他类型**：
```
用户 → 输入路径(/image.jpg)
     → 后端根据GEO/ISP选择CDN
     → 拼接URL(https://cdn-north.example.com/image.jpg)
     → 302跳转
```

## ✨ 优势

1. **用户体验**：简化了创建流程，不需要了解CDN配置
2. **智能分流**：后端可以根据实时信息动态选择最优CDN
3. **灵活性**：管理员可以在后端调整CDN策略，无需前端改动
4. **通用性**：general类型支持任意外部URL

## 📝 注意事项

1. **路径格式**：系统会自动在路径前添加 `/`
2. **URL验证**：general类型会验证URL格式是否正确
3. **固定策略**：前端固定使用 `weight` 策略（权重为1）
4. **缓存默认**：默认启用缓存

## 🚀 下一步

- [ ] 后端实现根据service_type自动选择CDN的逻辑
- [ ] 添加批量创建功能
- [ ] 支持导入CSV文件
- [ ] 增加创建预览功能
