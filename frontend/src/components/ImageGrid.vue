<template>
  <div class="image-grid">
    <div
      v-for="image in images"
      :key="image.id"
      class="image-card"
      @click="$emit('preview', image)"
    >
      <div class="image-wrapper">
        <img v-lazy="getImageUrl(image)" :alt="image.fileName" />
        <div class="image-overlay" @click.stop>
          <div class="overlay-row">
            <el-button
              :icon="View"
              circle
              size="small"
              @click="$emit('preview', image)"
              title="预览"
            />
            <el-dropdown
              @command="(cmd) => $emit('copyLink', image, cmd)"
              trigger="click"
            >
              <el-button :icon="Link" circle size="small" title="复制链接" />
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
              v-if="image.shortLinkUrl"
              :icon="Link"
              circle
              size="small"
              type="primary"
              @click="$emit('copyShortLink', image)"
              title="复制短链"
            />
            <el-button
              :icon="Download"
              circle
              size="small"
              @click="$emit('download', image)"
              title="下载"
            />
          </div>

          <div class="overlay-row">
            <el-button
              :icon="PriceTag"
              circle
              size="small"
              @click="$emit('editTags', image)"
              title="编辑标签"
            />
            <el-button
              :icon="Edit"
              circle
              size="small"
              @click="$emit('edit', image)"
              title="编辑图片"
            />
            <el-button
              :icon="RefreshRight"
              circle
              size="small"
              @click="$emit('convert', image)"
              title="格式转换"
            />
            <el-popconfirm
              title="确定删除此图片吗？"
              @confirm="$emit('delete', image.id)"
            >
              <template #reference>
                <el-button
                  :icon="Delete"
                  circle
                  size="small"
                  type="danger"
                  title="删除"
                />
              </template>
            </el-popconfirm>
          </div>
        </div>
      </div>
      <div class="image-info">
        <div class="image-name" :title="image.fileName">
          {{ image.fileName }}
        </div>
        <div class="image-tags" v-if="image.tags">
          <el-tag
            v-for="tag in parseTags(image.tags)"
            :key="tag"
            size="small"
            type="info"
            style="margin-right: 4px;"
          >
            {{ tag }}
          </el-tag>
        </div>
        <div class="image-meta">
          <span class="image-size">{{ formatFileSize(image.fileSize) }}</span>
          <span class="image-views" v-if="image.viewCount">
            <el-icon><View /></el-icon>
            {{ image.viewCount }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { View, Link, Download, Delete, PriceTag, Edit, RefreshRight } from '@element-plus/icons-vue'

defineProps({
  images: {
    type: Array,
    required: true
  }
})

defineEmits(['preview', 'copyLink', 'download', 'delete', 'editTags', 'edit', 'convert', 'copyShortLink'])

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

const parseTags = (tagsStr) => {
  if (!tagsStr) return []
  return tagsStr.split(',').map(t => t.trim()).filter(t => t).slice(0, 3) // 最多显示3个标签
}
</script>

<style scoped>
.image-grid {
  padding: 24px;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 20px;
  align-content: start;
}

.image-card {
  border-radius: 8px;
  overflow: hidden;
  background-color: #fff;
  border: 1px solid #e4e7ed;
  transition: all 0.3s;
  cursor: pointer;
  display: flex;
  flex-direction: column;
}

.image-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  transform: translateY(-2px);
}

.image-wrapper {
  position: relative;
  width: 100%;
  padding-top: 100%;
  background-color: #f5f7fa;
  overflow: hidden;
}

.image-wrapper img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: opacity 0.3s;
}

/* 懒加载状态样式 */
.image-wrapper img.lazy-loading {
  opacity: 0;
}

.image-wrapper img.lazy-loaded {
  opacity: 1;
}

.image-wrapper img.lazy-error {
  opacity: 0.5;
}

.image-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.65);
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  gap: 10px;
  padding: 12px;
  opacity: 0;
  transition: opacity 0.3s;
}

.overlay-row {
  display: flex;
  gap: 8px;
  align-items: center;
  justify-content: center;
}

.image-card:hover .image-overlay {
  opacity: 1;
}

.image-overlay .el-button {
  flex-shrink: 0;
  width: 32px;
  height: 32px;
}

.image-overlay .el-button.is-circle {
  padding: 8px;
}

.image-info {
  padding: 8px 10px;
  width: 100%;
  min-width: 0;
  box-sizing: border-box;
  flex-shrink: 0;
  overflow: hidden;
}

.image-name {
  font-size: 14px;
  color: #303133;
  margin-bottom: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  width: 100%;
}

.image-tags {
  margin-bottom: 6px;
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.image-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
}

.image-size {
  font-size: 12px;
  color: #909399;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex: 1;
  min-width: 0;
}

.image-views {
  font-size: 12px;
  color: #67C23A;
  display: flex;
  align-items: center;
  gap: 2px;
  white-space: nowrap;
  flex-shrink: 0;
}

.image-views .el-icon {
  font-size: 14px;
}

/* 响应式设计 - 平板 */
@media (max-width: 1024px) {
  .image-grid {
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 16px;
    padding: 16px;
  }

  .image-card {
    max-width: none;
  }
}

/* 响应式设计 - 手机 */
@media (max-width: 768px) {
  .image-grid {
    grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
    gap: 12px;
    padding: 12px;
  }

  .image-wrapper {
    height: 140px;
  }

  .image-info {
    padding: 6px 8px;
  }

  .image-name {
    font-size: 12px;
  }

  .image-meta {
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
  }

  .image-size,
  .image-views {
    font-size: 11px;
  }

  /* 移动端简化悬停操作 */
  .image-overlay {
    opacity: 1;
    background: linear-gradient(to bottom, rgba(0,0,0,0) 0%, rgba(0,0,0,0.6) 100%);
    padding: 8px;
  }

  .overlay-row {
    gap: 4px;
  }

  .image-overlay .el-button {
    width: 28px;
    height: 28px;
    padding: 6px;
  }
}

/* 响应式设计 - 小屏手机 */
@media (max-width: 480px) {
  .image-grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 8px;
    padding: 8px;
  }

  .image-wrapper {
    height: 120px;
  }

  .image-info {
    padding: 4px 6px;
  }

  .image-name {
    font-size: 11px;
  }

  .image-tags {
    display: none;
  }

  .image-meta {
    font-size: 10px;
  }

  /* 移动端只显示最重要的按钮 */
  .overlay-row:first-child {
    display: flex;
  }

  .overlay-row:last-child {
    display: none;
  }

  .image-overlay .el-button {
    width: 24px;
    height: 24px;
    padding: 4px;
  }
}
</style>
