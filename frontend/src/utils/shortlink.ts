/**
 * 短链工具函数
 */

import { ElMessage } from 'element-plus'

/**
 * 复制文本到剪贴板
 */
export const copyToClipboard = async (text: string): Promise<boolean> => {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      // 现代浏览器的 Clipboard API
      await navigator.clipboard.writeText(text)
      return true
    } else {
      // 兼容旧浏览器
      const textArea = document.createElement('textarea')
      textArea.value = text
      textArea.style.position = 'fixed'
      textArea.style.left = '-999999px'
      textArea.style.top = '-999999px'
      document.body.appendChild(textArea)
      textArea.focus()
      textArea.select()
      const successful = document.execCommand('copy')
      textArea.remove()
      return successful
    }
  } catch (err) {
    console.error('复制失败:', err)
    return false
  }
}

/**
 * 复制短链并显示提示
 */
export const copyShortLink = async (shortLinkUrl: string): Promise<void> => {
  const success = await copyToClipboard(shortLinkUrl)
  if (success) {
    ElMessage.success('短链已复制到剪贴板')
  } else {
    ElMessage.error('复制失败，请手动复制')
  }
}

/**
 * 生成短链的 Markdown 格式
 */
export const getShortLinkMarkdown = (shortLinkUrl: string, fileName?: string): string => {
  const title = fileName || '图片'
  return `![${title}](${shortLinkUrl})`
}

/**
 * 生成短链的 HTML 格式
 */
export const getShortLinkHTML = (shortLinkUrl: string, fileName?: string): string => {
  const alt = fileName || '图片'
  return `<img src="${shortLinkUrl}" alt="${alt}" />`
}

/**
 * 生成短链的 BBCode 格式
 */
export const getShortLinkBBCode = (shortLinkUrl: string): string => {
  return `[img]${shortLinkUrl}[/img]`
}

/**
 * 根据格式复制短链
 */
export const copyShortLinkWithFormat = async (
  shortLinkUrl: string,
  format: 'url' | 'markdown' | 'html' | 'bbcode',
  fileName?: string
): Promise<void> => {
  let text = shortLinkUrl
  let formatName = '链接'

  switch (format) {
    case 'url':
      text = shortLinkUrl
      formatName = '短链'
      break
    case 'markdown':
      text = getShortLinkMarkdown(shortLinkUrl, fileName)
      formatName = 'Markdown 格式'
      break
    case 'html':
      text = getShortLinkHTML(shortLinkUrl, fileName)
      formatName = 'HTML 格式'
      break
    case 'bbcode':
      text = getShortLinkBBCode(shortLinkUrl)
      formatName = 'BBCode 格式'
      break
  }

  const success = await copyToClipboard(text)
  if (success) {
    ElMessage.success(`${formatName}已复制到剪贴板`)
  } else {
    ElMessage.error('复制失败，请手动复制')
  }
}

/**
 * 生成短链的二维码数据 URL
 */
export const generateQRCode = async (text: string): Promise<string> => {
  try {
    // 使用动态导入 qrcode 库（需要先安装）
    const QRCode = await import('qrcode')
    const dataUrl = await QRCode.toDataURL(text, {
      width: 200,
      margin: 1,
      color: {
        dark: '#000000',
        light: '#FFFFFF'
      }
    })
    return dataUrl
  } catch (err) {
    console.error('生成二维码失败:', err)
    throw err
  }
}

/**
 * 检查是否有短链
 */
export const hasShortLink = (image: { shortLinkCode?: string; shortLinkUrl?: string }): boolean => {
  return !!(image.shortLinkCode && image.shortLinkUrl)
}

/**
 * 格式化短链代码（添加域名前缀）
 */
export const formatShortLinkUrl = (code: string, baseUrl: string = window.location.origin): string => {
  return `${baseUrl}/${code}`
}
