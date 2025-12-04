<template>
  <el-dialog
    v-model="visible"
    :title="isBatch ? '批量格式转换' : '图片格式转换'"
    width="500px"
    @close="handleClose"
  >
    <el-form :model="form" label-width="100px">
      <el-form-item label="当前格式">
        <el-tag v-if="!isBatch" type="info" size="large">
          {{ currentFormat?.toUpperCase() }}
        </el-tag>
        <el-tag v-else type="info" size="large">
          {{ selectedImages.length }} 张图片
        </el-tag>
      </el-form-item>

      <el-form-item label="目标格式" required>
        <el-select 
          v-model="form.targetFormat" 
          placeholder="请选择目标格式"
          style="width: 100%"
        >
          <el-option
            v-for="format in availableFormats"
            :key="format"
            :label="format.toUpperCase()"
            :value="format"
            :disabled="!isBatch && format === currentFormat"
          >
            <span>{{ format.toUpperCase() }}</span>
            <el-tag 
              v-if="isAnimatedFormat(format)" 
              type="warning" 
              size="small"
              style="margin-left: 8px"
            >
              支持动画
            </el-tag>
          </el-option>
        </el-select>
      </el-form-item>

      <el-form-item label="图片质量">
        <el-slider 
          v-model="form.quality" 
          :min="1" 
          :max="100"
          :marks="{ 50: '50%', 75: '75%', 90: '90%', 100: '100%' }"
          show-input
        />
        <div class="quality-hint">
          <el-icon><InfoFilled /></el-icon>
          <span>质量越高，文件越大。建议：JPEG 85-90%，PNG/WebP 90-95%</span>
        </div>
      </el-form-item>

      <el-alert 
        v-if="!isBatch && isAnimatedFormat(currentFormat) && !isAnimatedFormat(form.targetFormat)"
        title="注意：当前图片为动图，转换为静态格式后将丢失动画效果"
        type="warning"
        :closable="false"
        style="margin-bottom: 16px"
      />

      <el-alert 
        v-if="isBatch"
        :title="`将转换 ${selectedImages.length} 张图片为 ${form.targetFormat?.toUpperCase()} 格式`"
        type="info"
        :closable="false"
      />
    </el-form>

    <template #footer>
      <el-button @click="handleClose">取消</el-button>
      <el-button 
        type="primary" 
        :loading="converting"
        :disabled="!form.targetFormat || (!isBatch && form.targetFormat === currentFormat)"
        @click="handleConvert"
      >
        {{ converting ? '转换中...' : '开始转换' }}
      </el-button>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { InfoFilled } from '@element-plus/icons-vue'
import * as api from '@/api'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  },
  image: {
    type: Object,
    default: null
  },
  selectedImages: {
    type: Array,
    default: () => []
  }
})

const emit = defineEmits(['update:modelValue', 'converted'])

const visible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

const isBatch = computed(() => props.selectedImages.length > 0)

const form = ref({
  targetFormat: '',
  quality: 90
})

const converting = ref(false)
const supportedFormats = ref([])
const animatedFormats = ref([])

// 获取当前格式
const currentFormat = computed(() => {
  if (!props.image || !props.image.fileName) return ''
  const ext = props.image.fileName.split('.').pop()?.toLowerCase()
  return ext || ''
})

// 可用格式（排除当前格式）
const availableFormats = computed(() => {
  if (isBatch.value) {
    return supportedFormats.value
  }
  return supportedFormats.value.filter(f => f !== currentFormat.value)
})

// 判断是否为动图格式
const isAnimatedFormat = (format) => {
  return animatedFormats.value.includes(format)
}

// 获取支持的格式列表
const loadSupportedFormats = async () => {
  try {
    const res = await api.getSupportedFormats()
    if (res.data && res.data.data) {
      supportedFormats.value = res.data.data.supported || []
      animatedFormats.value = res.data.data.animated || []
    } else if (res.data) {
      // 兼容直接返回 data 的情况
      supportedFormats.value = res.data.supported || []
      animatedFormats.value = res.data.animated || []
    }
  } catch (error) {
    console.error('获取格式列表失败:', error)
    // 默认格式列表
    supportedFormats.value = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff', 'tif']
    animatedFormats.value = ['gif']
  }
}

// 组件挂载时加载格式列表
loadSupportedFormats()

// 转换操作
const handleConvert = async () => {
  if (!form.value.targetFormat) {
    ElMessage.warning('请选择目标格式')
    return
  }

  converting.value = true

  try {
    if (isBatch.value) {
      // 批量转换
      const ids = props.selectedImages.map(img => img.id)
      const res = await api.batchConvertFormat(ids, form.value.targetFormat, form.value.quality)
      
      if (res.data) {
        const { converted, errors } = res.data
        
        if (converted && converted.length > 0) {
          ElMessage.success(`成功转换 ${converted.length} 张图片`)
          emit('converted', converted)
        }
        
        if (errors && errors.length > 0) {
          ElMessage.warning(`${errors.length} 张图片转换失败`)
          console.error('转换失败列表:', errors)
        }
      }
    } else {
      // 单张转换
      const res = await api.convertImageFormat(props.image.id, form.value.targetFormat, form.value.quality)
      
      if (res.data) {
        ElMessage.success('格式转换成功')
        emit('converted', res.data)
      }
    }
    
    handleClose()
  } catch (error) {
    console.error('格式转换失败:', error)
    ElMessage.error('格式转换失败: ' + (error.response?.data?.message || error.message))
  } finally {
    converting.value = false
  }
}

const handleClose = () => {
  visible.value = false
  form.value.targetFormat = ''
  form.value.quality = 90
}

// 监听对话框打开，加载格式列表
watch(() => props.modelValue, (newVal) => {
  if (newVal) {
    loadSupportedFormats()
  }
})
</script>

<style scoped>
.quality-hint {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
  margin-top: 8px;
}

.quality-hint .el-icon {
  font-size: 14px;
}
</style>
