<template>
  <div class="image-manager">
    <!-- 顶部工具栏 -->
    <ImageToolbar 
      @upload="showUploadDialog = true"
      @createAlbum="handleShowCreateAlbum"
    />

    <!-- 主要内容区域 -->
    <div class="content">
      <!-- 移动端侧边栏遮罩 -->
      <div 
        v-if="showMobileSidebar" 
        class="sidebar-overlay"
        @click="showMobileSidebar = false"
      ></div>
      
      <!-- 左侧相册列表 -->
      <AlbumSidebar
        :class="{ 'mobile-open': showMobileSidebar }"
        :albums="albums"
        :current-album="currentAlbum"
        @selectAlbum="handleSelectAlbum"
        @editAlbum="handleEditAlbum"
        @deleteAlbum="handleDeleteAlbum"
      />

      <!-- 右侧图片列表 -->
      <div 
        class="main-content"
        @drop.prevent="handleDrop"
        @dragover.prevent="handleDragOver"
        @dragleave.prevent="handleDragLeave"
        :class="{ 'drag-over': isDragging }"
      >
        <!-- 拖拽上传提示层 -->
        <div v-if="isDragging" class="drag-overlay">
          <div class="drag-hint">
            <el-icon class="drag-icon"><Upload /></el-icon>
            <div class="drag-text">释放以上传图片到当前相册</div>
          </div>
        </div>

        <!-- 内容头部 -->
        <div class="content-header">
          <div class="header-left">
            <el-button 
              class="mobile-menu-btn"
              :icon="Menu" 
              circle 
              @click="showMobileSidebar = !showMobileSidebar"
            />
            <h2>{{ currentAlbum?.name || '未选择相册' }}</h2>
          </div>
          <div class="header-actions">
            <el-select 
              v-model="sortByValue" 
              placeholder="排序方式" 
              style="width: 140px; margin-right: 12px;"
              @change="handleSortChange"
            >
              <el-option label="上传时间 ↓" value="time-desc" />
              <el-option label="上传时间 ↑" value="time-asc" />
              <el-option label="访问次数 ↓" value="views-desc" />
              <el-option label="访问次数 ↑" value="views-asc" />
              <el-option label="文件名 A-Z" value="name-asc" />
              <el-option label="文件名 Z-A" value="name-desc" />
              <el-option label="文件大小 ↓" value="size-desc" />
              <el-option label="文件大小 ↑" value="size-asc" />
            </el-select>
            <el-input
              v-model="searchKeyword"
              placeholder="搜索图片..."
              :prefix-icon="Search"
              clearable
              @input="handleSearch"
              style="width: 200px; margin-right: 12px;"
            />
            <el-select
              v-model="selectedTag"
              placeholder="按标签筛选"
              clearable
              filterable
              style="width: 150px; margin-right: 12px;"
              @change="handleTagFilter"
            >
              <el-option
                v-for="tag in availableTags"
                :key="tag"
                :label="tag"
                :value="tag"
              >
                <span>{{ tag }}</span>
                <span style="float: right; color: var(--el-text-color-secondary); font-size: 13px">
                  {{ getTagCount(tag) }}
                </span>
              </el-option>
            </el-select>
            <el-radio-group v-model="viewMode" size="small">
              <el-radio-button value="grid">
                <el-icon><Grid /></el-icon>
                网格
              </el-radio-button>
              <el-radio-button value="list">
                <el-icon><List /></el-icon>
                列表
              </el-radio-button>
            </el-radio-group>
          </div>
        </div>

        <!-- 统计信息面板 -->
        <StatsPanel
          :current-album="currentAlbum"
          :loading="loading"
          :image-count="images.length"
          :total-size="totalSize"
        />

        <!-- 内容滚动区域 -->
        <div class="content-scroll-area">
          <!-- 加载状态 -->
          <div v-if="loading" class="loading-container">
            <el-icon class="is-loading" :size="40"><Loading /></el-icon>
          </div>

          <!-- 网格视图 -->
          <ImageGrid
            v-if="viewMode === 'grid' && !loading"
            :images="images"
            @preview="previewImage"
            @copyLink="copyImageLink"
            @download="downloadImage"
            @delete="handleDeleteImage"
            @editTags="handleEditTags"
            @edit="handleEdit"
            @convert="handleConvert"
          />

          <!-- 列表视图 -->
          <ImageList
            v-if="viewMode === 'list' && !loading"
            :images="images"
            @preview="previewImage"
            @copyLink="copyImageLink"
            @download="downloadImage"
            @delete="handleDeleteImage"
            @editTags="handleEditTags"
            @edit="handleEdit"
            @convert="handleConvert"
          />

          <!-- 分页 / 加载更多 -->
          <div class="load-more" v-if="images.length > 0 && !loading">
            <el-button
              type="primary"
              plain
              @click="handleLoadMore"
              :disabled="images.length >= store.total"
            >
              {{ images.length >= store.total ? '已全部加载' : '加载更多' }}
            </el-button>
          </div>

          <!-- 空状态 -->
          <el-empty
            v-if="!loading && images.length === 0"
            description="暂无图片，点击上传按钮添加图片"
          />
        </div>
      </div>
    </div>

    <!-- 上传对话框 -->
    <UploadDialog
      v-model="showUploadDialog"
      :albums="albums"
      :default-album-id="uploadAlbumId"
      :uploading="uploading"
      :upload-progress="uploadProgress"
      :upload-status="uploadStatus"
      :upload-message="uploadMessage"
      @upload="handleUpload"
    />

    <!-- 创建/编辑相册对话框 -->
    <AlbumDialog
      v-model="showAlbumDialog"
      :is-edit="isEditAlbum"
      :album="editingAlbum"
      @submit="handleAlbumSubmit"
    />

    <!-- 图片预览对话框 -->
    <ImagePreviewDialog
      v-model="showPreviewDialog"
      :image="previewImageData"
      @copyLink="copyImageLink"
      @download="downloadImage"
    />

    <!-- 标签编辑对话框 -->
    <TagEditor
      v-model="showTagEditor"
      :image="editingImage"
      @updated="handleTagsUpdated"
    />

    <!-- 图片编辑对话框 -->
    <ImageEditor
      v-if="editingImage"
      v-model="showImageEditor"
      :image="editingImage"
      @save="handleImageEditorSave"
    />

    <!-- 格式转换对话框 -->
    <FormatConverter
      v-model="showFormatConverter"
      :image="convertingImage"
      :selected-images="selectedImages"
      @converted="handleFormatConverted"
    />
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useImageStore } from '@/stores/image'
import * as api from '@/api'
import { ElMessage } from 'element-plus'
import {
  Upload,
  Search,
  Grid,
  List,
  Loading,
  Menu
} from '@element-plus/icons-vue'
import { useImageOperations } from '@/composables/useImageOperations'
import ImageToolbar from '@/components/ImageToolbar.vue'
import AlbumSidebar from '@/components/AlbumSidebar.vue'
import StatsPanel from '@/components/StatsPanel.vue'
import ImageGrid from '@/components/ImageGrid.vue'
import ImageList from '@/components/ImageList.vue'
import UploadDialog from '@/components/UploadDialog.vue'
import AlbumDialog from '@/components/AlbumDialog.vue'
import ImagePreviewDialog from '@/components/ImagePreviewDialog.vue'
import TagEditor from '@/components/TagEditor.vue'
import ImageEditor from '@/components/ImageEditor.vue'
import FormatConverter from '@/components/FormatConverter.vue'

const store = useImageStore()
const { copyImageLink, downloadImage, formatFileSize } = useImageOperations()

// Computed properties
const albums = computed(() => store.albums)
const currentAlbum = computed(() => store.currentAlbum)
const images = computed(() => store.images)
const loading = computed(() => store.loading)

const totalSize = computed(() => {
  if (!images.value || images.value.length === 0) return '0 B'
  const total = images.value.reduce((sum, img) => sum + (img.fileSize || 0), 0)
  return formatFileSize(total)
})

// State
const viewMode = ref('grid')
const searchKeyword = ref('')
const selectedTag = ref('')
const sortByValue = ref('time-desc')
const isDragging = ref(false)
const showUploadDialog = ref(false)
const showAlbumDialog = ref(false)
const showPreviewDialog = ref(false)
const uploading = ref(false)
const uploadProgress = ref(0)
const uploadStatus = ref('')
const uploadMessage = ref('')
const uploadAlbumId = ref(1)
const isEditAlbum = ref(false)
const editingAlbum = ref(null)
const previewImageData = ref(null)
const showTagEditor = ref(false)
const editingImage = ref(null)
const showImageEditor = ref(false)
const showMobileSidebar = ref(false)
const showFormatConverter = ref(false)
const convertingImage = ref(null)
const selectedImages = ref([])

// 可用标签列表
const availableTags = computed(() => {
  const tagSet = new Set()
  images.value.forEach(img => {
    if (img.tags) {
      img.tags.split(',').forEach(tag => {
        const trimmed = tag.trim()
        if (trimmed) tagSet.add(trimmed)
      })
    }
  })
  return Array.from(tagSet).sort()
})

// 获取标签的图片数量
const getTagCount = (tag) => {
  return images.value.filter(img => {
    if (!img.tags) return false
    const tags = img.tags.split(',').map(t => t.trim())
    return tags.includes(tag)
  }).length
}

// Lifecycle
onMounted(async () => {
  console.log('ImageManager mounted')
  await store.loadAlbums()
  console.log('相册加载完成，当前相册:', store.currentAlbum)
  if (store.currentAlbum) {
    console.log('开始加载相册图片，ID:', store.currentAlbum.id)
    await store.loadImages(store.currentAlbum.id)
    console.log('图片加载完成，数量:', store.images.length)
  } else {
    console.log('没有当前相册')
  }
})

// Album operations
const selectAlbum = async (album) => {
  store.currentAlbum = album
  searchKeyword.value = ''
  await store.loadImages(album.id)
}

// 移动端选择相册后关闭侧边栏
const handleSelectAlbum = async (album) => {
  await selectAlbum(album)
  showMobileSidebar.value = false
}

const handleShowCreateAlbum = () => {
  isEditAlbum.value = false
  editingAlbum.value = null
  showAlbumDialog.value = true
}

const handleEditAlbum = (album) => {
  isEditAlbum.value = true
  editingAlbum.value = album
  showAlbumDialog.value = true
}

const handleAlbumSubmit = async (formData) => {
  if (!formData.name) {
    ElMessage.warning('请输入相册名称')
    return
  }

  try {
    if (isEditAlbum.value) {
      await store.updateAlbum(formData.id, {
        name: formData.name,
        description: formData.description,
        isPrivate: formData.isPrivate,
        isPublic: formData.isPublic,
        allowShare: formData.allowShare,
        sharedUsers: formData.sharedUsers
      })
      ElMessage.success('更新成功')
    } else {
      await store.createAlbum(formData)
      ElMessage.success('创建成功')
    }
    showAlbumDialog.value = false
    await store.loadAlbums()
  } catch (error) {
    ElMessage.error(isEditAlbum.value ? '更新失败' : '创建失败')
  }
}

const handleDeleteAlbum = async (id) => {
  try {
    await store.removeAlbum(id)
    ElMessage.success('删除成功')
    if (currentAlbum.value?.id === id && albums.value.length > 0) {
      await selectAlbum(albums.value[0])
    }
  } catch (error) {
    ElMessage.error('删除失败')
  }
}

// Search and sort
const handleSearch = async () => {
  if (currentAlbum.value) {
    await store.loadImages(currentAlbum.value.id, searchKeyword.value)
  }
}

// 标签筛选
const handleTagFilter = async () => {
  if (!currentAlbum.value) return
  
  if (selectedTag.value) {
    // 使用标签搜索 API
    try {
      const res = await api.searchImagesByTag(selectedTag.value, currentAlbum.value.id)
      store.images = res.data || []
      store.total = res.total || 0
    } catch (error) {
      console.error('标签筛选失败:', error)
      ElMessage.error('标签筛选失败')
    }
  } else {
    // 清空标签筛选，重新加载
    await store.loadImages(currentAlbum.value.id, searchKeyword.value)
  }
}

const handleSortChange = async () => {
  const parts = sortByValue.value.split('-')
  store.sortBy = parts[0]
  store.order = parts[1]
  
  if (currentAlbum.value) {
    await store.loadImages(currentAlbum.value.id, searchKeyword.value)
  }
}

// Upload operations
const handleUpload = async ({ albumId, files }) => {
  if (files.length === 0) {
    ElMessage.warning('请选择要上传的图片')
    return
  }

  uploading.value = true
  uploadProgress.value = 0
  uploadStatus.value = ''
  const totalFiles = files.length
  
  try {
    uploadMessage.value = `准备上传 ${totalFiles} 个文件...`
    uploadProgress.value = 10
    
    uploadMessage.value = `正在上传 ${totalFiles} 个文件...`
    uploadProgress.value = 30
    
    await store.batchUploadImages(files, albumId)
    
    uploadProgress.value = 100
    uploadStatus.value = 'success'
    uploadMessage.value = `成功上传 ${totalFiles} 个文件`
    
    setTimeout(() => {
      ElMessage.success('上传成功')
      showUploadDialog.value = false
      uploadProgress.value = 0
      uploadStatus.value = ''
      uploadMessage.value = ''
    }, 1000)
    
    if (albumId === currentAlbum.value?.id) {
      await store.loadImages(currentAlbum.value.id)
    }
    await store.loadAlbums()
  } catch (error) {
    uploadStatus.value = 'exception'
    uploadMessage.value = '上传失败'
    ElMessage.error('上传失败')
  } finally {
    setTimeout(() => {
      uploading.value = false
    }, 1500)
  }
}

// Drag and drop
const handleDragOver = (e) => {
  if (!currentAlbum.value) return
  isDragging.value = true
}

const handleDragLeave = (e) => {
  if (e.target.classList.contains('main-content')) {
    isDragging.value = false
  }
}

const handleDrop = async (e) => {
  isDragging.value = false
  
  if (!currentAlbum.value) {
    ElMessage.warning('请先选择相册')
    return
  }

  const files = Array.from(e.dataTransfer.files).filter(file => 
    file.type.startsWith('image/')
  )

  if (files.length === 0) {
    ElMessage.warning('请拖拽图片文件')
    return
  }

  uploadAlbumId.value = currentAlbum.value.id
  
  uploading.value = true
  uploadProgress.value = 0
  uploadStatus.value = 'uploading'
  uploadMessage.value = `正在上传 ${files.length} 张图片...`

  try {
    let successCount = 0
    for (let i = 0; i < files.length; i++) {
      const formData = new FormData()
      formData.append('file', files[i])
      formData.append('albumId', uploadAlbumId.value)

      try {
        await store.uploadImage(formData)
        successCount++
        uploadProgress.value = Math.round(((i + 1) / files.length) * 100)
      } catch (error) {
        console.error(`上传失败: ${files[i].name}`, error)
      }
    }

    uploadStatus.value = 'success'
    uploadMessage.value = `成功上传 ${successCount}/${files.length} 张图片`
    
    if (successCount > 0) {
      await store.loadImages(uploadAlbumId.value, searchKeyword.value)
      await store.loadAlbums()
      ElMessage.success(`成功上传 ${successCount} 张图片`)
    }
    
    setTimeout(() => {
      uploading.value = false
      uploadProgress.value = 0
    }, 2000)
  } catch (error) {
    uploadStatus.value = 'error'
    uploadMessage.value = '上传失败'
    ElMessage.error('上传失败')
    setTimeout(() => {
      uploading.value = false
    }, 2000)
  }
}

// Image operations
const handleDeleteImage = async (id) => {
  try {
    await store.removeImage(id, currentAlbum.value.id)
    ElMessage.success('删除成功')
    await store.loadAlbums()
  } catch (error) {
    ElMessage.error('删除失败')
  }
}

const handleLoadMore = async () => {
  if (!currentAlbum.value) return
  await store.loadMoreImages(currentAlbum.value.id, searchKeyword.value)
}

const previewImage = (image) => {
  previewImageData.value = image
  showPreviewDialog.value = true
}

const handleEditTags = (image) => {
  editingImage.value = image
  showTagEditor.value = true
}

const handleTagsUpdated = async (tags) => {
  // 更新当前图片的标签
  if (editingImage.value) {
    editingImage.value.tags = tags
  }
  // 重新加载图片列表以获取最新数据
  await store.loadImages(currentAlbum.value.id, searchKeyword.value)
}

const handleEdit = (image) => {
  editingImage.value = image
  showImageEditor.value = true
}

const handleImageEditorSave = async ({ type, data }) => {
  try {
    if (type === 'rename') {
      await api.renameImage(editingImage.value.id, data.newFileName)
      ElMessage.success('重命名成功')
    } else if (type === 'crop' || type === 'filter') {
      await api.updateImageFile(editingImage.value.id, data.blob)
      ElMessage.success('图片已更新')
    }
    
    // 重新加载图片列表
    await store.loadImages(currentAlbum.value.id, searchKeyword.value)
    showImageEditor.value = false
  } catch (error) {
    ElMessage.error('操作失败: ' + (error.message || '未知错误'))
  }
}

// 格式转换
const handleConvert = (image) => {
  convertingImage.value = image
  selectedImages.value = [] // 单张转换时清空批量选择
  showFormatConverter.value = true
}

const handleFormatConverted = async (convertedData) => {
  // 重新加载图片列表以显示转换后的图片
  await store.loadImages(currentAlbum.value.id, searchKeyword.value)
  await store.loadAlbums() // 刷新相册统计信息
  
  // 清空状态
  convertingImage.value = null
  selectedImages.value = []
}

</script>

<style scoped>
.image-manager {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background-color: #f5f7fa;
}

.content {
  display: flex;
  flex: 1;
  overflow: hidden;
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background-color: #fff;
  position: relative;
  transition: background-color 0.3s;
  min-height: 0;
}

.main-content.drag-over {
  background-color: #f0f9ff;
  border: 2px dashed #409eff;
}

.drag-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(64, 158, 255, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  pointer-events: none;
}

.drag-hint {
  text-align: center;
  padding: 40px;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.drag-icon {
  font-size: 64px;
  color: #409eff;
  margin-bottom: 16px;
}

.drag-text {
  font-size: 18px;
  color: #409eff;
  font-weight: 500;
}

.content-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 24px;
  border-bottom: 1px solid #e4e7ed;
  flex-shrink: 0;
  flex-wrap: wrap;
  gap: 12px;
}

.content-scroll-area {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

/* 滚动条样式 */
.content-scroll-area::-webkit-scrollbar {
  width: 8px;
}

.content-scroll-area::-webkit-scrollbar-thumb {
  background-color: #dcdfe6;
  border-radius: 4px;
}

.content-scroll-area::-webkit-scrollbar-thumb:hover {
  background-color: #c0c4cc;
}

.content-scroll-area::-webkit-scrollbar-track {
  background-color: transparent;
}

.content-header h2 {
  font-size: 18px;
  font-weight: 600;
  color: #303133;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.mobile-menu-btn {
  display: none;
}

.sidebar-overlay {
  display: none;
}

.header-actions {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
}

.loading-container {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
  color: #409eff;
}

.load-more {
  display: flex;
  justify-content: center;
  padding: 16px 0;
}

/* 响应式设计 - 平板 */
@media (max-width: 1024px) {
  .content {
    flex-direction: column;
  }
  
  .content-header {
    padding: 16px;
  }
  
  .content-header h2 {
    font-size: 16px;
    width: 100%;
  }
  
  .header-actions {
    width: 100%;
    justify-content: flex-start;
  }
  
  .header-actions .el-select,
  .header-actions .el-input {
    width: auto !important;
    flex: 1;
    min-width: 120px;
  }
}

/* 响应式设计 - 手机 */
@media (max-width: 768px) {
  .image-manager {
    height: calc(100vh - 120px);
  }
  
  .sidebar-overlay {
    display: block;
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.5);
    z-index: 999;
  }
  
  .mobile-menu-btn {
    display: inline-flex;
  }
  
  .content-header {
    padding: 12px;
  }
  
  .content-header h2 {
    font-size: 15px;
  }
  
  .header-left {
    flex: 1;
  }
  
  .header-actions {
    flex-direction: column;
    align-items: stretch;
  }
  
  .header-actions .el-select,
  .header-actions .el-input,
  .header-actions .el-radio-group {
    width: 100% !important;
  }
  
  .drag-hint {
    padding: 20px;
  }
  
  .drag-icon {
    font-size: 48px;
  }
  
  .drag-text {
    font-size: 14px;
  }
}

/* 响应式设计 - 小屏手机 */
@media (max-width: 480px) {
  .image-manager {
    height: calc(100vh - 140px);
  }
  
  .content-header {
    padding: 10px;
  }
  
  .content-header h2 {
    font-size: 14px;
  }
  
  .header-actions .el-select .el-input__inner,
  .header-actions .el-input .el-input__inner {
    font-size: 13px;
  }
}
</style>
