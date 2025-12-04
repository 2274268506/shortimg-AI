<template>
  <div class="profile-page">
    <el-row :gutter="20">
      <!-- 个人信息卡片 -->
      <el-col :span="12">
        <el-card>
          <template #header>
            <div class="card-header">
              <span>个人信息</span>
              <el-button v-if="!editing" type="primary" size="small" @click="editing = true">
                编辑
              </el-button>
              <div v-else>
                <el-button size="small" @click="cancelEdit">取消</el-button>
                <el-button type="primary" size="small" @click="saveProfile">保存</el-button>
              </div>
            </div>
          </template>

          <el-form :model="profileForm" label-width="100px">
            <el-form-item label="用户名">
              <el-input v-model="profileForm.username" disabled />
            </el-form-item>
            <el-form-item label="邮箱">
              <el-input v-model="profileForm.email" disabled />
            </el-form-item>
            <el-form-item label="角色">
              <el-tag :type="profileForm.role === 'admin' ? 'danger' : 'success'">
                {{ profileForm.role === 'admin' ? '管理员' : '普通用户' }}
              </el-tag>
            </el-form-item>
            <el-form-item label="头像">
              <el-input v-model="profileForm.avatar" :disabled="!editing" placeholder="请输入头像URL" />
            </el-form-item>
            <el-form-item label="个人简介">
              <el-input v-model="profileForm.bio" :disabled="!editing" type="textarea" :rows="4"
                placeholder="请输入个人简介" />
            </el-form-item>
            <el-form-item label="注册时间">
              <span>{{ formatDate(profileForm.createdAt) }}</span>
            </el-form-item>
            <el-form-item label="最后登录">
              <span>{{ profileForm.lastLogin ? formatDate(profileForm.lastLogin) : '从未登录' }}</span>
            </el-form-item>
          </el-form>
        </el-card>
      </el-col>

      <!-- 修改密码卡片 -->
      <el-col :span="12">
        <el-card>
          <template #header>
            <span>修改密码</span>
          </template>

          <el-form :model="passwordForm" label-width="100px">
            <el-form-item label="当前密码">
              <el-input v-model="passwordForm.oldPassword" type="password" placeholder="请输入当前密码" show-password />
            </el-form-item>
            <el-form-item label="新密码">
              <el-input v-model="passwordForm.newPassword" type="password" placeholder="请输入新密码（至少6位）" show-password />
            </el-form-item>
            <el-form-item label="确认密码">
              <el-input v-model="passwordForm.confirmPassword" type="password" placeholder="请再次输入新密码" show-password />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" @click="changePassword">修改密码</el-button>
            </el-form-item>
          </el-form>
        </el-card>

        <!-- 用户统计卡片 -->
        <el-card style="margin-top: 20px">
          <template #header>
            <span>我的统计</span>
          </template>

          <el-descriptions v-if="userStats" :column="1" border>
            <el-descriptions-item label="图片数量">
              {{ userStats.totalImages }}
            </el-descriptions-item>
            <el-descriptions-item label="相册数量">
              {{ userStats.totalAlbums }}
            </el-descriptions-item>
            <el-descriptions-item label="存储空间">
              {{ formatSize(userStats.totalStorage) }}
            </el-descriptions-item>
            <el-descriptions-item label="总浏览量">
              {{ userStats.totalViews }}
            </el-descriptions-item>
            <el-descriptions-item label="总下载量">
              {{ userStats.totalDownloads }}
            </el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import * as api from '@/api'
import type { User, UserStats } from '@/types'
import { getUser, setUser } from '@/utils/config'

const editing = ref(false)
const profileForm = ref<User>({
  id: 0,
  username: '',
  email: '',
  role: '',
  avatar: '',
  bio: '',
  createdAt: '',
  updatedAt: ''
})

const originalProfile = ref<User | null>(null)

const passwordForm = ref({
  oldPassword: '',
  newPassword: '',
  confirmPassword: ''
})

const userStats = ref<UserStats | null>(null)

const loadProfile = async () => {
  try {
    const res = await api.getCurrentUser()
    const user = (res as any).data
    profileForm.value = { ...user }
    originalProfile.value = { ...user }
    setUser(user)

    // 加载用户统计
    loadStats()
  } catch (error) {
    ElMessage.error('加载个人信息失败')
  }
}

const loadStats = async () => {
  try {
    const currentUser = getUser()
    if (currentUser?.id) {
      const res = await api.getUserStats(currentUser.id)
      userStats.value = (res as any).data
    }
  } catch (error) {
    console.error('加载统计信息失败:', error)
  }
}

const cancelEdit = () => {
  if (originalProfile.value) {
    profileForm.value = { ...originalProfile.value }
  }
  editing.value = false
}

const saveProfile = async () => {
  try {
    await api.updateProfile({
      avatar: profileForm.value.avatar,
      bio: profileForm.value.bio
    })
    ElMessage.success('保存成功')
    editing.value = false
    loadProfile()
  } catch (error) {
    ElMessage.error('保存失败')
  }
}

const changePassword = async () => {
  const { oldPassword, newPassword, confirmPassword } = passwordForm.value

  if (!oldPassword) {
    ElMessage.warning('请输入当前密码')
    return
  }

  if (!newPassword) {
    ElMessage.warning('请输入新密码')
    return
  }

  if (newPassword.length < 6) {
    ElMessage.warning('密码长度至少为 6 位')
    return
  }

  if (newPassword !== confirmPassword) {
    ElMessage.warning('两次输入的密码不一致')
    return
  }

  try {
    await api.changePassword({
      oldPassword,
      newPassword
    })
    ElMessage.success('密码修改成功')
    passwordForm.value = {
      oldPassword: '',
      newPassword: '',
      confirmPassword: ''
    }
  } catch (error) {
    ElMessage.error('密码修改失败，请检查当前密码是否正确')
  }
}

const formatDate = (dateStr: string) => {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleString('zh-CN')
}

const formatSize = (bytes: number) => {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return (bytes / Math.pow(k, i)).toFixed(2) + ' ' + sizes[i]
}

onMounted(() => {
  loadProfile()
})
</script>

<style scoped>
.profile-page {
  padding: 24px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>
