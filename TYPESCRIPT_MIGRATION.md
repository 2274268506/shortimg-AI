# TypeScript 迁移指南

## ✅ 已完成的迁移

### 1. 基础配置
- ✅ 安装 TypeScript 依赖：`typescript`, `vue-tsc`, `@types/node`
- ✅ 创建 `tsconfig.json` - TypeScript 主配置
- ✅ 创建 `tsconfig.node.json` - Node 配置
- ✅ 创建 `src/env.d.ts` - Vue 模块声明
- ✅ 更新 `vite.config.js` → `vite.config.ts`
- ✅ 更新 `package.json` 添加类型检查脚本

### 2. 核心文件迁移
- ✅ `src/main.js` → `src/main.ts`
- ✅ `src/utils/request.js` → `src/utils/request.ts`
- ✅ `src/api/index.js` → `src/api/index.ts`
- ✅ `src/router/index.js` → `src/router/index.ts`
- ✅ `src/stores/image.ts` (已有，添加类型)

### 3. 类型定义
创建了 `src/types/index.ts`，包含：
- `Album` - 相册接口
- `Image` - 图片接口
- `Statistics` - 统计数据接口
- `ApiResponse<T>` - API 响应泛型
- `PaginatedResponse<T>` - 分页响应泛型

## 🔧 需要手动完成的迁移

### Vue 组件迁移

所有 `.vue` 文件需要添加 `<script setup lang="ts">`：

#### 1. App.vue
```vue
<script setup lang="ts">
// 现有代码保持不变
</script>
```

#### 2. 视图组件
- `src/views/ImageManager.vue`
- `src/views/Statistics.vue`

示例:
```vue
<script setup lang="ts">
import { ref, onMounted } from 'vue'
import type { Image } from '@/types'

const images = ref<Image[]>([])
const loading = ref<boolean>(false)

onMounted(async () => {
  // 代码...
})
</script>
```

#### 3. 组件
- `src/components/AlbumSidebar.vue`
- `src/components/AlbumDialog.vue`
- `src/components/ImageGrid.vue`
- `src/components/ImageList.vue`
- `src/components/ImageUpload.vue`
- `src/components/ImagePreview.vue`
- `src/components/TagEditor.vue`

### Store 剩余部分

修复 `src/stores/image.ts` 中的类型错误：

```typescript
// 修复 API 响应访问
const res = await api.getAlbums()
albums.value = (res as any).data || []  // 临时 fix

// 或者更新 axios 拦截器返回完整响应
```

## 📝 运行命令

```bash
# 开发模式
npm run dev

# 类型检查
npm run type-check

# 构建（包含类型检查）
npm run build
```

## ⚠️ 已知问题

1. **API 响应类型不匹配**
   - 原因：axios 拦截器直接返回 `response.data`
   - 解决方案：更新拦截器或调整类型定义

2. **Store 函数参数类型**
   - 需要为所有函数添加参数类型
   - 例如：`uploadImage(file: File, albumId: number)`

## 🎯 下一步

1. 为所有 Vue 组件添加 `lang="ts"`
2. 为组件 props/emits 添加类型定义
3. 修复 store 中的类型错误
4. 运行 `npm run type-check` 检查所有错误
5. 逐个修复类型错误

## 💡 最佳实践

1. **使用泛型**
   ```typescript
   const data = ref<Image[]>([])
   ```

2. **定义接口**
   ```typescript
   interface Props {
     image: Image
     size?: 'small' | 'medium' | 'large'
   }
   ```

3. **类型断言**
   ```typescript
   const value = data as Image
   ```

4. **可选链**
   ```typescript
   const name = user?.profile?.name
   ```

## 🔗 相关资源

- [Vue 3 + TypeScript 文档](https://vuejs.org/guide/typescript/overview.html)
- [Pinia TypeScript 支持](https://pinia.vuejs.org/cookbook/composables.html)
- [Vite TypeScript 配置](https://vitejs.dev/guide/features.html#typescript)
