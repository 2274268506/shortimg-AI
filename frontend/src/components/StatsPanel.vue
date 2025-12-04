<template>
  <div v-if="currentAlbum && !loading" class="stats-panel">
    <div class="stat-item">
      <el-icon class="stat-icon"><Picture /></el-icon>
      <div class="stat-content">
        <div class="stat-label">图片总数</div>
        <div class="stat-value">{{ imageCount }}</div>
      </div>
    </div>
    <div class="stat-item">
      <el-icon class="stat-icon"><Document /></el-icon>
      <div class="stat-content">
        <div class="stat-label">总大小</div>
        <div class="stat-value">{{ totalSize }}</div>
      </div>
    </div>
    <div class="stat-item">
      <el-icon class="stat-icon"><Collection /></el-icon>
      <div class="stat-content">
        <div class="stat-label">当前相册</div>
        <div class="stat-value">{{ currentAlbum.name }}</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { Picture, Document, Collection } from '@element-plus/icons-vue'

defineProps({
  currentAlbum: {
    type: Object,
    default: null
  },
  loading: {
    type: Boolean,
    default: false
  },
  imageCount: {
    type: Number,
    default: 0
  },
  totalSize: {
    type: String,
    default: '0 B'
  }
})
</script>

<style scoped>
.stats-panel {
  display: flex;
  gap: 16px;
  padding: 16px 24px;
  background-color: #f5f7fa;
  border-bottom: 1px solid #e4e7ed;
  flex-shrink: 0;
}

.stat-item {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  background-color: #fff;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.04);
  flex: 1;
}

.stat-icon {
  font-size: 32px;
  color: #409eff;
  margin-right: 12px;
}

.stat-content {
  flex: 1;
}

.stat-label {
  font-size: 12px;
  color: #909399;
  margin-bottom: 4px;
}

.stat-value {
  font-size: 18px;
  font-weight: 600;
  color: #303133;
}
</style>
