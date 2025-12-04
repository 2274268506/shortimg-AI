import { ElMessage } from 'element-plus'
import { recordDownload } from '@/api'

export function useImageOperations() {
  // 复制图片链接 - 多种格式
  const copyImageLink = async (image, format = 'url') => {
    const fullUrl = window.location.origin + image.url
    let textToCopy = ''
    
    switch (format) {
      case 'url':
        textToCopy = fullUrl
        break
      case 'markdown':
        textToCopy = `![${image.fileName}](${fullUrl})`
        break
      case 'html':
        textToCopy = `<img src="${fullUrl}" alt="${image.fileName}" />`
        break
      case 'bbcode':
        textToCopy = `[img]${fullUrl}[/img]`
        break
      default:
        textToCopy = fullUrl
    }
    
    try {
      // 尝试使用现代 Clipboard API
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(textToCopy)
        ElMessage.success('链接已复制到剪贴板')
      } else {
        // 降级方案：使用传统方法
        const textArea = document.createElement('textarea')
        textArea.value = textToCopy
        textArea.style.position = 'fixed'
        textArea.style.left = '-9999px'
        document.body.appendChild(textArea)
        textArea.select()
        
        try {
          document.execCommand('copy')
          ElMessage.success('链接已复制到剪贴板')
        } catch (err) {
          ElMessage.error('复制失败，请手动复制')
          console.error('复制失败:', err)
        }
        
        document.body.removeChild(textArea)
      }
    } catch (err) {
      ElMessage.error('复制失败')
      console.error('复制失败:', err)
    }
  }

  // 下载图片
  const downloadImage = async (image) => {
    try {
      // 记录下载次数
      if (image.id) {
        await recordDownload(image.id)
      }
    } catch (error) {
      console.error('记录下载失败:', error)
    }
    
    const link = document.createElement('a')
    link.href = image.url
    link.download = image.fileName
    link.click()
  }

  // 格式化文件大小
  const formatFileSize = (bytes) => {
    if (!bytes) return '0 B'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }

  // 格式化日期
  const formatDate = (dateStr) => {
    if (!dateStr) return ''
    const date = new Date(dateStr)
    return date.toLocaleString('zh-CN')
  }

  return {
    copyImageLink,
    downloadImage,
    formatFileSize,
    formatDate
  }
}
