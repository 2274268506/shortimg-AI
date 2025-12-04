<template>
  <div class="users-page">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>用户管理</span>
          <el-button type="primary" @click="handleRefresh" :icon="Refresh">
            刷新
          </el-button>
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
        <el-table-column prop="createdAt" label="注册时间" width="180">
          <template #default="{ row }">
            {{ formatDate(row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" fixed="right" width="200">
          <template #default="{ row }">
            <el-button
              v-if="row.role !== 'admin'"
              size="small"
              @click="handleSetAdmin(row)"
            >
              设为管理员
            </el-button>
            <el-popconfirm
              v-if="row.id !== currentUser?.id"
              title="确定删除此用户吗？"
              @confirm="handleDelete(row.id)"
            >
              <template #reference>
                <el-button size="small" type="danger">
                  删除
                </el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { Refresh } from '@element-plus/icons-vue'
import * as api from '@/api'
import type { User } from '@/types'
import { getUser } from '@/utils/config'

const users = ref<User[]>([])
const loading = ref(false)
const currentUser = ref(getUser())

const loadUsers = async () => {
  loading.value = true
  try {
    const res = await api.getUsers()
    users.value = (res as any).data || []
  } catch (error) {
    ElMessage.error('加载用户列表失败')
  } finally {
    loading.value = false
  }
}

const handleRefresh = () => {
  loadUsers()
}

const handleSetAdmin = async (user: User) => {
  try {
    await api.updateUserRole(user.id, 'admin')
    ElMessage.success('设置成功')
    loadUsers()
  } catch (error) {
    ElMessage.error('设置失败')
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
</style>
