# 🐛 Bug 修复：预览对话框错误

## 问题描述
用户反馈：查看按钮无法大图查看

## 错误信息
```
Uncaught (in promise) TypeError: can't access property "location", _ctx.window is undefined
```

## 问题原因

### 问题 1: 图标组件名称错误
在 `ImagePreviewDialog.vue` 组件中，下拉按钮的图标组件名称写错了：
- ❌ 错误: `<arrow-down />`
- ✅ 正确: `<ArrowDown />`

### 问题 2: 模板中直接使用 window 对象 ⭐ 主要问题
在 Vue 3 的模板中，直接使用 `window.location.origin` 会导致错误，因为 `window` 对象在模板上下文中不会自动可用。

**错误代码:**
```vue
<el-input 
  :model-value="image?.url ? (window.location.origin + image.url) : ''"
  readonly
/>
```

**正确做法:**
需要在 `<script setup>` 中创建一个计算属性来访问 `window` 对象：
```vue
const fullImageUrl = computed(() => {
  return props.image?.url ? (window.location.origin + props.image.url) : ''
})
```

然后在模板中使用这个计算属性：
```vue
<el-input 
  :model-value="fullImageUrl"
  readonly
/>
```

## 修复内容

### 修改文件
`frontend/src/components/ImagePreviewDialog.vue`

### 修改 1: 修复图标组件名称
```vue
<!-- 修复前 -->
<el-icon class="el-icon--right"><arrow-down /></el-icon>

<!-- 修复后 -->
<el-icon class="el-icon--right"><ArrowDown /></el-icon>
```

### 修改 2: 添加计算属性访问 window 对象
```javascript
// 在 <script setup> 中添加
const fullImageUrl = computed(() => {
  return props.image?.url ? (window.location.origin + props.image.url) : ''
})
```

### 修改 3: 更新模板使用计算属性
```vue
<!-- 修复前 -->
<el-input 
  :model-value="image?.url ? (window.location.origin + image.url) : ''"
  readonly
/>

<!-- 修复后 -->
<el-input 
  :model-value="fullImageUrl"
  readonly
/>
```

## 测试步骤

1. **启动前端开发服务器**
   ```bash
   cd frontend
   npm run dev
   ```

2. **测试预览功能**
   - 打开浏览器访问 http://localhost:5173
   - 选择一个相册
   - 点击任意图片的"查看"按钮（眼睛图标）
   - 验证预览对话框是否正常打开
   - 检查预览对话框中的大图是否正常显示

3. **测试预览对话框的所有功能**
   - ✅ 大图正常显示
   - ✅ 图片详情正确显示
   - ✅ 复制链接下拉菜单正常（包括图标）
   - ✅ 下载按钮正常工作
   - ✅ 关闭按钮正常工作

## 相关文件
- `frontend/src/components/ImagePreviewDialog.vue` - 预览对话框组件
- `frontend/src/views/ImageManager.vue` - 主页面（调用预览功能）
- `frontend/src/components/ImageGrid.vue` - 网格视图（触发预览）
- `frontend/src/components/ImageList.vue` - 列表视图（触发预览）

## 验证结果
✅ 构建测试通过
✅ 无语法错误
✅ 所有组件正常

## 修复时间
2025年12月3日

## 额外说明
这是重构后发现的一个小问题，已经修复。所有预览功能应该恢复正常。
