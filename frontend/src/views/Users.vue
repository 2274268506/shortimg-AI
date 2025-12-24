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
            <el-button type="success" @click="handleCreateUser" :icon="Plus">
              新建用户
            </el-button>
            <el-button @click="handleExportUsers">
              导出用户
            </el-button>
          </div>
        </div>
      </template>

      <!-- 批量操作工具栏 -->
      <div v-if="selectedUsers.length > 0" class="batch-actions">
        <span class="batch-info">已选择 {{ selectedUsers.length }} 个用户</span>
        <el-button size="small" @click="handleBatchEnable">批量启用</el-button>
        <el-button size="small" type="warning" @click="handleBatchDisable">批量禁用</el-button>
        <el-popconfirm title="确定要删除选中的用户吗？此操作不可恢复！" @confirm="handleBatchDelete">
          <template #reference>
            <el-button size="small" type="danger">批量删除</el-button>
          </template>
        </el-popconfirm>
      </div>

      <el-table :data="users" v-loading="loading" stripe @selection-change="handleSelectionChange">
        <el-table-column type="selection" width="55" />
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
        <el-table-column label="操作" fixed="right" width="350">
          <template #default="{ row }">
            <el-button size="small" @click="handleViewDetails(row)">
              详情
            </el-button>
            <el-button size="small" type="primary" @click="handleEditUser(row)">
              编辑
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
    <el-dialog v-model="detailsDialogVisible" title="用户详情" width="800px">
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

        <el-divider>最近上传的图片</el-divider>

        <div v-loading="loadingRecentImages">
          <div v-if="recentImages.length > 0" class="recent-images">
            <div v-for="img in recentImages" :key="img.id" class="image-item">
              <el-image
                :src="img.thumbnail || img.url"
                :preview-src-list="[img.url]"
                fit="cover"
                class="thumbnail"
              />
              <div class="image-info">
                <div class="image-name">{{ img.originalName }}</div>
                <div class="image-meta">
                  <span>{{ formatSize(img.fileSize) }}</span>
                  <span>{{ formatDate(img.createdAt) }}</span>
                </div>
              </div>
            </div>
          </div>
          <el-empty v-else description="暂无图片" />
        </div>
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

    <!-- 创建用户对话框 -->
    <el-dialog v-model="createUserDialogVisible" title="创建用户" width="500px">
      <el-form :model="createUserForm" label-width="100px">
        <el-form-item label="用户名" required>
          <el-input v-model="createUserForm.username" placeholder="请输入用户名" />
        </el-form-item>
        <el-form-item label="邮箱" required>
          <el-input v-model="createUserForm.email" type="email" placeholder="请输入邮箱地址" />
        </el-form-item>
        <el-form-item label="密码" required>
          <el-input v-model="createUserForm.password" type="password" placeholder="请输入密码（至少6位）" show-password />
        </el-form-item>
        <el-form-item label="确认密码" required>
          <el-input v-model="createUserForm.confirmPassword" type="password" placeholder="请再次输入密码" show-password />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="createUserForm.role" placeholder="请选择角色">
            <el-option label="普通用户" value="user" />
            <el-option label="管理员" value="admin" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createUserDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="confirmCreateUser">创建</el-button>
      </template>
    </el-dialog>

    <!-- 编辑用户对话框 -->
    <el-dialog v-model="editUserDialogVisible" title="编辑用户" width="500px">
      <el-form :model="editUserForm" label-width="100px">
        <el-form-item label="用户名" required>
          <el-input v-model="editUserForm.username" placeholder="请输入用户名" />
        </el-form-item>
        <el-form-item label="邮箱" required>
          <el-input v-model="editUserForm.email" type="email" placeholder="请输入邮箱地址" />
        </el-form-item>
        <el-form-item label="个人简介">
          <el-input v-model="editUserForm.bio" type="textarea" :rows="3" placeholder="请输入个人简介" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editUserDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="confirmEditUser">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Refresh, Search, Plus } from '@element-plus/icons-vue'
import * as api from '@/api'
import type { User, UserStats, Image } from '@/types'
import { getUser } from '@/utils/config'

const users = ref<User[]>([])
const loading = ref(false)
const currentUser = ref(getUser())
const selectedUsers = ref<User[]>([])

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
const recentImages = ref<Image[]>([])
const loadingRecentImages = ref(false)

// 重置密码
const resetPasswordDialogVisible = ref(false)
const resetPasswordForm = ref({
  userId: 0,
  newPassword: '',
  confirmPassword: ''
})

// 创建用户
const createUserDialogVisible = ref(false)
const createUserForm = ref({
  username: '',
  email: '',
  password: '',
  confirmPassword: '',
  role: 'user'
})

// 编辑用户
const editUserDialogVisible = ref(false)
const editUserForm = ref({
  id: 0,
  username: '',
  email: '',
  bio: ''
})

// 表格选择
const handleSelectionChange = (selection: User[]) => {
  selectedUsers.value = selection
}

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
  recentImages.value = []

  // 加载用户统计信息
  try {
    const res = await api.getUserStats(user.id)
    userStats.value = (res as any).data
  } catch (error) {
    ElMessage.error('加载用户统计失败')
  }

  // 加载最近上传的图片
  loadingRecentImages.value = true
  try {
    const res = await api.getUserRecentImages(user.id, 6)
    recentImages.value = (res as any).data || []
  } catch (error) {
    console.error('加载用户图片失败', error)
  } finally {
    loadingRecentImages.value = false
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

// 批量操作
const handleBatchEnable = async () => {
  try {
    await ElMessageBox.confirm(
      `确定要启用选中的 ${selectedUsers.value.length} 个用户吗？`,
      '确认操作',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'info'
      }
    )

    for (const user of selectedUsers.value) {
      await api.updateUserStatus(user.id, 'active')
    }

    ElMessage.success('批量启用成功')
    loadUsers()
    selectedUsers.value = []
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error('批量启用失败')
    }
  }
}

const handleBatchDisable = async () => {
  // 过滤掉当前用户
  const filteredUsers = selectedUsers.value.filter(u => u.id !== currentUser.value?.id)

  if (filteredUsers.length === 0) {
    ElMessage.warning('无法禁用自己的账号')
    return
  }

  try {
    await ElMessageBox.confirm(
      `确定要禁用选中的 ${filteredUsers.length} 个用户吗？`,
      '确认操作',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    for (const user of filteredUsers) {
      await api.updateUserStatus(user.id, 'disabled')
    }

    ElMessage.success('批量禁用成功')
    loadUsers()
    selectedUsers.value = []
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error('批量禁用失败')
    }
  }
}

const handleBatchDelete = async () => {
  // 过滤掉当前用户
  const filteredUsers = selectedUsers.value.filter(u => u.id !== currentUser.value?.id)

  if (filteredUsers.length === 0) {
    ElMessage.warning('无法删除自己的账号')
    return
  }

  try {
    for (const user of filteredUsers) {
      await api.deleteUser(user.id)
    }

    ElMessage.success('批量删除成功')
    loadUsers()
    selectedUsers.value = []
  } catch (error) {
    ElMessage.error('批量删除失败')
  }
}

// 创建用户
const handleCreateUser = () => {
  createUserForm.value = {
    username: '',
    email: '',
    password: '',
    confirmPassword: '',
    role: 'user'
  }
  createUserDialogVisible.value = true
}

const confirmCreateUser = async () => {
  const { username, email, password, confirmPassword, role } = createUserForm.value

  if (!username) {
    ElMessage.warning('请输入用户名')
    return
  }

  if (!email) {
    ElMessage.warning('请输入邮箱')
    return
  }

  if (!password) {
    ElMessage.warning('请输入密码')
    return
  }

  if (password.length < 6) {
    ElMessage.warning('密码长度至少为 6 位')
    return
  }

  if (password !== confirmPassword) {
    ElMessage.warning('两次输入的密码不一致')
    return
  }

  try {
    await api.createUser({
      username,
      email,
      password,
      role
    })
    ElMessage.success('用户创建成功')
    createUserDialogVisible.value = false
    loadUsers()
  } catch (error) {
    ElMessage.error('用户创建失败')
  }
}

// 编辑用户
const handleEditUser = (user: User) => {
  editUserForm.value = {
    id: user.id,
    username: user.username,
    email: user.email,
    bio: user.bio || ''
  }
  editUserDialogVisible.value = true
}

const confirmEditUser = async () => {
  const { id, username, email, bio } = editUserForm.value

  if (!username) {
    ElMessage.warning('请输入用户名')
    return
  }

  if (!email) {
    ElMessage.warning('请输入邮箱')
    return
  }

  try {
    await api.updateUser(id, {
      username,
      email,
      bio
    })
    ElMessage.success('用户信息更新成功')
    editUserDialogVisible.value = false
    loadUsers()
  } catch (error) {
    ElMessage.error('用户信息更新失败')
  }
}

// 导出用户列表
const handleExportUsers = () => {
  try {
    // 生成 CSV 内容
    const headers = ['ID', '用户名', '邮箱', '角色', '状态', '注册时间', '最后登录', '登录IP']
    const csvRows = [headers.join(',')]

    users.value.forEach(user => {
      const row = [
        user.id,
        user.username,
        user.email,
        user.role === 'admin' ? '管理员' : '普通用户',
        user.status === 'active' ? '启用' : '禁用',
        formatDate(user.createdAt),
        user.lastLogin ? formatDate(user.lastLogin) : '从未登录',
        user.loginIP || '无'
      ]
      csvRows.push(row.map(v => `"${v}"`).join(','))
    })

    // 创建 Blob 并下载
    const csvContent = '\uFEFF' + csvRows.join('\n') // \uFEFF 是 BOM，确保 Excel 正确识别 UTF-8
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    const url = URL.createObjectURL(blob)

    link.setAttribute('href', url)
    link.setAttribute('download', `用户列表_${new Date().toISOString().split('T')[0]}.csv`)
    link.style.visibility = 'hidden'

    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)

    ElMessage.success('导出成功')
  } catch (error) {
    ElMessage.error('导出失败')
  }
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

.batch-actions {
  padding: 12px;
  background-color: #f5f7fa;
  border-radius: 4px;
  margin-bottom: 16px;
  display: flex;
  align-items: center;
  gap: 10px;
}

.batch-info {
  margin-right: 10px;
  font-weight: 500;
  color: #409eff;
}

.recent-images {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 16px;
  margin-top: 16px;
}

.image-item {
  border: 1px solid #e4e7ed;
  border-radius: 8px;
  overflow: hidden;
  transition: all 0.3s;
  cursor: pointer;
}

.image-item:hover {
  box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
  transform: translateY(-2px);
}

.image-item .thumbnail {
  width: 100%;
  height: 150px;
  object-fit: cover;
}

.image-item .image-info {
  padding: 8px 12px;
  background: #fff;
}

.image-item .image-name {
  font-size: 14px;
  font-weight: 500;
  color: #303133;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-bottom: 4px;
}

.image-item .image-meta {
  font-size: 12px;
  color: #909399;
  display: flex;
  justify-content: space-between;
}
</style>
