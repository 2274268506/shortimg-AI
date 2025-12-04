<template>
  <div class="users-page">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>用户管理</span>
          <div class="header-actions">
            <el-input v-model="searchKeyword" placeholder="搜索用户名或邮箱" style="width: 200px; margin-right: 10px" clearable
              @clear="handleSearch" @keyup.enter="handleSearch">
              <template #prefix>
                <el-icon>
                  <Search />
                </el-icon>
              </template>
            </el-input>
            <el-select v-model="filterStatus" placeholder="状态" style="width: 120px; margin-right: 10px" clearable
              @change="handleSearch">
              <el-option label="全部" value="" />
              <el-option label="启用" value="active" />
              <el-option label="禁用" value="disabled" />
            </el-select>
            <el-select v-model="filterRole" placeholder="角色" style="width: 120px; margin-right: 10px" clearable
              @change="handleSearch">
              <el-option label="全部" value="" />
              <el-option label="管理员" value="admin" />
              <el-option label="普通用户" value="user" />
            </el-select>
            <el-button type="primary" @click="handleRefresh" :icon="Refresh">
              刷新
            </el-button>
          </div>
        </div>
      </template>

      <el-table :data="users" v-loading="loading" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="username" label="用户名" width="150" />
        <el-table-column prop="email" label="邮箱" width="200" />
        <el-table-column prop="role" label="角色" width="120">
          <template #default="{ row }">
            <el-tag :type="row.role === 'admin' ? 'danger' : 'success'">
              {{ row.role === 'admin' ? '管理员' : '普通用户' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 'active' ? 'success' : 'info'">
              {{ row.status === 'active' ? '启用' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="lastLogin" label="最后登录" width="180">
          <template #default="{ row }">
            {{ row.lastLogin ? formatDate(row.lastLogin) : '从未登录' }}
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="注册时间" width="180">
          <template #default="{ row }">
            {{ formatDate(row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" fixed="right" width="280">
          <template #default="{ row }">
            <el-button size="small" @click="handleViewDetails(row)">
              详情
            </el-button>
            <el-button v-if="row.status === 'active'" size="small" type="warning" @click="handleToggleStatus(row)"
              :disabled="row.id === currentUser?.id">
              禁用
            </el-button>
            <el-button v-else size="small" type="success" @click="handleToggleStatus(row)">
              启用
            </el-button>
            <el-button v-if="row.role !== 'admin'" size="small" @click="handleSetAdmin(row)">
              设为管理员
            </el-button>
            <el-button size="small" type="primary" @click="handleResetPassword(row)">
              重置密码
            </el-button>
            <el-popconfirm v-if="row.id !== currentUser?.id" title="确定删除此用户吗？" @confirm="handleDelete(row.id)">
              <template #reference>
                <el-button size="small" type="danger">
                  删除
                </el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination">
        <el-pagination v-model:current-page="currentPage" v-model:page-size="pageSize" :page-sizes="[10, 20, 50, 100]"
          :total="total" layout="total, sizes, prev, pager, next, jumper" @size-change="handleSearch"
          @current-change="handleSearch" />
      </div>
    </el-card>

    <!-- 用户详情对话框 -->
    <el-dialog v-model="detailsDialogVisible" title="用户详情" width="600px">
      <div v-if="selectedUser" class="user-details">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="用户ID">{{ selectedUser.id }}</el-descriptions-item>
          <el-descriptions-item label="用户名">{{ selectedUser.username }}</el-descriptions-item>
          <el-descriptions-item label="邮箱">{{ selectedUser.email }}</el-descriptions-item>
          <el-descriptions-item label="角色">
            <el-tag :type="selectedUser.role === 'admin' ? 'danger' : 'success'">
              {{ selectedUser.role === 'admin' ? '管理员' : '普通用户' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="selectedUser.status === 'active' ? 'success' : 'info'">
              {{ selectedUser.status === 'active' ? '启用' : '禁用' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="注册时间">
            {{ formatDate(selectedUser.createdAt) }}
          </el-descriptions-item>
          <el-descriptions-item label="最后登录">
            {{ selectedUser.lastLogin ? formatDate(selectedUser.lastLogin) : '从未登录' }}
          </el-descriptions-item>
          <el-descriptions-item label="登录IP">
            {{ selectedUser.loginIP || '无' }}
          </el-descriptions-item>
          <el-descriptions-item label="个人简介" :span="2">
            {{ selectedUser.bio || '未填写' }}
          </el-descriptions-item>
        </el-descriptions>

        <el-divider>用户统计</el-divider>

        <el-descriptions v-if="userStats" :column="2" border>
          <el-descriptions-item label="图片数量">{{ userStats.totalImages }}</el-descriptions-item>
          <el-descriptions-item label="相册数量">{{ userStats.totalAlbums }}</el-descriptions-item>
          <el-descriptions-item label="存储空间">{{ formatSize(userStats.totalStorage) }}</el-descriptions-item>
          <el-descriptions-item label="总浏览量">{{ userStats.totalViews }}</el-descriptions-item>
          <el-descriptions-item label="总下载量">{{ userStats.totalDownloads }}</el-descriptions-item>
        </el-descriptions>
      </div>
    </el-dialog>

    <!-- 重置密码对话框 -->
    <el-dialog v-model="resetPasswordDialogVisible" title="重置密码" width="400px">
      <el-form :model="resetPasswordForm" label-width="100px">
        <el-form-item label="新密码">
          <el-input v-model="resetPasswordForm.newPassword" type="password" placeholder="请输入新密码" show-password />
        </el-form-item>
        <el-form-item label="确认密码">
          <el-input v-model="resetPasswordForm.confirmPassword" type="password" placeholder="请再次输入新密码" show-password />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="resetPasswordDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="confirmResetPassword">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh, Search } from '@element-plus/icons-vue'
import * as api from '@/api'
import type { User, UserStats } from '@/types'
import { getUser } from '@/utils/config'

const users = ref<User[]>([])
const loading = ref(false)
const currentUser = ref(getUser())

// 分页
const currentPage = ref(1)
const pageSize = ref(20)
const total = ref(0)

// 搜索和筛选
const searchKeyword = ref('')
const filterStatus = ref('')
const filterRole = ref('')

// 用户详情
const detailsDialogVisible = ref(false)
const selectedUser = ref<User | null>(null)
const userStats = ref<UserStats | null>(null)

// 重置密码
const resetPasswordDialogVisible = ref(false)
const resetPasswordForm = ref({
  userId: 0,
  newPassword: '',
  confirmPassword: ''
})

const loadUsers = async () => {
  loading.value = true
  try {
    const res = await api.getUsers({
      page: currentPage.value,
      pageSize: pageSize.value,
      keyword: searchKeyword.value,
      status: filterStatus.value,
      role: filterRole.value
    })
    const data = (res as any).data
    users.value = data.users || []
    total.value = data.total || 0
  } catch (error) {
    ElMessage.error('加载用户列表失败')
  } finally {
    loading.value = false
  }
}

const handleSearch = () => {
  currentPage.value = 1
  loadUsers()
}

const handleRefresh = () => {
  searchKeyword.value = ''
  filterStatus.value = ''
  filterRole.value = ''
  currentPage.value = 1
  loadUsers()
}

const handleViewDetails = async (user: User) => {
  selectedUser.value = user
  detailsDialogVisible.value = true

  // 加载用户统计信息
  try {
    const res = await api.getUserStats(user.id)
    userStats.value = (res as any).data
  } catch (error) {
    ElMessage.error('加载用户统计失败')
  }
}

const handleToggleStatus = async (user: User) => {
  const newStatus = user.status === 'active' ? 'disabled' : 'active'
  const action = newStatus === 'active' ? '启用' : '禁用'

  try {
    await ElMessageBox.confirm(
      `确定要${action}用户 "${user.username}" 吗？`,
      '确认操作',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    await api.updateUserStatus(user.id, newStatus)
    ElMessage.success(`${action}成功`)
    loadUsers()
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error(`${action}失败`)
    }
  }
}

const handleSetAdmin = async (user: User) => {
  try {
    await ElMessageBox.confirm(
      `确定要将用户 "${user.username}" 设为管理员吗？`,
      '确认操作',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    await api.updateUserRole(user.id, 'admin')
    ElMessage.success('设置成功')
    loadUsers()
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error('设置失败')
    }
  }
}

const handleResetPassword = (user: User) => {
  resetPasswordForm.value = {
    userId: user.id,
    newPassword: '',
    confirmPassword: ''
  }
  resetPasswordDialogVisible.value = true
}

const confirmResetPassword = async () => {
  const { userId, newPassword, confirmPassword } = resetPasswordForm.value

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
    await api.resetUserPassword(userId, newPassword)
    ElMessage.success('密码重置成功')
    resetPasswordDialogVisible.value = false
  } catch (error) {
    ElMessage.error('密码重置失败')
  }
}

const handleDelete = async (id: number) => {
  try {
    await api.deleteUser(id)
    ElMessage.success('删除成功')
    loadUsers()
  } catch (error) {
    ElMessage.error('删除失败')
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
  loadUsers()
})
</script>

<style scoped>
.users-page {
  padding: 24px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header-actions {
  display: flex;
  align-items: center;
}

.pagination {
  margin-top: 20px;
  display: flex;
  justify-content: flex-end;
}

.user-details {
  padding: 10px 0;
}
</style>
