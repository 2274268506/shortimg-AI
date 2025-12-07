<template>
  <el-dialog
    v-model="visible"
    :title="isEdit ? '编辑相册' : '新建相册'"
    width="600px"
    @close="handleClose"
  >
    <el-form :model="form" label-width="100px">
      <el-form-item label="相册名称" required>
        <el-input v-model="form.name" placeholder="请输入相册名称" />
      </el-form-item>
      <el-form-item label="相册描述">
        <el-input
          v-model="form.description"
          type="textarea"
          :rows="3"
          placeholder="请输入相册描述"
        />
      </el-form-item>

      <el-divider content-position="left">
        <el-icon><Lock /></el-icon>
        <span style="margin-left: 8px;">隐私设置</span>
      </el-divider>

      <el-form-item label="访问权限">
        <el-radio-group v-model="privacyMode" @change="handlePrivacyModeChange">
          <el-radio value="public" style="display: block; margin-bottom: 12px;">
            <div style="display: inline-flex; align-items: center;">
              <el-icon style="margin-right: 4px;"><View /></el-icon>
              <strong>公开</strong>
            </div>
            <div style="color: var(--el-text-color-secondary); font-size: 13px; margin-left: 20px;">
              所有人都可以查看此相册
            </div>
          </el-radio>
          <el-radio value="private" style="display: block; margin-bottom: 12px;">
            <div style="display: inline-flex; align-items: center;">
              <el-icon style="margin-right: 4px;"><Hide /></el-icon>
              <strong>私有</strong>
            </div>
            <div style="color: var(--el-text-color-secondary); font-size: 13px; margin-left: 20px;">
              仅自己可见
            </div>
          </el-radio>
          <el-radio value="shared" style="display: block;">
            <div style="display: inline-flex; align-items: center;">
              <el-icon style="margin-right: 4px;"><Share /></el-icon>
              <strong>共享</strong>
            </div>
            <div style="color: var(--el-text-color-secondary); font-size: 13px; margin-left: 20px;">
              与特定用户共享
            </div>
          </el-radio>
        </el-radio-group>
      </el-form-item>

      <el-form-item label="允许分享链接" v-if="privacyMode !== 'private'">
        <el-switch v-model="form.allowShare" />
        <span style="margin-left: 12px; color: var(--el-text-color-secondary); font-size: 13px;">
          允许通过链接分享此相册
        </span>
      </el-form-item>

      <el-divider content-position="left">
        <el-icon><Link /></el-icon>
        <span style="margin-left: 8px;">短链设置</span>
      </el-divider>

      <el-form-item label="自动生成短链">
        <el-switch v-model="form.enableShortLink" />
        <div style="margin-left: 12px; color: var(--el-text-color-secondary); font-size: 13px;">
          <div>开启后，上传到此相册的图片将自动生成短链</div>
          <div style="margin-top: 4px; color: var(--el-color-primary);">
            <el-icon><InfoFilled /></el-icon>
            短链示例: http://localhost/abc123
          </div>
        </div>
      </el-form-item>

      <el-form-item label="共享用户" v-if="privacyMode === 'shared'">
        <el-select
          v-model="form.sharedUserIds"
          multiple
          filterable
          remote
          reserve-keyword
          placeholder="输入用户名搜索"
          :remote-method="searchUsers"
          :loading="loadingUsers"
          style="width: 100%;"
        >
          <el-option
            v-for="user in availableUsers"
            :key="user.id"
            :label="`${user.username} (${user.email})`"
            :value="user.id"
          >
            <div style="display: flex; align-items: center; justify-content: space-between;">
              <div>
                <el-icon style="margin-right: 4px;"><User /></el-icon>
                <span>{{ user.username }}</span>
              </div>
              <span style="color: var(--el-text-color-secondary); font-size: 12px;">
                {{ user.email }}
              </span>
            </div>
          </el-option>
        </el-select>
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="handleClose">取消</el-button>
      <el-button type="primary" @click="handleSubmit">
        {{ isEdit ? '保存' : '创建' }}
      </el-button>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Lock, View, Hide, Share, User, Link, InfoFilled } from '@element-plus/icons-vue'
import { getUsers } from '@/api/users'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  },
  isEdit: {
    type: Boolean,
    default: false
  },
  album: {
    type: Object,
    default: null
  }
})

const emit = defineEmits(['update:modelValue', 'submit'])

const visible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

const form = ref({
  name: '',
  description: '',
  isPrivate: false,
  isPublic: true,
  allowShare: true,
  enableShortLink: false,
  sharedUserIds: []
})

const privacyMode = ref('public')
const availableUsers = ref([])
const loadingUsers = ref(false)

// 根据隐私模式更新表单字段
const handlePrivacyModeChange = (mode) => {
  switch (mode) {
    case 'public':
      form.value.isPrivate = false
      form.value.isPublic = true
      form.value.allowShare = true
      form.value.sharedUserIds = []
      break
    case 'private':
      form.value.isPrivate = true
      form.value.isPublic = false
      form.value.allowShare = false
      form.value.sharedUserIds = []
      break
    case 'shared':
      form.value.isPrivate = false
      form.value.isPublic = false
      form.value.allowShare = true
      break
  }
}

// 搜索用户
const searchUsers = async (query) => {
  if (!query) {
    availableUsers.value = []
    return
  }

  loadingUsers.value = true
  try {
    const response = await getUsers({ keyword: query })
    availableUsers.value = response.data || []
  } catch (error) {
    console.error('搜索用户失败:', error)
  } finally {
    loadingUsers.value = false
  }
}

watch(() => props.album, (newAlbum) => {
  if (newAlbum && props.isEdit) {
    // 编辑模式：加载现有相册数据
    form.value = {
      id: newAlbum.id,
      name: newAlbum.name,
      description: newAlbum.description || '',
      isPrivate: newAlbum.isPrivate || false,
      isPublic: newAlbum.isPublic !== undefined ? newAlbum.isPublic : true,
      allowShare: newAlbum.allowShare !== undefined ? newAlbum.allowShare : true,
      enableShortLink: newAlbum.enableShortLink || false,
      sharedUserIds: newAlbum.sharedUsers ? newAlbum.sharedUsers.split(',').map(id => parseInt(id)).filter(id => id) : []
    }

    // 设置隐私模式
    if (newAlbum.isPrivate) {
      privacyMode.value = 'private'
    } else if (!newAlbum.isPublic && form.value.sharedUserIds.length > 0) {
      privacyMode.value = 'shared'
    } else {
      privacyMode.value = 'public'
    }
  } else {
    // 新建模式：使用默认值
    form.value = {
      name: '',
      description: '',
      isPrivate: false,
      isPublic: true,
      allowShare: true,
      enableShortLink: false,
      sharedUserIds: []
    }
    privacyMode.value = 'public'
  }
}, { immediate: true })

const handleSubmit = () => {
  if (!form.value.name) {
    ElMessage.warning('请输入相册名称')
    return
  }

  // 准备提交数据
  const submitData = {
    name: form.value.name,
    description: form.value.description,
    isPrivate: form.value.isPrivate,
    isPublic: form.value.isPublic,
    allowShare: form.value.allowShare,
    enableShortLink: form.value.enableShortLink,
    sharedUsers: form.value.sharedUserIds.join(',')
  }

  if (props.isEdit) {
    submitData.id = form.value.id
  }

  emit('submit', submitData)
}

const handleClose = () => {
  form.value = {
    name: '',
    description: '',
    isPrivate: false,
    isPublic: true,
    allowShare: true,
    enableShortLink: false,
    sharedUserIds: []
  }
  privacyMode.value = 'public'
  availableUsers.value = []
  visible.value = false
}
</script>

<style scoped>
:deep(.el-radio) {
  height: auto;
  line-height: 1.5;
  align-items: flex-start;
}

:deep(.el-radio__label) {
  white-space: normal;
  line-height: 1.5;
}
</style>
