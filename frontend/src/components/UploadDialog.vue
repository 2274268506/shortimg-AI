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
        <el-select v-model="albumId" placeholder="请选择相册">
          <el-option
            v-for="album in albums"
            :key="album.id"
            :label="album.name"
            :value="album.id"
          />
        </el-select>
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
const fileList = ref([])
const uploadRef = ref()

// 监听对话框关闭，清空文件列表
watch(visible, (newVal) => {
  if (!newVal) {
    fileList.value = []
    if (uploadRef.value) {
      uploadRef.value.clearFiles()
    }
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
