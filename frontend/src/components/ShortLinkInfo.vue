<template>
  <div v-if="hasShortLink" class="short-link-info">
    <div class="short-link-header">
      <el-icon class="link-icon"><Link /></el-icon>
      <span class="short-link-title">短链接</span>
    </div>

    <div class="short-link-content">
      <!-- 短链 URL 显示 -->
      <div class="short-link-url-wrapper">
        <el-input
          v-model="displayUrl"
          readonly
          class="short-link-input"
          :title="displayUrl"
        >
          <template #append>
            <el-button
              :icon="CopyDocument"
              @click="handleCopyUrl"
              title="复制短链"
            />
          </template>
        </el-input>
      </div>

      <!-- 格式化复制按钮组 -->
      <div class="format-buttons">
        <el-button-group>
          <el-button
            size="small"
            @click="handleCopyFormat('markdown')"
            title="复制 Markdown 格式"
          >
            <el-icon><Document /></el-icon>
            <span class="button-text">Markdown</span>
          </el-button>
          <el-button
            size="small"
            @click="handleCopyFormat('html')"
            title="复制 HTML 格式"
          >
            <el-icon><Document /></el-icon>
            <span class="button-text">HTML</span>
          </el-button>
          <el-button
            size="small"
            @click="handleCopyFormat('bbcode')"
            title="复制 BBCode 格式"
          >
            <el-icon><Postcard /></el-icon>
            <span class="button-text">BBCode</span>
          </el-button>
          <el-button
            v-if="showQRCode"
            size="small"
            @click="handleShowQR"
            title="查看二维码"
          >
            <el-icon><Grid /></el-icon>
            <span class="button-text">二维码</span>
          </el-button>
        </el-button-group>
      </div>

      <!-- 短链统计信息（可选） -->
      <div v-if="showStats && stats" class="short-link-stats">
        <el-tag type="info" size="small" effect="plain">
          <el-icon><View /></el-icon>
          点击: {{ stats.clicks || 0 }}
        </el-tag>
        <el-tag v-if="stats.createdAt" type="info" size="small" effect="plain">
          <el-icon><Clock /></el-icon>
          创建: {{ formatDate(stats.createdAt) }}
        </el-tag>
      </div>
    </div>

    <!-- 二维码对话框 -->
    <el-dialog
      v-model="qrDialogVisible"
      title="短链二维码"
      width="400px"
      center
    >
      <div class="qr-code-container">
        <div v-if="qrCodeLoading" class="qr-loading">
          <el-icon class="is-loading"><Loading /></el-icon>
          <p>生成二维码中...</p>
        </div>
        <div v-else-if="qrCodeError" class="qr-error">
          <el-icon><WarnTriangleFilled /></el-icon>
          <p>{{ qrCodeError }}</p>
        </div>
        <div v-else class="qr-code-wrapper">
          <img :src="qrCodeDataUrl" alt="短链二维码" class="qr-code-image" />
          <p class="qr-code-url">{{ displayUrl }}</p>
          <el-button
            type="primary"
            :icon="Download"
            @click="handleDownloadQR"
            class="download-btn"
          >
            下载二维码
          </el-button>
        </div>
      </div>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import {
  Link,
  CopyDocument,
  Document,
  Postcard,
  Grid,
  View,
  Clock,
  Download,
  Loading,
  WarnTriangleFilled
} from '@element-plus/icons-vue'
import { copyShortLink, copyShortLinkWithFormat, generateQRCode, hasShortLink as checkHasShortLink } from '@/utils/shortlink'

interface ShortLinkStats {
  clicks?: number
  createdAt?: string
}

interface Props {
  shortLinkCode?: string
  shortLinkUrl?: string
  fileName?: string
  showQRCode?: boolean
  showStats?: boolean
  stats?: ShortLinkStats | null
}

const props = withDefaults(defineProps<Props>(), {
  showQRCode: true,
  showStats: false,
  stats: null
})

// 计算属性
const hasShortLink = computed(() => checkHasShortLink({
  shortLinkCode: props.shortLinkCode,
  shortLinkUrl: props.shortLinkUrl
}))

const displayUrl = computed(() => props.shortLinkUrl || '')

// 二维码相关状态
const qrDialogVisible = ref(false)
const qrCodeDataUrl = ref('')
const qrCodeLoading = ref(false)
const qrCodeError = ref('')

// 复制短链
const handleCopyUrl = async () => {
  if (props.shortLinkUrl) {
    await copyShortLink(props.shortLinkUrl)
  }
}

// 复制格式化短链
const handleCopyFormat = async (format: 'markdown' | 'html' | 'bbcode') => {
  if (props.shortLinkUrl) {
    await copyShortLinkWithFormat(props.shortLinkUrl, format, props.fileName)
  }
}

// 显示二维码
const handleShowQR = async () => {
  if (!props.shortLinkUrl) return

  qrDialogVisible.value = true

  // 如果已经生成过，直接显示
  if (qrCodeDataUrl.value) return

  // 生成二维码
  qrCodeLoading.value = true
  qrCodeError.value = ''

  try {
    qrCodeDataUrl.value = await generateQRCode(props.shortLinkUrl)
  } catch (err) {
    qrCodeError.value = '生成二维码失败，请确保已安装 qrcode 库'
    console.error(err)
  } finally {
    qrCodeLoading.value = false
  }
}

// 下载二维码
const handleDownloadQR = () => {
  if (!qrCodeDataUrl.value) return

  const link = document.createElement('a')
  link.href = qrCodeDataUrl.value
  link.download = `shortlink-${props.shortLinkCode || 'qrcode'}.png`
  link.click()
}

// 格式化日期
const formatDate = (dateStr: string) => {
  const date = new Date(dateStr)
  return date.toLocaleString('zh-CN')
}

// 监听短链变化，清除二维码缓存
watch(() => props.shortLinkUrl, () => {
  qrCodeDataUrl.value = ''
})
</script>

<style scoped>
.short-link-info {
  margin: 12px 0;
  padding: 16px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 8px;
  color: #fff;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.short-link-header {
  display: flex;
  align-items: center;
  margin-bottom: 12px;
  font-weight: 600;
  font-size: 15px;
}

.link-icon {
  margin-right: 8px;
  font-size: 18px;
}

.short-link-title {
  font-weight: 600;
}

.short-link-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.short-link-url-wrapper {
  width: 100%;
}

.short-link-input {
  width: 100%;
}

.short-link-input :deep(.el-input__wrapper) {
  background-color: rgba(255, 255, 255, 0.95);
  box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.3) inset;
}

.short-link-input :deep(.el-input__inner) {
  color: #333;
  font-family: 'Courier New', monospace;
  font-size: 13px;
}

.short-link-input :deep(.el-input-group__append) {
  background-color: rgba(255, 255, 255, 0.9);
  border-left: 1px solid rgba(102, 126, 234, 0.2);
}

.short-link-input :deep(.el-input-group__append .el-button) {
  color: #667eea;
}

.short-link-input :deep(.el-input-group__append .el-button:hover) {
  color: #764ba2;
  background-color: rgba(102, 126, 234, 0.1);
}

.format-buttons {
  display: flex;
  justify-content: flex-start;
}

.format-buttons .el-button-group {
  background-color: rgba(255, 255, 255, 0.15);
  border-radius: 6px;
  padding: 2px;
}

.format-buttons :deep(.el-button) {
  background-color: transparent;
  border-color: transparent;
  color: #fff;
  transition: all 0.3s;
}

.format-buttons :deep(.el-button:hover) {
  background-color: rgba(255, 255, 255, 0.2);
  border-color: rgba(255, 255, 255, 0.3);
  transform: translateY(-1px);
}

.format-buttons :deep(.el-button .el-icon) {
  margin-right: 4px;
}

.short-link-stats {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.short-link-stats .el-tag {
  background-color: rgba(255, 255, 255, 0.15);
  border-color: rgba(255, 255, 255, 0.3);
  color: #fff;
}

.short-link-stats :deep(.el-tag .el-icon) {
  margin-right: 4px;
}

/* 二维码对话框样式 */
.qr-code-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 300px;
}

.qr-loading,
.qr-error {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  color: #666;
}

.qr-loading .el-icon {
  font-size: 32px;
  color: #409eff;
}

.qr-error .el-icon {
  font-size: 32px;
  color: #f56c6c;
}

.qr-code-wrapper {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
}

.qr-code-image {
  width: 200px;
  height: 200px;
  border: 4px solid #fff;
  border-radius: 8px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
}

.qr-code-url {
  font-size: 12px;
  color: #666;
  word-break: break-all;
  text-align: center;
  max-width: 300px;
  margin: 0;
}

.download-btn {
  margin-top: 8px;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .short-link-info {
    padding: 12px;
  }

  .button-text {
    display: none;
  }

  .format-buttons :deep(.el-button) {
    padding: 8px 12px;
  }

  .short-link-input :deep(.el-input__inner) {
    font-size: 12px;
  }
}

@media (max-width: 480px) {
  .short-link-header {
    font-size: 14px;
  }

  .link-icon {
    font-size: 16px;
  }

  .format-buttons {
    width: 100%;
  }

  .format-buttons .el-button-group {
    width: 100%;
    display: flex;
  }

  .format-buttons :deep(.el-button) {
    flex: 1;
    padding: 6px 8px;
  }
}
</style>
