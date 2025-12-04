<template>
  <div class="statistics-page">
    <div class="page-header">
      <h1>
        <el-icon><DataAnalysis /></el-icon>
        使用统计
      </h1>
    </div>

    <!-- 总览卡片 -->
    <div class="overview-cards">
      <el-card class="stat-card">
        <div class="stat-content">
          <div class="stat-icon primary">
            <el-icon><Picture /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-label">总图片数</div>
            <div class="stat-value">{{ formatNumber(overview.totalImages) }}</div>
          </div>
        </div>
      </el-card>

      <el-card class="stat-card">
        <div class="stat-content">
          <div class="stat-icon success">
            <el-icon><View /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-label">总访问次数</div>
            <div class="stat-value">{{ formatNumber(overview.totalViews) }}</div>
          </div>
        </div>
      </el-card>

      <el-card class="stat-card">
        <div class="stat-content">
          <div class="stat-icon warning">
            <el-icon><Download /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-label">总下载次数</div>
            <div class="stat-value">{{ formatNumber(overview.totalDownloads) }}</div>
          </div>
        </div>
      </el-card>

      <el-card class="stat-card">
        <div class="stat-content">
          <div class="stat-icon danger">
            <el-icon><Document /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-label">总存储空间</div>
            <div class="stat-value">{{ formatFileSize(overview.totalSize) }}</div>
          </div>
        </div>
      </el-card>
    </div>

    <!-- 今日数据 -->
    <el-row :gutter="20" style="margin-top: 20px">
      <el-col :span="12">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>今日数据</span>
              <el-tag type="success">{{ currentDate }}</el-tag>
            </div>
          </template>
          <div class="today-stats">
            <div class="today-item">
              <span class="label">访问次数:</span>
              <span class="value">{{ formatNumber(today.views) }}</span>
            </div>
            <div class="today-item">
              <span class="label">下载次数:</span>
              <span class="value">{{ formatNumber(today.downloads) }}</span>
            </div>
            <div class="today-item">
              <span class="label">上传图片:</span>
              <span class="value">{{ formatNumber(today.uploads) }}</span>
            </div>
            <div class="today-item">
              <span class="label">流量消耗:</span>
              <span class="value">{{ formatFileSize(today.traffic) }}</span>
            </div>
          </div>
        </el-card>
      </el-col>

      <el-col :span="12">
        <el-card>
          <template #header>
            <span>相册统计</span>
          </template>
          <div class="album-stats-container">
            <el-scrollbar max-height="200px">
              <div class="album-stat-item" v-for="album in albumStats" :key="album.id">
                <div class="album-name">{{ album.name }}</div>
                <div class="album-info-grid">
                  <div class="info-item">
                    <span class="label">图片数:</span>
                    <span class="value">{{ album.imageCount }}</span>
                  </div>
                  <div class="info-item">
                    <span class="label">大小:</span>
                    <span class="value">{{ formatFileSize(album.totalSize) }}</span>
                  </div>
                  <div class="info-item">
                    <span class="label">访问:</span>
                    <span class="value">{{ formatNumber(album.totalViews) }}</span>
                  </div>
                </div>
              </div>
            </el-scrollbar>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 趋势图表 -->
    <el-row :gutter="20" style="margin-top: 20px">
      <el-col :span="24">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>访问趋势</span>
              <el-radio-group v-model="chartPeriod" size="small" @change="handlePeriodChange">
                <el-radio-button value="7">最近7天</el-radio-button>
                <el-radio-button value="30">最近30天</el-radio-button>
              </el-radio-group>
            </div>
          </template>
          <div ref="chartContainer" style="height: 300px"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 热门图片 -->
    <el-card style="margin-top: 20px">
      <template #header>
        <span>热门图片 TOP 10</span>
      </template>
      <el-table :data="topImages" stripe>
        <el-table-column type="index" label="排名" width="80" />
        <el-table-column label="预览" width="100">
          <template #default="{ row }">
            <img :src="row.url" class="preview-thumb" />
          </template>
        </el-table-column>
        <el-table-column prop="fileName" label="文件名" min-width="200" show-overflow-tooltip />
        <el-table-column label="访问次数" width="120">
          <template #default="{ row }">
            <el-tag type="success">{{ formatNumber(row.viewCount) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="下载次数" width="120">
          <template #default="{ row }">
            <el-tag type="warning">{{ formatNumber(row.downloadCount) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="文件大小" width="120">
          <template #default="{ row }">
            {{ formatFileSize(row.fileSize) }}
          </template>
        </el-table-column>
        <el-table-column label="最后访问" width="180">
          <template #default="{ row }">
            {{ row.lastViewAt ? formatDate(row.lastViewAt) : '从未访问' }}
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { getStatistics } from '@/api'
import { ElMessage } from 'element-plus'
import {
  DataAnalysis,
  Picture,
  View,
  Download,
  Document
} from '@element-plus/icons-vue'
import * as echarts from 'echarts'

const overview = ref({
  totalImages: 0,
  totalSize: 0,
  totalViews: 0,
  totalDownloads: 0
})

const today = ref({
  views: 0,
  downloads: 0,
  uploads: 0,
  traffic: 0
})

const albumStats = ref([])
const topImages = ref([])
const chartPeriod = ref('7')
const recent7Days = ref([])
const recent30Days = ref([])
const chartContainer = ref(null)
let chartInstance = null

const currentDate = computed(() => {
  return new Date().toLocaleDateString('zh-CN')
})

const loadStatistics = async () => {
  try {
    const res = await getStatistics()
    const data = res.data
    
    overview.value = data.overview
    today.value = data.today
    albumStats.value = data.albumStats || []
    
    // topImages 已经包含完整的 URL (后端生成)
    topImages.value = data.topImages || []
    
    recent7Days.value = data.recent7Days || []
    recent30Days.value = data.recent30Days || []
    
    // 初始化图表
    initChart()
  } catch (error) {
    ElMessage.error('加载统计数据失败')
    console.error(error)
  }
}

const initChart = () => {
  if (!chartContainer.value) return
  
  if (chartInstance) {
    chartInstance.dispose()
  }
  
  chartInstance = echarts.init(chartContainer.value)
  updateChart()
}

const updateChart = () => {
  if (!chartInstance) return
  
  const data = chartPeriod.value === '7' ? recent7Days.value : recent30Days.value
  const dates = data.map(item => item.date).reverse()
  const views = data.map(item => item.totalViews).reverse()
  const downloads = data.map(item => item.totalDownloads).reverse()
  const uploads = data.map(item => item.totalUploads).reverse()
  
  const option = {
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'cross'
      }
    },
    legend: {
      data: ['访问次数', '下载次数', '上传数量']
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: dates
    },
    yAxis: {
      type: 'value'
    },
    series: [
      {
        name: '访问次数',
        type: 'line',
        smooth: true,
        data: views,
        itemStyle: { color: '#67C23A' }
      },
      {
        name: '下载次数',
        type: 'line',
        smooth: true,
        data: downloads,
        itemStyle: { color: '#E6A23C' }
      },
      {
        name: '上传数量',
        type: 'line',
        smooth: true,
        data: uploads,
        itemStyle: { color: '#409EFF' }
      }
    ]
  }
  
  chartInstance.setOption(option)
}

const handlePeriodChange = () => {
  updateChart()
}

const formatNumber = (num) => {
  if (!num) return '0'
  return num.toLocaleString()
}

const formatFileSize = (bytes) => {
  if (!bytes) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
}

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleString('zh-CN')
}

onMounted(() => {
  loadStatistics()
  
  // 监听窗口大小变化
  window.addEventListener('resize', () => {
    if (chartInstance) {
      chartInstance.resize()
    }
  })
})
</script>

<style scoped>
.statistics-page {
  padding: 20px;
  background-color: #f5f7fa;
  min-height: 100vh;
}

.page-header {
  margin-bottom: 20px;
}

.page-header h1 {
  font-size: 24px;
  font-weight: 600;
  color: #303133;
  display: flex;
  align-items: center;
  gap: 10px;
}

.overview-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
  margin-bottom: 20px;
}

.stat-card {
  cursor: pointer;
  transition: all 0.3s;
}

.stat-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.1);
}

.stat-content {
  display: flex;
  align-items: center;
  gap: 20px;
}

.stat-icon {
  width: 60px;
  height: 60px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 28px;
  color: white;
}

.stat-icon.primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.stat-icon.success {
  background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
}

.stat-icon.warning {
  background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%);
}

.stat-icon.danger {
  background: linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%);
}

.stat-info {
  flex: 1;
}

.stat-label {
  font-size: 14px;
  color: #909399;
  margin-bottom: 8px;
}

.stat-value {
  font-size: 28px;
  font-weight: 600;
  color: #303133;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.today-stats {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 15px;
}

.today-item {
  display: flex;
  justify-content: space-between;
  padding: 12px;
  background-color: #f5f7fa;
  border-radius: 8px;
}

.today-item .label {
  color: #606266;
  font-size: 14px;
}

.today-item .value {
  color: #303133;
  font-size: 16px;
  font-weight: 600;
}

.album-stats-container {
  max-height: 200px;
}

.album-stat-item {
  padding: 12px;
  margin-bottom: 10px;
  background-color: #f5f7fa;
  border-radius: 8px;
}

.album-stat-item:last-child {
  margin-bottom: 0;
}

.album-name {
  font-weight: 600;
  color: #303133;
  margin-bottom: 8px;
}

.album-info-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}

.info-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.info-item .label {
  font-size: 12px;
  color: #909399;
}

.info-item .value {
  font-size: 14px;
  color: #303133;
  font-weight: 500;
}

.preview-thumb {
  width: 60px;
  height: 60px;
  object-fit: cover;
  border-radius: 4px;
  cursor: pointer;
}

.preview-thumb:hover {
  transform: scale(1.1);
  transition: transform 0.3s;
}
</style>
