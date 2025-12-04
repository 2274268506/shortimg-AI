<template>
  <div class="settings-page">
    <!-- 系统配置 -->
    <el-card class="settings-card">
      <template #header>
        <div class="card-header">
          <span>系统配置</span>
          <el-icon><Setting /></el-icon>
        </div>
      </template>

      <el-form label-width="150px">
        <el-form-item label="后端服务地址">
          <el-input
            v-model="backendUrl"
            placeholder="http://localhost:8080"
            style="width: 400px;"
          >
            <template #append>
              <el-button @click="saveBackendUrl" type="primary">
                保存
              </el-button>
            </template>
          </el-input>
          <div class="form-tip">
            设置后端API服务器地址，保存后会自动刷新页面
          </div>
        </el-form-item>

        <el-form-item label="连接状态">
          <el-tag :type="connectionStatus === 'connected' ? 'success' : 'danger'">
            {{ connectionStatus === 'connected' ? '已连接' : '未连接' }}
          </el-tag>
          <el-button
            size="small"
            @click="testConnection"
            style="margin-left: 8px;"
            :loading="testing"
          >
            测试连接
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 显示设置 -->
    <el-card class="settings-card">
      <template #header>
        <div class="card-header">
          <span>显示设置</span>
          <el-icon><View /></el-icon>
        </div>
      </template>

      <el-form label-width="150px">
        <el-form-item label="主题模式">
          <el-radio-group v-model="displaySettings.theme">
            <el-radio label="light">浅色</el-radio>
            <el-radio label="dark">深色</el-radio>
            <el-radio label="auto">跟随系统</el-radio>
          </el-radio-group>
        </el-form-item>

        <el-form-item label="默认视图">
          <el-radio-group v-model="displaySettings.defaultView">
            <el-radio label="grid">网格视图</el-radio>
            <el-radio label="list">列表视图</el-radio>
          </el-radio-group>
          <div class="form-tip">
            图片管理页面的默认显示模式
          </div>
        </el-form-item>

        <el-form-item label="每页显示数量">
          <el-select v-model="displaySettings.pageSize" style="width: 150px;">
            <el-option label="12 张" :value="12" />
            <el-option label="24 张" :value="24" />
            <el-option label="48 张" :value="48" />
            <el-option label="96 张" :value="96" />
          </el-select>
        </el-form-item>

        <el-form-item label="图片缩略图质量">
          <el-slider
            v-model="displaySettings.thumbnailQuality"
            :min="50"
            :max="100"
            :step="10"
            show-stops
          />
          <div class="form-tip">
            较低质量可提升加载速度，较高质量显示更清晰
          </div>
        </el-form-item>

        <el-form-item label="启用图片懒加载">
          <el-switch
            v-model="displaySettings.lazyLoad"
            active-text="已启用"
            inactive-text="已禁用"
          />
          <div class="form-tip">
            启用后可提升页面加载速度
          </div>
        </el-form-item>

        <el-form-item label="显示文件大小">
          <el-switch
            v-model="displaySettings.showFileSize"
            active-text="显示"
            inactive-text="隐藏"
          />
        </el-form-item>

        <el-form-item label="显示上传日期">
          <el-switch
            v-model="displaySettings.showUploadDate"
            active-text="显示"
            inactive-text="隐藏"
          />
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 上传设置 -->
    <el-card class="settings-card">
      <template #header>
        <div class="card-header">
          <span>上传设置</span>
          <el-icon><Upload /></el-icon>
        </div>
      </template>

      <el-form label-width="150px">
        <el-form-item label="默认图片格式">
          <el-select v-model="uploadSettings.defaultFormat" style="width: 150px;">
            <el-option label="保持原格式" value="original" />
            <el-option label="JPEG" value="jpg" />
            <el-option label="PNG" value="png" />
            <el-option label="WebP" value="webp" />
          </el-select>
          <div class="form-tip">
            上传时自动转换为指定格式
          </div>
        </el-form-item>

        <el-form-item label="默认压缩质量">
          <el-slider
            v-model="uploadSettings.quality"
            :min="60"
            :max="100"
            :step="5"
            show-stops
          />
          <span style="margin-left: 8px;">{{ uploadSettings.quality }}%</span>
          <div class="form-tip">
            JPEG/WebP 格式的压缩质量（60-100）
          </div>
        </el-form-item>

        <el-form-item label="最大文件大小">
          <el-input-number
            v-model="uploadSettings.maxFileSize"
            :min="1"
            :max="100"
            :step="1"
          />
          <span style="margin-left: 8px;">MB</span>
          <div class="form-tip">
            超过此大小的文件将被拒绝
          </div>
        </el-form-item>

        <el-form-item label="允许的格式">
          <el-checkbox-group v-model="uploadSettings.allowedFormats">
            <el-checkbox label="jpg">JPEG</el-checkbox>
            <el-checkbox label="png">PNG</el-checkbox>
            <el-checkbox label="gif">GIF</el-checkbox>
            <el-checkbox label="webp">WebP</el-checkbox>
            <el-checkbox label="bmp">BMP</el-checkbox>
            <el-checkbox label="tiff">TIFF</el-checkbox>
          </el-checkbox-group>
        </el-form-item>

        <el-form-item label="自动生成缩略图">
          <el-switch
            v-model="uploadSettings.autoThumbnail"
            active-text="已启用"
            inactive-text="已禁用"
          />
        </el-form-item>

        <el-form-item label="保留EXIF信息">
          <el-switch
            v-model="uploadSettings.keepExif"
            active-text="保留"
            inactive-text="移除"
          />
          <div class="form-tip">
            EXIF 包含拍摄时间、GPS 位置等信息
          </div>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 性能设置 -->
    <el-card class="settings-card">
      <template #header>
        <div class="card-header">
          <span>性能设置</span>
          <el-icon><Odometer /></el-icon>
        </div>
      </template>

      <el-form label-width="150px">
        <el-form-item label="启用请求缓存">
          <el-switch
            v-model="performanceSettings.enableCache"
            active-text="已启用"
            inactive-text="已禁用"
          />
          <div class="form-tip">
            缓存 API 响应以提升性能
          </div>
        </el-form-item>

        <el-form-item label="缓存有效期">
          <el-input-number
            v-model="performanceSettings.cacheDuration"
            :min="60"
            :max="3600"
            :step="60"
            :disabled="!performanceSettings.enableCache"
          />
          <span style="margin-left: 8px;">秒</span>
        </el-form-item>

        <el-form-item label="预加载下一页">
          <el-switch
            v-model="performanceSettings.preloadNextPage"
            active-text="已启用"
            inactive-text="已禁用"
          />
          <div class="form-tip">
            提前加载下一页数据，提升浏览体验
          </div>
        </el-form-item>

        <el-form-item label="并发上传数">
          <el-input-number
            v-model="performanceSettings.concurrentUploads"
            :min="1"
            :max="10"
            :step="1"
          />
          <div class="form-tip">
            批量上传时同时处理的文件数量
          </div>
        </el-form-item>

        <el-form-item label="请求超时时间">
          <el-input-number
            v-model="performanceSettings.requestTimeout"
            :min="5000"
            :max="60000"
            :step="5000"
          />
          <span style="margin-left: 8px;">毫秒</span>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" @click="clearCache">
            <el-icon><Delete /></el-icon>
            清除缓存
          </el-button>
          <span style="margin-left: 8px; font-size: 12px; color: #909399;">
            清除所有本地缓存数据
          </span>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 通知设置 -->
    <el-card class="settings-card">
      <template #header>
        <div class="card-header">
          <span>通知设置</span>
          <el-icon><Bell /></el-icon>
        </div>
      </template>

      <el-form label-width="150px">
        <el-form-item label="上传完成通知">
          <el-switch
            v-model="notificationSettings.uploadComplete"
            active-text="已启用"
            inactive-text="已禁用"
          />
        </el-form-item>

        <el-form-item label="操作成功提示">
          <el-switch
            v-model="notificationSettings.successNotify"
            active-text="已启用"
            inactive-text="已禁用"
          />
        </el-form-item>

        <el-form-item label="错误提示">
          <el-switch
            v-model="notificationSettings.errorNotify"
            active-text="已启用"
            inactive-text="已禁用"
          />
        </el-form-item>

        <el-form-item label="通知停留时间">
          <el-input-number
            v-model="notificationSettings.duration"
            :min="1000"
            :max="10000"
            :step="1000"
          />
          <span style="margin-left: 8px;">毫秒</span>
        </el-form-item>

        <el-form-item label="通知位置">
          <el-select v-model="notificationSettings.position" style="width: 150px;">
            <el-option label="右上角" value="top-right" />
            <el-option label="右下角" value="bottom-right" />
            <el-option label="左上角" value="top-left" />
            <el-option label="左下角" value="bottom-left" />
          </el-select>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 防盗链设置 -->
    <el-card class="settings-card">
      <template #header>
        <div class="card-header">
          <span>防盗链设置</span>
          <el-icon><Lock /></el-icon>
        </div>
      </template>

      <el-form label-width="150px">
        <el-form-item label="启用防盗链保护">
          <el-switch
            v-model="settings.hotlinkProtection"
            active-text="已启用"
            inactive-text="已禁用"
          />
          <div class="form-tip">
            启用后，只有白名单中的域名可以引用图片
          </div>
        </el-form-item>

        <el-form-item label="启用Token验证">
          <el-switch
            v-model="settings.tokenProtection"
            active-text="已启用"
            inactive-text="已禁用"
          />
          <div class="form-tip">
            启用后，访问图片需要带有有效的签名token
          </div>
        </el-form-item>

        <el-form-item label="允许的域名">
          <el-tag
            v-for="domain in settings.allowedDomains"
            :key="domain"
            closable
            @close="removeDomain(domain)"
            style="margin-right: 8px;"
          >
            {{ domain }}
          </el-tag>
          <el-input
            v-if="inputVisible"
            ref="inputRef"
            v-model="inputValue"
            size="small"
            style="width: 200px;"
            @keyup.enter="handleInputConfirm"
            @blur="handleInputConfirm"
          />
          <el-button
            v-else
            size="small"
            @click="showInput"
          >
            + 添加域名
          </el-button>
        </el-form-item>

        <el-form-item label="Token有效期">
          <el-input-number
            v-model="settings.tokenTTL"
            :min="60"
            :max="86400"
            :step="60"
          />
          <span style="margin-left: 8px;">秒</span>
          <div class="form-tip">
            签名URL的有效时间（60秒 - 24小时）
          </div>
        </el-form-item>

        <el-divider />

        <el-form-item label="测试签名URL">
          <el-space direction="vertical" fill style="width: 100%;">
            <div>
              <el-input
                v-model="testImageId"
                placeholder="输入图片ID"
                style="width: 200px; margin-right: 8px;"
              />
              <el-button
                type="primary"
                @click="generateTestURL"
                :loading="generating"
              >
                生成签名URL
              </el-button>
            </div>
            <el-input
              v-if="signedURL"
              v-model="signedURL"
              readonly
              type="textarea"
              :rows="3"
            >
              <template #append>
                <el-button @click="copySignedURL">
                  <el-icon><DocumentCopy /></el-icon>
                  复制
                </el-button>
              </template>
            </el-input>
            <div v-if="expiresAt" class="expires-info">
              过期时间：{{ expiresAt }}
            </div>
          </el-space>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" @click="saveSettings">
            保存设置
          </el-button>
          <el-button @click="resetSettings">
            重置
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card class="info-card">
      <template #header>
        <span>使用说明</span>
      </template>
      <el-descriptions :column="1" border>
        <el-descriptions-item label="防盗链保护">
          通过检查 HTTP Referer 头限制图片访问来源。只有来自白名单域名的请求才能访问图片。
        </el-descriptions-item>
        <el-descriptions-item label="Token验证">
          为图片URL添加签名token，token包含过期时间。适合生成临时分享链接。
        </el-descriptions-item>
        <el-descriptions-item label="配置方式">
          修改后端 routes/routes.go 中的注释，启用相应的中间件。
        </el-descriptions-item>
      </el-descriptions>
    </el-card>

    <!-- 全局操作 -->
    <el-card class="settings-card">
      <template #header>
        <div class="card-header">
          <span>全局操作</span>
          <el-icon><Tools /></el-icon>
        </div>
      </template>

      <el-space wrap>
        <el-button type="primary" size="large" @click="saveAllSettings">
          <el-icon><Select /></el-icon>
          保存所有设置
        </el-button>
        
        <el-button size="large" @click="resetAllSettings">
          <el-icon><RefreshRight /></el-icon>
          重置所有设置
        </el-button>

        <el-button size="large" @click="exportSettings">
          <el-icon><Download /></el-icon>
          导出配置
        </el-button>

        <el-upload
          :show-file-list="false"
          :before-upload="importSettings"
          accept=".json"
        >
          <el-button size="large">
            <el-icon><Upload /></el-icon>
            导入配置
          </el-button>
        </el-upload>
      </el-space>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, nextTick, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { 
  Lock, DocumentCopy, Setting, View, Odometer, Bell, Delete,
  Tools, Select, RefreshRight, Download, Upload
} from '@element-plus/icons-vue'
import * as api from '@/api'
import { useClipboard } from '@vueuse/core'
import { getConfig, saveConfig } from '@/utils/config'
import { updateBaseURL } from '@/utils/request'

// 系统配置
const backendUrl = ref('')
const connectionStatus = ref<'connected' | 'disconnected'>('disconnected')
const testing = ref(false)

// 显示设置
const displaySettings = ref({
  theme: 'light' as 'light' | 'dark' | 'auto',
  defaultView: 'grid' as 'grid' | 'list',
  pageSize: 24,
  thumbnailQuality: 80,
  lazyLoad: true,
  showFileSize: true,
  showUploadDate: true
})

// 上传设置
const uploadSettings = ref({
  defaultFormat: 'original' as string,
  quality: 85,
  maxFileSize: 10,
  allowedFormats: ['jpg', 'png', 'gif', 'webp'],
  autoThumbnail: true,
  keepExif: false
})

// 性能设置
const performanceSettings = ref({
  enableCache: true,
  cacheDuration: 300,
  preloadNextPage: true,
  concurrentUploads: 3,
  requestTimeout: 30000
})

// 通知设置
const notificationSettings = ref({
  uploadComplete: true,
  successNotify: true,
  errorNotify: true,
  duration: 3000,
  position: 'top-right' as 'top-right' | 'bottom-right' | 'top-left' | 'bottom-left'
})

// 防盗链设置
const settings = ref({
  hotlinkProtection: false,
  tokenProtection: false,
  allowedDomains: ['localhost', '127.0.0.1'],
  tokenTTL: 3600
})

const inputVisible = ref(false)
const inputValue = ref('')
const inputRef = ref()
const testImageId = ref('')
const signedURL = ref('')
const expiresAt = ref('')
const generating = ref(false)

const { copy } = useClipboard()

const showInput = () => {
  inputVisible.value = true
  nextTick(() => {
    inputRef.value?.focus()
  })
}

const handleInputConfirm = () => {
  if (inputValue.value) {
    settings.value.allowedDomains.push(inputValue.value)
    inputValue.value = ''
  }
  inputVisible.value = false
}

const removeDomain = (domain: string) => {
  const index = settings.value.allowedDomains.indexOf(domain)
  if (index > -1) {
    settings.value.allowedDomains.splice(index, 1)
  }
}

const generateTestURL = async () => {
  if (!testImageId.value) {
    ElMessage.warning('请输入图片ID')
    return
  }

  generating.value = true
  try {
    const res = await api.getSignedURL(Number(testImageId.value), settings.value.tokenTTL)
    const data = (res as any).data
    signedURL.value = window.location.origin + data.url
    expiresAt.value = data.expiresAt
    ElMessage.success('生成成功')
  } catch (error: any) {
    ElMessage.error('生成失败: ' + (error.message || '未知错误'))
  } finally {
    generating.value = false
  }
}

// 系统配置函数
const saveBackendUrl = () => {
  if (!backendUrl.value) {
    ElMessage.warning('请输入后端服务地址')
    return
  }
  
  saveConfig({ backendUrl: backendUrl.value })
  updateBaseURL(backendUrl.value)
  ElMessage.success('保存成功，页面即将刷新')
  
  setTimeout(() => {
    window.location.reload()
  }, 1000)
}

const testConnection = async () => {
  testing.value = true
  try {
    // 测试连接：尝试获取相册列表
    await api.getAlbums()
    connectionStatus.value = 'connected'
    ElMessage.success('连接成功')
  } catch (error) {
    connectionStatus.value = 'disconnected'
    ElMessage.error('连接失败，请检查后端服务地址')
  } finally {
    testing.value = false
  }
}

// 防盗链函数
const copySignedURL = () => {
  copy(signedURL.value)
  ElMessage.success('已复制到剪贴板')
}

const saveSettings = () => {
  // 保存防盗链设置
  localStorage.setItem('hotlink-settings', JSON.stringify(settings.value))
  
  // 保存显示设置
  localStorage.setItem('display-settings', JSON.stringify(displaySettings.value))
  
  // 保存上传设置
  localStorage.setItem('upload-settings', JSON.stringify(uploadSettings.value))
  
  // 保存性能设置
  localStorage.setItem('performance-settings', JSON.stringify(performanceSettings.value))
  
  // 保存通知设置
  localStorage.setItem('notification-settings', JSON.stringify(notificationSettings.value))
  
  ElMessage.success('所有设置已保存')
}

const resetSettings = () => {
  settings.value = {
    hotlinkProtection: false,
    tokenProtection: false,
    allowedDomains: ['localhost', '127.0.0.1'],
    tokenTTL: 3600
  }
  displaySettings.value = {
    theme: 'light',
    defaultView: 'grid',
    pageSize: 24,
    thumbnailQuality: 80,
    lazyLoad: true,
    showFileSize: true,
    showUploadDate: true
  }
  uploadSettings.value = {
    defaultFormat: 'original',
    quality: 85,
    maxFileSize: 10,
    allowedFormats: ['jpg', 'png', 'gif', 'webp'],
    autoThumbnail: true,
    keepExif: false
  }
  performanceSettings.value = {
    enableCache: true,
    cacheDuration: 300,
    preloadNextPage: true,
    concurrentUploads: 3,
    requestTimeout: 30000
  }
  notificationSettings.value = {
    uploadComplete: true,
    successNotify: true,
    errorNotify: true,
    duration: 3000,
    position: 'top-right'
  }
  ElMessage.success('已重置为默认设置')
}

// 清除缓存
const clearCache = () => {
  // 清除所有设置相关的缓存
  const keysToKeep = ['hotlink-settings', 'display-settings', 'upload-settings', 'performance-settings', 'notification-settings', 'token', 'config']
  const allKeys = Object.keys(localStorage)
  
  allKeys.forEach(key => {
    if (!keysToKeep.includes(key)) {
      localStorage.removeItem(key)
    }
  })
  
  // 清除 sessionStorage
  sessionStorage.clear()
  
  ElMessage.success('缓存已清除')
}

// 保存所有设置
const saveAllSettings = () => {
  saveSettings()
}

// 重置所有设置
const resetAllSettings = () => {
  ElMessageBox.confirm(
    '确定要重置所有设置为默认值吗？此操作不可撤销。',
    '警告',
    {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning',
    }
  ).then(() => {
    resetSettings()
  }).catch(() => {
    // 用户取消
  })
}

// 导出配置
const exportSettings = () => {
  const config = {
    version: '1.0',
    exportTime: new Date().toISOString(),
    settings: {
      display: displaySettings.value,
      upload: uploadSettings.value,
      performance: performanceSettings.value,
      notification: notificationSettings.value,
      hotlink: settings.value
    }
  }
  
  const blob = new Blob([JSON.stringify(config, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `tc-go-settings-${new Date().getTime()}.json`
  a.click()
  URL.revokeObjectURL(url)
  
  ElMessage.success('配置已导出')
}

// 导入配置
const importSettings = (file: File) => {
  const reader = new FileReader()
  
  reader.onload = (e) => {
    try {
      const config = JSON.parse(e.target?.result as string)
      
      if (!config.version || !config.settings) {
        throw new Error('无效的配置文件')
      }
      
      // 导入各项设置
      if (config.settings.display) {
        displaySettings.value = { ...displaySettings.value, ...config.settings.display }
        localStorage.setItem('display-settings', JSON.stringify(displaySettings.value))
      }
      
      if (config.settings.upload) {
        uploadSettings.value = { ...uploadSettings.value, ...config.settings.upload }
        localStorage.setItem('upload-settings', JSON.stringify(uploadSettings.value))
      }
      
      if (config.settings.performance) {
        performanceSettings.value = { ...performanceSettings.value, ...config.settings.performance }
        localStorage.setItem('performance-settings', JSON.stringify(performanceSettings.value))
      }
      
      if (config.settings.notification) {
        notificationSettings.value = { ...notificationSettings.value, ...config.settings.notification }
        localStorage.setItem('notification-settings', JSON.stringify(notificationSettings.value))
      }
      
      if (config.settings.hotlink) {
        settings.value = { ...settings.value, ...config.settings.hotlink }
        localStorage.setItem('hotlink-settings', JSON.stringify(settings.value))
      }
      
      ElMessage.success('配置导入成功')
    } catch (error) {
      ElMessage.error('配置文件格式错误')
    }
  }
  
  reader.readAsText(file)
  return false // 阻止自动上传
}

// 加载保存的设置
const loadSettings = () => {
  // 加载防盗链设置
  const hotlinkSaved = localStorage.getItem('hotlink-settings')
  if (hotlinkSaved) {
    settings.value = JSON.parse(hotlinkSaved)
  }
  
  // 加载显示设置
  const displaySaved = localStorage.getItem('display-settings')
  if (displaySaved) {
    displaySettings.value = JSON.parse(displaySaved)
  }
  
  // 加载上传设置
  const uploadSaved = localStorage.getItem('upload-settings')
  if (uploadSaved) {
    uploadSettings.value = JSON.parse(uploadSaved)
  }
  
  // 加载性能设置
  const performanceSaved = localStorage.getItem('performance-settings')
  if (performanceSaved) {
    performanceSettings.value = JSON.parse(performanceSaved)
  }
  
  // 加载通知设置
  const notificationSaved = localStorage.getItem('notification-settings')
  if (notificationSaved) {
    notificationSettings.value = JSON.parse(notificationSaved)
  }
}

// 初始化
onMounted(() => {
  loadSettings()
  
  // 加载后端地址配置
  const config = getConfig()
  backendUrl.value = config.backendUrl
  
  // 测试连接
  testConnection()
})
</script>

<style scoped>
.settings-page {
  padding: 24px;
  max-width: 1200px;
  margin: 0 auto;
}

.settings-card {
  margin-bottom: 24px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-weight: 600;
}

.form-tip {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}

.expires-info {
  font-size: 12px;
  color: #67C23A;
  padding: 8px;
  background: #f0f9ff;
  border-radius: 4px;
}

.info-card {
  margin-top: 24px;
}
</style>
