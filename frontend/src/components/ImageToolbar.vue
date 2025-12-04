<template>
  <div class="toolbar">
    <div class="toolbar-left">
      <h1>
        <el-icon>
          <Picture />
        </el-icon>
        图床管理系统
      </h1>
      <div class="toolbar-nav">
        <router-link to="/" class="nav-link" active-class="active">
          <el-icon>
            <Files />
          </el-icon>
          资源管理
        </router-link>
        <router-link to="/statistics" class="nav-link" active-class="active">
          <el-icon>
            <DataAnalysis />
          </el-icon>
          使用统计
        </router-link>
        <router-link to="/settings" class="nav-link" active-class="active">
          <el-icon>
            <Setting />
          </el-icon>
          系统设置
        </router-link>
        <router-link v-if="isAdmin" to="/users" class="nav-link" active-class="active">
          <el-icon>
            <UserFilled />
          </el-icon>
          用户管理
        </router-link>
        <router-link v-if="isAdmin" to="/logs" class="nav-link" active-class="active">
          <el-icon>
            <Document />
          </el-icon>
          日志管理
        </router-link>
      </div>
    </div>
    <div class="toolbar-right">
      <el-button type="primary" :icon="Upload" @click="$emit('upload')">
        上传图片
      </el-button>
      <el-button :icon="FolderAdd" @click="$emit('createAlbum')">
        新建相册
      </el-button>

      <el-dropdown v-if="currentUser" @command="handleCommand" trigger="click">
        <el-button :icon="User">
          {{ currentUser.username }}
        </el-button>
        <template #dropdown>
          <el-dropdown-menu>
            <el-dropdown-item command="profile">
              <el-icon>
                <User />
              </el-icon>
              个人信息
            </el-dropdown-item>
            <el-dropdown-item command="logout" divided>
              <el-icon>
                <SwitchButton />
              </el-icon>
              退出登录
            </el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Picture, Upload, FolderAdd, Files, DataAnalysis, Setting, UserFilled, User, SwitchButton, Document } from '@element-plus/icons-vue'
import { getUser, clearAuth } from '@/utils/config'

defineEmits(['upload', 'createAlbum'])

const router = useRouter()
const currentUser = computed(() => getUser())
const isAdmin = computed(() => currentUser.value?.role === 'admin')

const handleCommand = async (command) => {
  if (command === 'logout') {
    try {
      await ElMessageBox.confirm('确定要退出登录吗？', '提示', {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      })

      clearAuth()
      ElMessage.success('已退出登录')
      router.push('/login')
    } catch {
      // 用户取消
    }
  } else if (command === 'profile') {
    router.push('/profile')
  }
}
</script>

<style scoped>
.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  background-color: #fff;
  border-bottom: 1px solid #e4e7ed;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.04);
  flex-wrap: wrap;
  gap: 12px;
}

.toolbar-left {
  display: flex;
  align-items: center;
  gap: 40px;
  flex-wrap: wrap;
}

.toolbar-left h1 {
  font-size: 20px;
  font-weight: 600;
  color: #303133;
  display: flex;
  align-items: center;
  gap: 8px;
}

.toolbar-nav {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border-radius: 6px;
  color: #606266;
  text-decoration: none;
  font-size: 14px;
  transition: all 0.3s;
}

.nav-link:hover {
  background-color: #f5f7fa;
  color: #409eff;
}

.nav-link.active {
  background-color: #ecf5ff;
  color: #409eff;
  font-weight: 500;
}

.toolbar-right {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

/* 响应式设计 - 平板 */
@media (max-width: 1024px) {
  .toolbar {
    padding: 12px 16px;
  }

  .toolbar-left {
    gap: 20px;
  }

  .toolbar-left h1 {
    font-size: 18px;
  }

  .nav-link {
    padding: 6px 12px;
    font-size: 13px;
  }
}

/* 响应式设计 - 手机 */
@media (max-width: 768px) {
  .toolbar {
    flex-direction: column;
    align-items: stretch;
    padding: 12px;
    gap: 12px;
  }

  .toolbar-left {
    flex-direction: column;
    align-items: flex-start;
    gap: 12px;
    width: 100%;
  }

  .toolbar-left h1 {
    font-size: 16px;
  }

  .toolbar-nav {
    width: 100%;
    justify-content: flex-start;
    gap: 6px;
  }

  .nav-link {
    flex: 1;
    justify-content: center;
    padding: 8px 8px;
    font-size: 12px;
  }

  .nav-link .el-icon {
    display: none;
  }

  .toolbar-right {
    width: 100%;
    justify-content: stretch;
  }

  .toolbar-right .el-button {
    flex: 1;
    font-size: 13px;
  }
}

/* 响应式设计 - 小屏手机 */
@media (max-width: 480px) {
  .toolbar-left h1 .el-icon {
    display: none;
  }

  .nav-link {
    padding: 6px 4px;
    font-size: 11px;
  }

  .toolbar-right .el-button span {
    display: none;
  }
}
</style>
