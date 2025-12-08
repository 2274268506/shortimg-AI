<template>
  <div class="login-page">
    <el-card class="login-card">
      <template #header>
        <div class="login-header">
          <h2>{{ isLogin ? '登录' : '注册' }}</h2>
          <el-button 
            text 
            type="primary" 
            :icon="Setting"
            @click="showSettings = true"
            class="settings-btn"
          >
            后端设置
          </el-button>
        </div>
      </template>

      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        label-width="80px"
      >
        <el-form-item label="用户名" prop="username">
          <el-input
            v-model="form.username"
            placeholder="请输入用户名"
            :prefix-icon="User"
          />
        </el-form-item>

        <el-form-item v-if="!isLogin" label="邮箱" prop="email">
          <el-input
            v-model="form.email"
            placeholder="请输入邮箱"
            :prefix-icon="Message"
          />
        </el-form-item>

        <el-form-item label="密码" prop="password">
          <el-input
            v-model="form.password"
            type="password"
            placeholder="请输入密码"
            :prefix-icon="Lock"
            show-password
          />
        </el-form-item>

        <el-form-item v-if="!isLogin" label="确认密码" prop="confirmPassword">
          <el-input
            v-model="form.confirmPassword"
            type="password"
            placeholder="请再次输入密码"
            :prefix-icon="Lock"
            show-password
          />
        </el-form-item>

        <!-- 显示当前后端地址 -->
        <el-alert
          :title="`当前后端地址: ${currentBackendUrl}`"
          type="info"
          :closable="false"
          show-icon
          style="margin-bottom: 16px;"
        />

        <el-form-item>
          <el-button
            type="primary"
            @click="handleSubmit"
            :loading="loading"
            style="width: 100%;"
          >
            {{ isLogin ? '登录' : '注册' }}
          </el-button>
        </el-form-item>

        <div class="login-footer">
          <el-link type="primary" @click="toggleMode">
            {{ isLogin ? '没有账号？立即注册' : '已有账号？立即登录' }}
          </el-link>
        </div>
      </el-form>
    </el-card>

    <!-- 后端设置对话框 -->
    <el-dialog
      v-model="showSettings"
      title="后端服务器设置"
      width="500px"
    >
      <el-form label-width="100px">
        <el-form-item label="后端地址">
          <el-input
            v-model="backendUrl"
            placeholder="例如: https://img.oxvxo.link"
          >
            <template #prepend>
              <el-icon><Link /></el-icon>
            </template>
          </el-input>
          <div class="hint-text">
            请输入完整的后端服务器地址，例如：
            <br />• https://img.oxvxo.link
            <br />• http://localhost:8080
            <br />• http://192.168.1.100:8080
          </div>
        </el-form-item>

        <el-form-item label="预设地址">
          <el-select 
            v-model="backendUrl" 
            placeholder="选择预设地址"
            style="width: 100%;"
          >
            <el-option label="本地开发 (localhost:8080)" value="http://localhost:8080" />
            <el-option label="本地开发 (127.0.0.1:8080)" value="http://127.0.0.1:8080" />
          </el-select>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" @click="saveBackendUrl" :loading="testing">
            保存并测试连接
          </el-button>
          <el-button @click="showSettings = false">取消</el-button>
        </el-form-item>

        <!-- 连接状态提示 -->
        <el-alert
          v-if="connectionStatus"
          :title="connectionStatus.message"
          :type="connectionStatus.type"
          :closable="false"
          show-icon
          style="margin-top: 16px;"
        />
      </el-form>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { User, Lock, Message, Setting, Link } from '@element-plus/icons-vue'
import axios from 'axios'
import * as api from '@/api'
import { setToken, setUser, getConfig, saveConfig } from '@/utils/config'

const router = useRouter()
const formRef = ref<FormInstance>()
const isLogin = ref(true)
const loading = ref(false)

// 后端设置相关
const showSettings = ref(false)
const backendUrl = ref(getConfig().backendUrl)
const currentBackendUrl = computed(() => getConfig().backendUrl)
const testing = ref(false)
const connectionStatus = ref<{ type: 'success' | 'error' | 'warning', message: string } | null>(null)

const form = reactive({
  username: '',
  email: '',
  password: '',
  confirmPassword: ''
})

const validateConfirmPassword = (_rule: any, value: any, callback: any) => {
  if (value === '') {
    callback(new Error('请再次输入密码'))
  } else if (value !== form.password) {
    callback(new Error('两次输入密码不一致'))
  } else {
    callback()
  }
}

const rules = reactive<FormRules>({
  username: [
    { required: true, message: '请输入用户名', trigger: 'blur' },
    { min: 3, max: 20, message: '长度在 3 到 20 个字符', trigger: 'blur' }
  ],
  email: [
    { required: true, message: '请输入邮箱地址', trigger: 'blur' },
    { type: 'email', message: '请输入正确的邮箱地址', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码长度不能少于 6 个字符', trigger: 'blur' }
  ],
  confirmPassword: [
    { required: true, validator: validateConfirmPassword, trigger: 'blur' }
  ]
})

// 保存并测试后端地址
const saveBackendUrl = async () => {
  if (!backendUrl.value) {
    ElMessage.error('请输入后端地址')
    return
  }

  // 移除末尾的斜杠
  const url = backendUrl.value.replace(/\/$/, '')
  
  testing.value = true
  connectionStatus.value = null

  try {
    // 测试连接
    const response = await axios.get(`${url}/health`, { timeout: 5000 })
    if (response.data.status === 'healthy') {
      // 保存配置
      saveConfig({ backendUrl: url })
      connectionStatus.value = {
        type: 'success',
        message: '连接成功！后端服务正常运行。'
      }
      ElMessage.success('后端地址已保存并测试成功')
      
      // 2秒后关闭对话框
      setTimeout(() => {
        showSettings.value = false
        connectionStatus.value = null
      }, 2000)
    } else {
      connectionStatus.value = {
        type: 'warning',
        message: '服务器响应异常，但地址已保存。'
      }
    }
  } catch (error: any) {
    connectionStatus.value = {
      type: 'error',
      message: `连接失败: ${error.message || '无法连接到后端服务器'}`
    }
    ElMessage.error('连接测试失败，请检查地址是否正确')
  } finally {
    testing.value = false
  }
}

const toggleMode = () => {
  isLogin.value = !isLogin.value
  formRef.value?.resetFields()
}

const handleSubmit = async () => {
  if (!formRef.value) return

  await formRef.value.validate(async (valid) => {
    if (!valid) return

    loading.value = true
    try {
      if (isLogin.value) {
        // 登录
        const res = await api.login({
          username: form.username,
          password: form.password
        })
        const data = (res as any).data
        setToken(data.token)
        setUser(data.user)
        ElMessage.success('登录成功')
        router.push('/')
      } else {
        // 注册
        const res = await api.register({
          username: form.username,
          email: form.email,
          password: form.password
        })
        const data = (res as any).data
        setToken(data.token)
        setUser(data.user)
        ElMessage.success('注册成功')
        router.push('/')
      }
    } catch (error: any) {
      const errorMsg = error.response?.data?.error || '操作失败'
      ElMessage.error(errorMsg)
      
      // 如果是连接错误，提示用户检查后端设置
      if (error.code === 'ERR_NETWORK' || error.message.includes('Network Error')) {
        ElMessage.warning('无法连接到后端服务器，请检查后端设置')
      }
    } finally {
      loading.value = false
    }
  })
}
</script>


<style scoped>
.login-page {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.login-card {
  width: 450px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
}

.login-header {
  text-align: center;
  position: relative;
}

.login-header h2 {
  margin: 0;
  font-size: 24px;
  color: #303133;
}

.settings-btn {
  position: absolute;
  right: 0;
  top: 50%;
  transform: translateY(-50%);
}

.login-footer {
  text-align: center;
  margin-top: 16px;
}

.hint-text {
  font-size: 12px;
  color: #909399;
  margin-top: 8px;
  line-height: 1.6;
}
</style>
