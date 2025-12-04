<template>
  <el-dialog
    v-model="visible"
    title="图片权限设置"
    width="500px"
    @close="handleClose"
  >
    <el-form :model="form" label-width="100px">
      <el-form-item label="访问权限">
        <el-radio-group v-model="form.isPrivate">
          <el-radio :value="false" style="display: block; margin-bottom: 12px;">
            <div style="display: inline-flex; align-items: center;">
              <el-icon style="margin-right: 4px;"><View /></el-icon>
              <strong>公开</strong>
            </div>
            <div style="color: var(--el-text-color-secondary); font-size: 13px; margin-left: 20px;">
              所有人都可以查看此图片
            </div>
          </el-radio>
          <el-radio :value="true" style="display: block;">
            <div style="display: inline-flex; align-items: center;">
              <el-icon style="margin-right: 4px;"><Hide /></el-icon>
              <strong>私有</strong>
            </div>
            <div style="color: var(--el-text-color-secondary); font-size: 13px; margin-left: 20px;">
              仅自己可见
            </div>
          </el-radio>
        </el-radio-group>
      </el-form-item>
      
      <el-form-item label="允许下载" v-if="!form.isPrivate">
        <el-switch v-model="form.allowDownload" />
        <span style="margin-left: 12px; color: var(--el-text-color-secondary); font-size: 13px;">
          允许其他用户下载此图片
        </span>
      </el-form-item>
      
      <el-alert
        v-if="form.isPrivate"
        title="私有图片只有所有者和管理员可以查看和下载"
        type="warning"
        :closable="false"
        show-icon
        style="margin-bottom: 16px;"
      />
    </el-form>
    <template #footer>
      <el-button @click="handleClose">取消</el-button>
      <el-button type="primary" @click="handleSubmit">保存</el-button>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { View, Hide } from '@element-plus/icons-vue'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  },
  image: {
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
  isPrivate: false,
  allowDownload: true
})

watch(() => props.image, (newImage) => {
  if (newImage) {
    form.value = {
      isPrivate: newImage.isPrivate || false,
      allowDownload: newImage.allowDownload !== undefined ? newImage.allowDownload : true
    }
  } else {
    form.value = {
      isPrivate: false,
      allowDownload: true
    }
  }
}, { immediate: true })

const handleSubmit = () => {
  if (!props.image) {
    ElMessage.warning('没有选择图片')
    return
  }
  
  const submitData = {
    id: props.image.id,
    isPrivate: form.value.isPrivate,
    isPublic: !form.value.isPrivate,
    allowDownload: form.value.isPrivate ? false : form.value.allowDownload
  }
  
  emit('submit', submitData)
}

const handleClose = () => {
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
