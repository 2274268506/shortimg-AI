<template>
  <el-table :data="images" stripe>
    <el-table-column label="预览" width="80">
      <template #default="{ row }">
        <img
          v-lazy="getImageUrl(row)"
          class="table-thumbnail"
          @click="$emit('preview', row)"
        />
      </template>
    </el-table-column>
    <el-table-column prop="fileName" label="文件名" min-width="200" />
    <el-table-column label="尺寸" width="120">
      <template #default="{ row }">
        {{ row.width }} × {{ row.height }}
      </template>
    </el-table-column>
    <el-table-column label="大小" width="100">
      <template #default="{ row }">
        {{ formatFileSize(row.fileSize) }}
      </template>
    </el-table-column>
    <el-table-column label="访问" width="80">
      <template #default="{ row }">
        <el-tag type="success" size="small">{{ row.viewCount || 0 }}</el-tag>
      </template>
    </el-table-column>
    <el-table-column label="上传时间" width="180">
      <template #default="{ row }">
        {{ formatDate(row.createdAt) }}
      </template>
    </el-table-column>
    <el-table-column label="操作" width="350" fixed="right">
      <template #default="{ row }">
        <el-button
          :icon="View"
          size="small"
          @click="$emit('preview', row)"
        >
          预览
        </el-button>
        <el-dropdown @command="(cmd) => $emit('copyLink', row, cmd)" trigger="click">
          <el-button :icon="Link" size="small">
            复制 <el-icon class="el-icon--right"><arrow-down /></el-icon>
          </el-button>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="url">直接链接</el-dropdown-item>
              <el-dropdown-item command="markdown">Markdown</el-dropdown-item>
              <el-dropdown-item command="html">HTML</el-dropdown-item>
              <el-dropdown-item command="bbcode">BBCode</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
        <el-button
          :icon="Download"
          size="small"
          @click="$emit('download', row)"
        >
          下载
        </el-button>
        <el-button
          :icon="PriceTag"
          size="small"
          @click="$emit('editTags', row)"
        >
          标签
        </el-button>
        <el-button
          :icon="Edit"
          size="small"
          @click="$emit('edit', row)"
        >
          编辑
        </el-button>
        <el-button
          :icon="RefreshRight"
          size="small"
          @click="$emit('convert', row)"
        >
          转换
        </el-button>
        <el-popconfirm
          title="确定删除吗？"
          @confirm="$emit('delete', row.id)"
        >
          <template #reference>
            <el-button
              :icon="Delete"
              size="small"
              type="danger"
            >
              删除
            </el-button>
          </template>
        </el-popconfirm>
      </template>
    </el-table-column>
  </el-table>
</template>

<script setup>
import { View, Link, Download, Delete, ArrowDown, PriceTag, Edit, RefreshRight } from '@element-plus/icons-vue'

defineProps({
  images: {
    type: Array,
    required: true
  }
})

defineEmits(['preview', 'copyLink', 'download', 'delete', 'editTags', 'edit', 'convert'])

// 添加时间戳参数以避免缓存
const getImageUrl = (image) => {
  const timestamp = new Date(image.updatedAt).getTime()
  return `${image.url}?t=${timestamp}`
}

const formatFileSize = (bytes) => {
  if (!bytes) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
}

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  return date.toLocaleString('zh-CN')
}
</script>

<style scoped>
.table-thumbnail {
  width: 50px;
  height: 50px;
  object-fit: cover;
  border-radius: 4px;
  cursor: pointer;
  transition: opacity 0.3s;
}

/* 懒加载状态样式 */
.table-thumbnail.lazy-loading {
  opacity: 0.3;
}

.table-thumbnail.lazy-loaded {
  opacity: 1;
}

.table-thumbnail.lazy-error {
  opacity: 0.5;
}

/* 响应式设计 - 手机 */
@media (max-width: 768px) {
  :deep(.el-table) {
    font-size: 12px;
  }
  
  :deep(.el-table th),
  :deep(.el-table td) {
    padding: 8px 0;
  }
  
  :deep(.el-table .cell) {
    padding: 0 4px;
  }
  
  .table-thumbnail {
    width: 40px;
    height: 40px;
  }
}

/* 响应式设计 - 小屏手机 */
@media (max-width: 480px) {
  :deep(.el-table) {
    font-size: 11px;
  }
  
  :deep(.el-table th),
  :deep(.el-table td) {
    padding: 6px 0;
  }
  
  .table-thumbnail {
    width: 35px;
    height: 35px;
  }
  
  :deep(.el-button) {
    padding: 4px 8px;
    font-size: 11px;
  }
}
</style>
