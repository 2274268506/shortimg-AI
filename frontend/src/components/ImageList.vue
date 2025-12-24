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
    <el-table-column label="文件名" min-width="200">
      <template #default="{ row }">
        <span :title="row.fileName">{{ row.originalName || row.fileName }}</span>
      </template>
    </el-table-column>
    <el-table-column label="尺寸" width="120">
      <template #default="{ row }">
        {{ row.width }} × {{ row.height }}
      </template>
    </el-table-column>
    <el-table-column v-if="displaySettings.showFileSize" label="大小" width="100">
      <template #default="{ row }">
        {{ formatFileSize(row.fileSize) }}
      </template>
    </el-table-column>
    <el-table-column label="访问" width="80">
      <template #default="{ row }">
        <el-tag type="success" size="small">{{ row.viewCount || 0 }}</el-tag>
      </template>
    </el-table-column>
    <el-table-column label="短链" width="120">
      <template #default="{ row }">
        <el-button
          v-if="row.shortLinkUrl"
          :icon="Link"
          size="small"
          type="primary"
          plain
          @click="$emit('copyShortLink', row)"
          title="复制短链"
        >
          复制短链
        </el-button>
        <el-tag v-else type="info" size="small" effect="plain">
          无短链
        </el-tag>
      </template>
    </el-table-column>
    <el-table-column v-if="displaySettings.showUploadDate" label="上传时间" width="180">
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
import { Link, View, Download, Delete, Edit, Refresh, MagicStick } from '@element-plus/icons-vue'
import { computed } from 'vue'

defineProps({
  images: {
    type: Array,
    required: true
  }
})

defineEmits(['preview', 'copyLink', 'download', 'delete', 'editTags', 'edit', 'convert', 'copyShortLink'])

// 加载显示设置
const loadDisplaySettings = () => {
  const settings = localStorage.getItem('display-settings')
  return settings ? JSON.parse(settings) : {
    showFileSize: true,
    showUploadDate: true,
    thumbnailQuality: 80
  }
}

const displaySettings = computed(() => loadDisplaySettings())

// 添加时间戳参数以避免缓存
const getImageUrl = (image) => {
  const timestamp = new Date(image.updatedAt).getTime()
  const quality = displaySettings.value.thumbnailQuality || 80

  // 如果图片有缩略图，使用缩略图API，并添加质量参数
  if (image.thumbnail) {
    return `/api/images/${image.id}/thumbnail?quality=${quality}&t=${timestamp}`
  }

  // 没有缩略图则使用原图
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
  const now = new Date()
  const diff = now - date
  const days = Math.floor(diff / (1000 * 60 * 60 * 24))

  if (days === 0) {
    const hours = Math.floor(diff / (1000 * 60 * 60))
    if (hours === 0) {
      const minutes = Math.floor(diff / (1000 * 60))
      return minutes === 0 ? '刚刚' : `${minutes}分钟前`
    }
    return `${hours}小时前`
  } else if (days === 1) {
    return '昨天'
  } else if (days < 7) {
    return `${days}天前`
  } else {
    return date.toLocaleDateString('zh-CN')
  }
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
