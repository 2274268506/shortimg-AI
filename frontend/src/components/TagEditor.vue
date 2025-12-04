<template>
  <el-dialog
    v-model="visible"
    title="编辑标签"
    width="500px"
  >
    <div class="tag-editor">
      <div class="current-tags">
        <el-tag
          v-for="tag in currentTags"
          :key="tag"
          closable
          @close="removeTag(tag)"
          style="margin-right: 8px; margin-bottom: 8px;"
        >
          {{ tag }}
        </el-tag>
      </div>

      <el-input
        v-model="newTag"
        placeholder="输入新标签，按回车添加"
        @keyup.enter="addTag"
        style="margin-top: 12px;"
      >
        <template #append>
          <el-button :icon="Plus" @click="addTag">添加</el-button>
        </template>
      </el-input>

      <el-divider>常用标签</el-divider>

      <div class="common-tags">
        <el-tag
          v-for="tag in commonTags"
          :key="tag.name"
          :type="isTagSelected(tag.name) ? 'success' : 'info'"
          @click="toggleTag(tag.name)"
          style="margin-right: 8px; margin-bottom: 8px; cursor: pointer;"
        >
          {{ tag.name }} ({{ tag.count }})
        </el-tag>
        <el-empty v-if="commonTags.length === 0" description="暂无标签" :image-size="60" />
      </div>
    </div>

    <template #footer>
      <el-button @click="visible = false">取消</el-button>
      <el-button type="primary" @click="handleSave" :loading="saving">
        保存
      </el-button>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { Plus } from '@element-plus/icons-vue'
import { updateImageTags, getAllTags } from '@/api'
import { ElMessage } from 'element-plus'

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

const emit = defineEmits(['update:modelValue', 'updated'])

const visible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

const currentTags = ref([])
const newTag = ref('')
const commonTags = ref([])
const saving = ref(false)

// 监听对话框打开，加载数据
watch(() => props.modelValue, async (newVal) => {
  if (newVal) {
    // 解析当前图片的标签
    if (props.image?.tags) {
      currentTags.value = props.image.tags.split(',').map(t => t.trim()).filter(t => t)
    } else {
      currentTags.value = []
    }

    // 加载常用标签
    try {
      const res = await getAllTags()
      commonTags.value = res.data || []
    } catch (error) {
      console.error('加载标签失败:', error)
    }
  }
})

const isTagSelected = (tagName) => {
  return currentTags.value.includes(tagName)
}

const addTag = () => {
  const tag = newTag.value.trim()
  if (tag && !currentTags.value.includes(tag)) {
    currentTags.value.push(tag)
    newTag.value = ''
  } else if (currentTags.value.includes(tag)) {
    ElMessage.warning('标签已存在')
  }
}

const removeTag = (tag) => {
  currentTags.value = currentTags.value.filter(t => t !== tag)
}

const toggleTag = (tagName) => {
  if (isTagSelected(tagName)) {
    removeTag(tagName)
  } else {
    currentTags.value.push(tagName)
  }
}

const handleSave = async () => {
  saving.value = true
  try {
    const tagsStr = currentTags.value.join(', ')
    await updateImageTags(props.image.id, tagsStr)
    ElMessage.success('标签保存成功')
    emit('updated', tagsStr)
    visible.value = false
  } catch (error) {
    ElMessage.error('保存失败')
    console.error(error)
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.tag-editor {
  padding: 12px 0;
}

.current-tags {
  min-height: 40px;
  padding: 12px;
  background-color: #f5f7fa;
  border-radius: 4px;
}

.common-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
</style>
