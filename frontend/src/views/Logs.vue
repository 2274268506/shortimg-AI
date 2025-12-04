<template>
  <div class="logs-page">
    <!-- 权限检查提示 -->
    <el-alert
      v-if="!isAdmin"
      title="权限不足"
      type="warning"
      description="您需要管理员权限才能查看日志。请联系管理员获取权限。"
      :closable="false"
      show-icon
      style="margin-bottom: 20px"
    />

    <el-card v-if="isAdmin">
      <template #header>
        <div class="card-header">
          <h2>日志管理</h2>
          <div class="header-actions">
            <el-button :icon="Download" @click="exportLogs">
              导出日志
            </el-button>
            <el-popconfirm
              title="确定清理90天前的日志吗？"
              @confirm="handleClearLogs"
            >
              <template #reference>
                <el-button :icon="Delete" type="danger">
                  清理旧日志
                </el-button>
              </template>
            </el-popconfirm>
          </div>
        </div>
      </template>

      <el-tabs v-model="activeTab" @tab-change="handleTabChange">
        <el-tab-pane label="操作日志" name="operation">
          <div class="filter-bar">
            <el-select v-model="operationFilters.module" placeholder="模块" clearable style="width: 150px">
              <el-option label="图片" value="image" />
              <el-option label="相册" value="album" />
              <el-option label="用户" value="user" />
            </el-select>
            <el-select v-model="operationFilters.action" placeholder="操作" clearable style="width: 150px">
              <el-option label="创建" value="create" />
              <el-option label="更新" value="update" />
              <el-option label="删除" value="delete" />
              <el-option label="上传" value="upload" />
              <el-option label="下载" value="download" />
            </el-select>
            <el-button type="primary" @click="loadOperationLogs">查询</el-button>
            <el-button @click="resetOperationFilters">重置</el-button>
          </div>

          <el-table :data="operationLogs" style="width: 100%" v-loading="loading">
            <el-table-column prop="id" label="ID" width="80" />
            <el-table-column prop="created_at" label="时间" width="180">
              <template #default="{ row }">
                {{ formatDate(row.created_at) }}
              </template>
            </el-table-column>
            <el-table-column prop="username" label="用户" width="120" />
            <el-table-column prop="module" label="模块" width="100">
              <template #default="{ row }">
                <el-tag :type="getModuleType(row.module)">{{ row.module }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="action" label="操作" width="100">
              <template #default="{ row }">
                <el-tag :type="getActionType(row.action)">{{ row.action }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="description" label="描述" min-width="200" />
            <el-table-column prop="ip" label="IP" width="130" />
            <el-table-column prop="status" label="状态" width="80">
              <template #default="{ row }">
                <el-tag :type="row.status < 400 ? 'success' : 'danger'">
                  {{ row.status }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="latency" label="耗时(ms)" width="100" />
          </el-table>

          <el-pagination
            v-model:current-page="operationPage"
            v-model:page-size="operationPageSize"
            :total="operationTotal"
            :page-sizes="[20, 50, 100]"
            layout="total, sizes, prev, pager, next"
            @current-change="loadOperationLogs"
            @size-change="loadOperationLogs"
            style="margin-top: 20px; justify-content: center"
          />
        </el-tab-pane>

        <el-tab-pane label="系统日志" name="system">
          <div class="filter-bar">
            <el-select v-model="systemFilters.level" placeholder="级别" clearable style="width: 150px">
              <el-option label="Debug" value="debug" />
              <el-option label="Info" value="info" />
              <el-option label="Warn" value="warn" />
              <el-option label="Error" value="error" />
            </el-select>
            <el-input
              v-model="systemFilters.module"
              placeholder="模块"
              clearable
              style="width: 200px"
            />
            <el-button type="primary" @click="loadSystemLogs">查询</el-button>
            <el-button @click="resetSystemFilters">重置</el-button>
          </div>

          <el-table :data="systemLogs" style="width: 100%" v-loading="loading">
            <el-table-column prop="id" label="ID" width="80" />
            <el-table-column prop="created_at" label="时间" width="180">
              <template #default="{ row }">
                {{ formatDate(row.created_at) }}
              </template>
            </el-table-column>
            <el-table-column prop="level" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="getLevelType(row.level)">{{ row.level }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="module" label="模块" width="150" />
            <el-table-column prop="message" label="消息" min-width="300" />
            <el-table-column prop="error" label="错误" min-width="200">
              <template #default="{ row }">
                <span style="color: #f56c6c; font-family: monospace; font-size: 12px">
                  {{ row.error }}
                </span>
              </template>
            </el-table-column>
          </el-table>

          <el-pagination
            v-model:current-page="systemPage"
            v-model:page-size="systemPageSize"
            :total="systemTotal"
            :page-sizes="[20, 50, 100]"
            layout="total, sizes, prev, pager, next"
            @current-change="loadSystemLogs"
            @size-change="loadSystemLogs"
            style="margin-top: 20px; justify-content: center"
          />
        </el-tab-pane>

        <el-tab-pane label="前端日志" name="frontend">
          <div class="filter-bar">
            <el-select v-model="frontendFilter" placeholder="日志级别" clearable style="width: 150px">
              <el-option label="All" value="" />
              <el-option label="Debug" value="debug" />
              <el-option label="Info" value="info" />
              <el-option label="Warn" value="warn" />
              <el-option label="Error" value="error" />
            </el-select>
            <el-button :icon="Download" @click="downloadFrontendLogs">下载日志</el-button>
            <el-button :icon="Delete" type="danger" @click="clearFrontendLogs">清空日志</el-button>
          </div>

          <el-table :data="filteredFrontendLogs" style="width: 100%" max-height="600">
            <el-table-column prop="timestamp" label="时间" width="180" />
            <el-table-column prop="level" label="级别" width="100">
              <template #default="{ row }">
                <el-tag :type="getLevelType(row.level)">{{ row.level }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="module" label="模块" width="150" />
            <el-table-column prop="message" label="消息" min-width="300" />
            <el-table-column label="详情" width="100">
              <template #default="{ row }">
                <el-button size="small" @click="showLogDetail(row)">查看</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <!-- 日志详情对话框 -->
    <el-dialog v-model="showDetailDialog" title="日志详情" width="800px">
      <pre style="max-height: 500px; overflow: auto">{{ JSON.stringify(selectedLog, null, 2) }}</pre>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Download, Delete } from '@element-plus/icons-vue'
import { getOperationLogs, getSystemLogs, clearOldLogs, type OperationLog, type SystemLog } from '@/api/logs'
import { logger, type LogEntry } from '@/utils/logger'
import { getUser } from '@/utils/config'

const activeTab = ref('operation')
const loading = ref(false)

// 检查用户权限
const user = getUser()
const isAdmin = computed(() => user && user.role === 'admin')

// 操作日志
const operationLogs = ref<OperationLog[]>([])
const operationPage = ref(1)
const operationPageSize = ref(20)
const operationTotal = ref(0)
const operationFilters = ref({
  module: '',
  action: ''
})

// 系统日志
const systemLogs = ref<SystemLog[]>([])
const systemPage = ref(1)
const systemPageSize = ref(20)
const systemTotal = ref(0)
const systemFilters = ref({
  level: '',
  module: ''
})

// 前端日志
const frontendLogs = ref<LogEntry[]>([])
const frontendFilter = ref('')
const filteredFrontendLogs = computed(() => {
  if (!frontendFilter.value) {
    return frontendLogs.value
  }
  return frontendLogs.value.filter(log => log.level === frontendFilter.value)
})

// 日志详情
const showDetailDialog = ref(false)
const selectedLog = ref<any>(null)

// 加载操作日志
const loadOperationLogs = async () => {
  loading.value = true
  try {
    const response = await getOperationLogs({
      page: operationPage.value,
      pageSize: operationPageSize.value,
      ...operationFilters.value
    }) as any
    operationLogs.value = response.data as OperationLog[]
    operationTotal.value = response.pagination.total
  } catch (error: any) {
    // 检查是否是权限错误
    if (error?.response?.status === 401 || error?.response?.status === 403) {
      ElMessage.error('需要管理员权限才能查看日志')
    } else {
      ElMessage.error('加载操作日志失败')
    }
    logger.error('Failed to load operation logs', 'Logs', error)
  } finally {
    loading.value = false
  }
}

// 加载系统日志
const loadSystemLogs = async () => {
  loading.value = true
  try {
    const response = await getSystemLogs({
      page: systemPage.value,
      pageSize: systemPageSize.value,
      ...systemFilters.value
    }) as any
    systemLogs.value = response.data as SystemLog[]
    systemTotal.value = response.pagination.total
  } catch (error: any) {
    // 检查是否是权限错误
    if (error?.response?.status === 401 || error?.response?.status === 403) {
      ElMessage.error('需要管理员权限才能查看日志')
    } else {
      ElMessage.error('加载系统日志失败')
    }
    logger.error('Failed to load system logs', 'Logs', error)
  } finally {
    loading.value = false
  }
}

// 加载前端日志
const loadFrontendLogs = () => {
  frontendLogs.value = logger.getLogs().reverse() // 最新的在前
}

// 标签页切换
const handleTabChange = (name: string) => {
  if (name === 'operation') {
    loadOperationLogs()
  } else if (name === 'system') {
    loadSystemLogs()
  } else if (name === 'frontend') {
    loadFrontendLogs()
  }
}

// 重置筛选
const resetOperationFilters = () => {
  operationFilters.value = { module: '', action: '' }
  loadOperationLogs()
}

const resetSystemFilters = () => {
  systemFilters.value = { level: '', module: '' }
  loadSystemLogs()
}

// 清理旧日志
const handleClearLogs = async () => {
  try {
    await clearOldLogs(90)
    ElMessage.success('旧日志已清理')
    if (activeTab.value === 'operation') {
      loadOperationLogs()
    } else {
      loadSystemLogs()
    }
  } catch (error) {
    ElMessage.error('清理日志失败')
  }
}

// 导出日志
const exportLogs = () => {
  const logs = activeTab.value === 'operation' ? operationLogs.value : systemLogs.value
  const dataStr = JSON.stringify(logs, null, 2)
  const dataBlob = new Blob([dataStr], { type: 'application/json' })
  const url = URL.createObjectURL(dataBlob)
  const link = document.createElement('a')
  link.href = url
  link.download = `${activeTab.value}-logs-${new Date().toISOString()}.json`
  link.click()
  URL.revokeObjectURL(url)
}

// 下载前端日志
const downloadFrontendLogs = () => {
  logger.downloadLogs()
}

// 清空前端日志
const clearFrontendLogs = () => {
  logger.clearLogs()
  loadFrontendLogs()
  ElMessage.success('前端日志已清空')
}

// 查看日志详情
const showLogDetail = (log: LogEntry) => {
  selectedLog.value = log
  showDetailDialog.value = true
}

// 工具函数
const formatDate = (dateStr: string) => {
  return new Date(dateStr).toLocaleString('zh-CN')
}

const getModuleType = (module: string) => {
  const types: Record<string, any> = {
    image: 'primary',
    album: 'success',
    user: 'warning'
  }
  return types[module] || 'info'
}

const getActionType = (action: string) => {
  const types: Record<string, any> = {
    create: 'success',
    update: 'primary',
    delete: 'danger',
    upload: 'success',
    download: 'info'
  }
  return types[action] || 'info'
}

const getLevelType = (level: string) => {
  const types: Record<string, any> = {
    debug: 'info',
    info: 'success',
    warn: 'warning',
    error: 'danger'
  }
  return types[level.toLowerCase()] || 'info'
}

onMounted(() => {
  // 仅在用户是管理员时加载日志
  if (isAdmin.value) {
    loadOperationLogs()
    logger.info('Logs page mounted', 'Logs')
  } else {
    ElMessage.warning('需要管理员权限才能查看日志')
    logger.warn('Non-admin user attempted to access logs page', 'Logs')
  }
})
</script>

<style scoped>
.logs-page {
  padding: 20px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.card-header h2 {
  margin: 0;
  font-size: 20px;
}

.header-actions {
  display: flex;
  gap: 12px;
}

.filter-bar {
  display: flex;
  gap: 12px;
  margin-bottom: 20px;
}

:deep(.el-table) {
  font-size: 14px;
}

:deep(.el-pagination) {
  display: flex;
}
</style>
