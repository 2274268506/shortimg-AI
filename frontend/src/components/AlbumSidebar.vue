<template>
  <div class="sidebar">
    <div class="sidebar-header">
      <h3>相册列表</h3>
    </div>
    <div class="album-list">
      <div
        v-for="album in albums"
        :key="album.id"
        class="album-item"
        :class="{ active: currentAlbum?.id === album.id }"
        @click="$emit('selectAlbum', album)"
      >
        <div class="album-icon">
          <el-icon><Folder /></el-icon>
        </div>
        <div class="album-info">
          <div class="album-name-wrapper">
            <span class="album-name">{{ album.name }}</span>
            <el-icon 
              v-if="album.isPrivate" 
              class="privacy-icon private" 
              title="私有相册"
            >
              <Lock />
            </el-icon>
            <el-icon 
              v-else-if="!album.isPublic && album.sharedUsers" 
              class="privacy-icon shared" 
              title="共享相册"
            >
              <Share />
            </el-icon>
          </div>
          <div class="album-count">{{ album.imageCount || 0 }} 张图片</div>
        </div>
        <div class="album-actions" v-if="album.id !== 1">
          <el-button
            :icon="Edit"
            size="small"
            link
            @click.stop="$emit('editAlbum', album)"
            title="编辑相册"
          />
          <el-popconfirm
            title="确定删除此相册吗？"
            @confirm="$emit('deleteAlbum', album.id)"
          >
            <template #reference>
              <el-button
                :icon="Delete"
                type="danger"
                size="small"
                link
                @click.stop
              />
            </template>
          </el-popconfirm>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { Folder, Edit, Delete, Lock, Share } from '@element-plus/icons-vue'

defineProps({
  albums: {
    type: Array,
    required: true
  },
  currentAlbum: {
    type: Object,
    default: null
  }
})

defineEmits(['selectAlbum', 'editAlbum', 'deleteAlbum'])
</script>

<style scoped>
.sidebar {
  width: 280px;
  min-width: 280px;
  background-color: #fff;
  border-right: 1px solid #e4e7ed;
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  flex-shrink: 0;
}

.sidebar-header {
  padding: 16px 20px;
  border-bottom: 1px solid #e4e7ed;
  flex-shrink: 0;
}

.sidebar-header h3 {
  font-size: 16px;
  font-weight: 600;
  color: #303133;
  margin: 0;
}

.album-list {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 8px;
}

/* 滚动条样式 */
.album-list::-webkit-scrollbar {
  width: 6px;
}

.album-list::-webkit-scrollbar-thumb {
  background-color: #dcdfe6;
  border-radius: 3px;
}

.album-list::-webkit-scrollbar-thumb:hover {
  background-color: #c0c4cc;
}

.album-list::-webkit-scrollbar-track {
  background-color: transparent;
}

.album-item {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  margin-bottom: 4px;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.3s;
  min-height: 60px;
}

.album-item:hover {
  background-color: #f5f7fa;
}

.album-item.active {
  background-color: #ecf5ff;
  color: #409eff;
}

.album-icon {
  font-size: 24px;
  margin-right: 12px;
}

.album-info {
  flex: 1;
  min-width: 0;
}

.album-name-wrapper {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 4px;
}

.album-name {
  font-size: 14px;
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex: 1;
  min-width: 0;
}

.privacy-icon {
  font-size: 14px;
  flex-shrink: 0;
}

.privacy-icon.private {
  color: #f56c6c;
}

.privacy-icon.shared {
  color: #e6a23c;
}

.album-count {
  font-size: 12px;
  color: #909399;
}

.album-actions {
  opacity: 0;
  transition: opacity 0.3s;
}

.album-item:hover .album-actions {
  opacity: 1;
}

/* 响应式设计 - 平板 */
@media (max-width: 1024px) {
  .sidebar {
    width: 240px;
    min-width: 240px;
  }
  
  .sidebar-header {
    padding: 12px 16px;
  }
  
  .sidebar-header h3 {
    font-size: 15px;
  }
  
  .album-item {
    padding: 10px 12px;
  }
  
  .album-name {
    font-size: 13px;
  }
  
  .album-count {
    font-size: 11px;
  }
}

/* 响应式设计 - 手机 */
@media (max-width: 768px) {
  .sidebar {
    position: fixed;
    left: 0;
    top: 0;
    bottom: 0;
    width: 280px;
    z-index: 1000;
    transform: translateX(-100%);
    transition: transform 0.3s ease;
    box-shadow: 2px 0 8px rgba(0, 0, 0, 0.15);
  }
  
  .sidebar.mobile-open {
    transform: translateX(0);
  }
  
  .album-list {
    padding: 4px;
  }
  
  .album-item {
    padding: 12px;
  }
  
  /* 移动端始终显示操作按钮 */
  .album-actions {
    opacity: 1;
  }
}

/* 响应式设计 - 小屏手机 */
@media (max-width: 480px) {
  .sidebar {
    width: 240px;
  }
  
  .sidebar-header {
    padding: 10px 12px;
  }
  
  .sidebar-header h3 {
    font-size: 14px;
  }
  
  .album-item {
    padding: 10px;
  }
  
  .album-name {
    font-size: 12px;
  }
  
  .album-count {
    font-size: 10px;
  }
  
  .album-icon {
    font-size: 18px;
  }
}
</style>
