<template>
  <el-dialog
    v-model="visible"
    :title="image?.fileName"
    width="80%"
    class="preview-dialog"
  >
    <div class="preview-content">
      <div class="preview-image-container">
        <img :src="imageUrlWithTimestamp" class="preview-image" />
      </div>
      <div class="preview-details">
        <h3>图片详情</h3>
        <div class="detail-item">
          <span class="detail-label">文件名:</span>
          <span class="detail-value">{{ image?.fileName }}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">尺寸:</span>
          <span class="detail-value">{{ image?.width }} × {{ image?.height }} px</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">文件大小:</span>
          <span class="detail-value">{{ formatFileSize(image?.fileSize) }}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">格式:</span>
          <span class="detail-value">{{ image?.mimeType || '未知' }}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">上传时间:</span>
          <span class="detail-value">{{ formatDate(image?.createdAt) }}</span>
        </div>
        <div class="detail-item" v-if="image?.owner">
          <span class="detail-label">上传者:</span>
          <span class="detail-value">
            <el-tag type="info" size="small">
              <el-icon style="margin-right: 4px;"><User /></el-icon>
              {{ image.owner.username }}
            </el-tag>
          </span>
        </div>
        <div class="detail-item">
          <span class="detail-label">访问权限:</span>
          <span class="detail-value">
            <el-tag v-if="image?.isPrivate" type="danger" size="small">
              <el-icon style="margin-right: 4px;"><Lock /></el-icon>
              私有
            </el-tag>
            <el-tag v-else type="success" size="small">
              <el-icon style="margin-right: 4px;"><View /></el-icon>
              公开
            </el-tag>
          </span>
        </div>
        <div class="detail-item">
          <span class="detail-label">下载权限:</span>
          <span class="detail-value">
            <el-tag v-if="image?.allowDownload" type="success" size="small">
              <el-icon style="margin-right: 4px;"><Check /></el-icon>
              允许
            </el-tag>
            <el-tag v-else type="warning" size="small">
              <el-icon style="margin-right: 4px;"><Close /></el-icon>
              禁止
            </el-tag>
          </span>
        </div>
        <div class="detail-item" v-if="imageStats">
          <span class="detail-label">访问次数:</span>
          <span class="detail-value">
            <el-tag type="success">{{ formatNumber(imageStats.viewCount) }}</el-tag>
          </span>
        </div>
        <div class="detail-item" v-if="imageStats">
          <span class="detail-label">下载次数:</span>
          <span class="detail-value">
            <el-tag type="warning">{{ formatNumber(imageStats.downloadCount) }}</el-tag>
          </span>
        </div>
        <div class="detail-item" v-if="imageStats && imageStats.lastViewAt">
          <span class="detail-label">最后访问:</span>
          <span class="detail-value">{{ formatDate(imageStats.lastViewAt) }}</span>
        </div>
        <div class="detail-item">
          <span class="detail-label">图片链接:</span>
          <div class="detail-value link-value">
            <el-input
              :model-value="fullImageUrl"
              readonly
              size="small"
            />
            <el-dropdown @command="(cmd) => $emit('copyLink', image, cmd)" trigger="click">
              <el-button :icon="Link" size="small" style="margin-left: 8px;">
                复制 <el-icon class="el-icon--right"><ArrowDown /></el-icon>
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
          </div>
        </div>
        <!-- 短链信息 -->
        <div v-if="image?.shortLinkUrl" class="short-link-section">
          <ShortLinkInfo
            :short-link-code="image.shortLinkCode"
            :short-link-url="image.shortLinkUrl"
            :file-name="image.fileName"
            :show-q-r-code="true"
            :show-stats="false"
          />
        </div>
      </div>
    </div>
    <template #footer>
      <el-button @click="$emit('download', image)" :icon="Download">
        下载图片
      </el-button>
      <el-button @click="visible = false">
        关闭
      </el-button>
    </template>
  </el-dialog>
</template>

<script setup>
import { computed, watch, ref } from 'vue'
import { Link, Download, ArrowDown, User, Lock, View, Check, Close } from '@element-plus/icons-vue'
import { recordView, getImageStats } from '@/api'
import ShortLinkInfo from './ShortLinkInfo.vue'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  },
  image: {
    type: Object,
    default: null
  }
})

const emit = defineEmits(['update:modelValue', 'copyLink', 'download'])

const imageStats = ref(null)

const visible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

const fullImageUrl = computed(() => {
  return props.image?.url ? (window.location.origin + props.image.url) : ''
})

// 添加时间戳参数以避免缓存
const imageUrlWithTimestamp = computed(() => {
  if (!props.image?.url) return ''
  const timestamp = new Date(props.image.updatedAt).getTime()
  return `${props.image.url}?t=${timestamp}`
})

// 监听对话框打开，记录访问次数并获取统计数据
watch(() => props.modelValue, async (newVal) => {
  if (newVal && props.image?.id) {
    try {
      // 记录访问次数
      await recordView(props.image.id)
      // 获取图片统计数据
      const res = await getImageStats(props.image.id)
      imageStats.value = res.data
    } catch (error) {
      console.error('加载图片统计失败:', error)
    }
  }
})

const formatNumber = (num) => {
  if (!num) return '0'
  return num.toLocaleString()
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
.preview-dialog {
  .preview-content {
    display: flex;
    gap: 24px;
  }

  .preview-image-container {
    flex: 1;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 400px;
    background-color: #f5f7fa;
    border-radius: 8px;
    padding: 20px;
  }

  .preview-image {
    max-width: 100%;
    max-height: 60vh;
    object-fit: contain;
  }

  .preview-details {
    width: 350px;
    background-color: #f5f7fa;
    padding: 20px;
    border-radius: 8px;
  }

  .preview-details h3 {
    margin: 0 0 16px 0;
    font-size: 16px;
    color: #303133;
  }

  .detail-item {
    margin-bottom: 16px;
  }

  .detail-label {
    display: block;
    font-size: 12px;
    color: #909399;
    margin-bottom: 4px;
  }

  .detail-value {
    display: block;
    font-size: 14px;
    color: #303133;
    word-break: break-all;
  }

  .link-value {
    display: flex;
    align-items: center;
  }

  .short-link-section {
    margin-top: 20px;
  }
}
</style>
