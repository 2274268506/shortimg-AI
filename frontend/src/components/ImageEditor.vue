<template>
  <el-dialog
    v-model="visible"
    title="图片编辑"
    width="900px"
    :close-on-click-modal="false"
    @close="handleClose"
  >
    <el-tabs v-model="activeTab" type="border-card">
      <!-- 重命名 -->
      <el-tab-pane label="重命名" name="rename">
        <el-form label-width="100px">
          <el-form-item label="当前文件名">
            <el-input v-model="image.fileName" disabled />
          </el-form-item>
          <el-form-item label="新文件名">
            <el-input
              v-model="newFileName"
              placeholder="输入新的文件名（不含扩展名）"
            />
          </el-form-item>
          <el-form-item>
            <el-button type="primary" @click="handleRename">
              确认重命名
            </el-button>
          </el-form-item>
        </el-form>
      </el-tab-pane>

      <!-- 裁剪 -->
      <el-tab-pane label="裁剪" name="crop">
        <div class="crop-container">
          <div class="crop-preview">
            <img ref="cropImage" :src="image.url" />
          </div>
          <div class="crop-controls">
            <el-space direction="vertical" size="large" fill>
              <el-button-group>
                <el-button @click="cropRotate(-90)">
                  <el-icon><RefreshLeft /></el-icon>
                  逆时针
                </el-button>
                <el-button @click="cropRotate(90)">
                  <el-icon><RefreshRight /></el-icon>
                  顺时针
                </el-button>
              </el-button-group>
              
              <el-button-group>
                <el-button @click="cropFlip('horizontal')">
                  水平翻转
                </el-button>
                <el-button @click="cropFlip('vertical')">
                  垂直翻转
                </el-button>
              </el-button-group>

              <div>
                <div style="margin-bottom: 8px;">纵横比：</div>
                <el-button-group>
                  <el-button @click="setAspectRatio(NaN)">自由</el-button>
                  <el-button @click="setAspectRatio(1)">1:1</el-button>
                  <el-button @click="setAspectRatio(4/3)">4:3</el-button>
                  <el-button @click="setAspectRatio(16/9)">16:9</el-button>
                </el-button-group>
              </div>

              <el-button type="primary" @click="handleCrop">
                应用裁剪
              </el-button>
            </el-space>
          </div>
        </div>
      </el-tab-pane>

      <!-- 滤镜 -->
      <el-tab-pane label="滤镜" name="filter">
        <div class="filter-container">
          <div class="filter-preview">
            <img
              :src="image.url"
              :style="filterStyle"
              ref="filterImage"
            />
          </div>
          <div class="filter-controls">
            <el-form label-width="80px">
              <el-form-item label="亮度">
                <el-slider
                  v-model="filters.brightness"
                  :min="0"
                  :max="200"
                  :step="1"
                  show-input
                />
              </el-form-item>
              
              <el-form-item label="对比度">
                <el-slider
                  v-model="filters.contrast"
                  :min="0"
                  :max="200"
                  :step="1"
                  show-input
                />
              </el-form-item>
              
              <el-form-item label="饱和度">
                <el-slider
                  v-model="filters.saturate"
                  :min="0"
                  :max="200"
                  :step="1"
                  show-input
                />
              </el-form-item>
              
              <el-form-item label="灰度">
                <el-slider
                  v-model="filters.grayscale"
                  :min="0"
                  :max="100"
                  :step="1"
                  show-input
                />
              </el-form-item>
              
              <el-form-item label="模糊">
                <el-slider
                  v-model="filters.blur"
                  :min="0"
                  :max="10"
                  :step="0.1"
                  show-input
                />
              </el-form-item>

              <el-form-item>
                <el-space>
                  <el-button @click="resetFilters">重置</el-button>
                  <el-button type="primary" @click="handleFilter">
                    应用滤镜
                  </el-button>
                </el-space>
              </el-form-item>
            </el-form>
          </div>
        </div>
      </el-tab-pane>
    </el-tabs>
  </el-dialog>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { ElMessage } from 'element-plus'
import { RefreshLeft, RefreshRight } from '@element-plus/icons-vue'
import Cropper from 'cropperjs'
import 'cropperjs/dist/cropper.css'
import type { Image } from '@/types'

interface Props {
  modelValue: boolean
  image: Image
}

interface Emits {
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', data: { type: string; data: any }): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const visible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

const activeTab = ref('rename')
const newFileName = ref('')
const cropImage = ref<HTMLImageElement>()
const filterImage = ref<HTMLImageElement>()
let cropper: Cropper | null = null

// 滤镜参数
const filters = ref({
  brightness: 100,
  contrast: 100,
  saturate: 100,
  grayscale: 0,
  blur: 0
})

// 计算滤镜样式
const filterStyle = computed(() => {
  const { brightness, contrast, saturate, grayscale, blur } = filters.value
  return {
    filter: `brightness(${brightness}%) contrast(${contrast}%) saturate(${saturate}%) grayscale(${grayscale}%) blur(${blur}px)`
  }
})

// 监听标签页切换，初始化裁剪器
watch(activeTab, async (newTab) => {
  if (newTab === 'crop') {
    await nextTick()
    initCropper()
  } else {
    destroyCropper()
  }
})

// 监听对话框打开，重置数据
watch(visible, (val) => {
  if (val) {
    newFileName.value = props.image.fileName.replace(/\.[^.]+$/, '')
    resetFilters()
  } else {
    destroyCropper()
  }
})

// 初始化裁剪器
const initCropper = () => {
  if (cropImage.value && !cropper) {
    cropper = new Cropper(cropImage.value, {
      viewMode: 1,
      autoCropArea: 1,
      responsive: true,
      restore: false,
      guides: true,
      center: true,
      highlight: true,
      cropBoxMovable: true,
      cropBoxResizable: true,
      toggleDragModeOnDblclick: false
    } as any)
  }
}

// 销毁裁剪器
const destroyCropper = () => {
  if (cropper) {
    cropper.destroy()
    cropper = null
  }
}

// 裁剪器旋转
const cropRotate = (degree: number) => {
  ;(cropper as any)?.rotate(degree)
}

// 裁剪器翻转
const cropFlip = (type: 'horizontal' | 'vertical') => {
  if (type === 'horizontal') {
    const scaleX = (cropper as any)?.getData().scaleX || 1
    ;(cropper as any)?.scaleX(-scaleX)
  } else {
    const scaleY = (cropper as any)?.getData().scaleY || 1
    ;(cropper as any)?.scaleY(-scaleY)
  }
}

// 设置纵横比
const setAspectRatio = (ratio: number) => {
  ;(cropper as any)?.setAspectRatio(ratio)
}

// 重置滤镜
const resetFilters = () => {
  filters.value = {
    brightness: 100,
    contrast: 100,
    saturate: 100,
    grayscale: 0,
    blur: 0
  }
}

// 处理重命名
const handleRename = () => {
  if (!newFileName.value.trim()) {
    ElMessage.warning('请输入新文件名')
    return
  }
  
  const ext = props.image.fileName.match(/\.[^.]+$/)?.[0] || ''
  const fullName = newFileName.value.trim() + ext
  
  emit('save', {
    type: 'rename',
    data: { newFileName: fullName }
  })
}

// 处理裁剪
const handleCrop = () => {
  if (!cropper) return
  
  const canvas = (cropper as any).getCroppedCanvas()
  // 从原图片获取扩展名
  const ext = props.image.fileName.split('.').pop()?.toLowerCase() || 'jpg'
  const mimeType = ext === 'png' ? 'image/png' : 'image/jpeg'
  
  canvas.toBlob((blob: Blob | null) => {
    if (blob) {
      // 创建带文件名的 File 对象
      const file = new File([blob], `cropped.${ext}`, { type: mimeType })
      emit('save', {
        type: 'crop',
        data: { blob: file }
      })
    }
  }, mimeType, 0.95)
}

// 处理滤镜
const handleFilter = () => {
  if (!filterImage.value) return
  
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')
  const img = filterImage.value
  
  canvas.width = img.naturalWidth
  canvas.height = img.naturalHeight
  
  if (ctx) {
    ctx.filter = filterStyle.value.filter
    ctx.drawImage(img, 0, 0)
    
    // 从原图片获取扩展名
    const ext = props.image.fileName.split('.').pop()?.toLowerCase() || 'jpg'
    const mimeType = ext === 'png' ? 'image/png' : 'image/jpeg'
    
    canvas.toBlob((blob: Blob | null) => {
      if (blob) {
        // 创建带文件名的 File 对象
        const file = new File([blob], `filtered.${ext}`, { type: mimeType })
        emit('save', {
          type: 'filter',
          data: { blob: file }
        })
      }
    }, mimeType, 0.95)
  }
}

// 处理关闭
const handleClose = () => {
  destroyCropper()
  activeTab.value = 'rename'
}
</script>

<style scoped>
.crop-container,
.filter-container {
  display: flex;
  gap: 20px;
  min-height: 400px;
}

.crop-preview,
.filter-preview {
  flex: 1;
  background: #f5f5f5;
  border-radius: 4px;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}

.crop-preview img,
.filter-preview img {
  max-width: 100%;
  max-height: 500px;
  display: block;
}

.crop-controls,
.filter-controls {
  width: 250px;
  padding: 20px;
  background: #fafafa;
  border-radius: 4px;
}

:deep(.el-tabs__content) {
  padding: 20px;
}
</style>
