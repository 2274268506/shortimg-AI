<template>
  <el-dialog
    v-model="visible"
    title="上传图片"
    width="600px"
    :close-on-click-modal="false"
    :close-on-press-escape="false"
    append-to-body
    @close="handleClose"
  >
    <el-form label-width="80px">
      <el-form-item label="选择相册">
        <el-select v-model="albumId" placeholder="请选择相册" @change="handleAlbumChange">
          <el-option
            v-for="album in albums"
            :key="album.id"
            :label="album.name"
            :value="album.id"
          >
            <div style="display: flex; align-items: center; justify-content: space-between;">
              <span>{{ album.name }}</span>
              <el-tag v-if="album.enableShortLink" size="small" type="success">
                自动短链
              </el-tag>
            </div>
          </el-option>
        </el-select>
      </el-form-item>

      <el-form-item label="生成短链">
        <el-switch v-model="enableShortLink" />
        <span style="margin-left: 12px; color: var(--el-text-color-secondary); font-size: 13px;">
          {{ shortLinkHint }}
        </span>
      </el-form-item>

      <el-form-item label="选择图片">
        <el-upload
          ref="uploadRef"
          :auto-upload="false"
          :on-change="handleFileChange"
          :file-list="fileList"
          accept="image/*"
          multiple
          drag
        >
          <el-icon class="el-icon--upload"><Upload /></el-icon>
          <div class="el-upload__text">
            拖拽文件到此处或 <em>点击上传</em>
          </div>
          <template #tip>
            <div class="el-upload__tip">
              支持 jpg/png/gif/webp 格式，单个文件不超过 100MB
            </div>
          </template>
        </el-upload>
      </el-form-item>
    </el-form>

    <!-- 上传进度 -->
    <div v-if="uploading" class="upload-progress">
      <el-progress :percentage="uploadProgress" :status="uploadStatus" />
      <p class="progress-text">{{ uploadMessage }}</p>
    </div>

    <template #footer>
      <el-button @click="handleClose" :disabled="uploading">取消</el-button>
      <el-button
        type="primary"
        @click="handleUpload"
        :loading="uploading"
      >
        {{ uploading ? '上传中...' : '开始上传' }}
      </el-button>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { Upload } from '@element-plus/icons-vue'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  },
  albums: {
    type: Array,
    required: true
  },
  defaultAlbumId: {
    type: Number,
    default: 1
  },
  uploading: {
    type: Boolean,
    default: false
  },
  uploadProgress: {
    type: Number,
    default: 0
  },
  uploadStatus: {
    type: String,
    default: ''
  },
  uploadMessage: {
    type: String,
    default: ''
  }
})

const emit = defineEmits(['update:modelValue', 'upload'])

const visible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

const albumId = ref(props.defaultAlbumId)
const enableShortLink = ref(false)
const fileList = ref([])
const uploadRef = ref()

// 计算短链提示文本
const shortLinkHint = computed(() => {
  const selectedAlbum = props.albums.find(a => a.id === albumId.value)
  if (selectedAlbum?.enableShortLink) {
    return enableShortLink.value
      ? '相册已开启自动短链，将为上传的图片生成短链'
      : '关闭后将不生成短链（覆盖相册设置）'
  }
  return enableShortLink.value
    ? '开启后将为上传的图片生成短链'
    : '相册未开启短链，上传的图片不会生成短链'
})

// 相册切换时更新短链开关
const handleAlbumChange = (newAlbumId) => {
  const selectedAlbum = props.albums.find(a => a.id === newAlbumId)
  if (selectedAlbum) {
    enableShortLink.value = selectedAlbum.enableShortLink || false
  }
}

// 监听对话框关闭，清空文件列表
watch(visible, (newVal) => {
  if (!newVal) {
    fileList.value = []
    if (uploadRef.value) {
      uploadRef.value.clearFiles()
    }
  } else {
    // 对话框打开时，更新 albumId 为 defaultAlbumId
    albumId.value = props.defaultAlbumId
    // 同时更新短链开关
    const selectedAlbum = props.albums.find(a => a.id === props.defaultAlbumId)
    if (selectedAlbum) {
      enableShortLink.value = selectedAlbum.enableShortLink || false
    }
  }
})

// 监听 defaultAlbumId 的变化
watch(() => props.defaultAlbumId, (newId) => {
  albumId.value = newId
  const selectedAlbum = props.albums.find(a => a.id === newId)
  if (selectedAlbum) {
    enableShortLink.value = selectedAlbum.enableShortLink || false
  }
})

// 监听上传状态，成功后清空文件列表
watch(() => props.uploadStatus, (newStatus) => {
  if (newStatus === 'success') {
    setTimeout(() => {
      fileList.value = []
      if (uploadRef.value) {
        uploadRef.value.clearFiles()
      }
    }, 1000)
  }
})

const handleFileChange = (file, files) => {
  fileList.value = files
}

const handleUpload = () => {
  emit('upload', {
    albumId: albumId.value,
    enableShortLink: enableShortLink.value,
    files: fileList.value.map(f => f.raw)
  })
}

const handleClose = () => {
  if (!props.uploading) {
    fileList.value = []
    if (uploadRef.value) {
      uploadRef.value.clearFiles()
    }
    visible.value = false
  }
}
</script>

<style scoped>
.upload-progress {
  margin-top: 20px;
  padding: 20px;
  background-color: #f5f7fa;
  border-radius: 8px;
}

.progress-text {
  margin-top: 12px;
  text-align: center;
  color: #606266;
  font-size: 14px;
}

/* 响应式设计 - 手机 */
@media (max-width: 768px) {
  :deep(.el-dialog) {
    width: 90% !important;
    margin: 5vh auto !important;
  }

  :deep(.el-form-item__label) {
    width: 70px !important;
    font-size: 13px;
  }

  :deep(.el-upload-dragger) {
    padding: 30px 20px;
  }

  :deep(.el-icon--upload) {
    font-size: 48px;
  }

  :deep(.el-upload__text) {
    font-size: 13px;
  }

  :deep(.el-upload__tip) {
    font-size: 11px;
  }

  .upload-progress {
    padding: 15px;
  }

  .progress-text {
    font-size: 13px;
  }
}

/* 响应式设计 - 小屏手机 */
@media (max-width: 480px) {
  :deep(.el-dialog) {
    width: 95% !important;
  }

  :deep(.el-form-item__label) {
    width: 60px !important;
    font-size: 12px;
  }

  :deep(.el-upload-dragger) {
    padding: 20px 15px;
  }

  :deep(.el-dialog__header) {
    padding: 15px;
  }

  :deep(.el-dialog__body) {
    padding: 15px;
  }

  :deep(.el-dialog__footer) {
    padding: 10px 15px;
  }

  .upload-progress {
    padding: 10px;
  }
}
</style>
