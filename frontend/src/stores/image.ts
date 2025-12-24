import { defineStore } from 'pinia'
import { ref } from 'vue'
import * as api from '@/api'
import type { Album, Image } from '@/types'

// 从 LocalStorage 加载显示设置
const loadDisplaySettings = () => {
  const saved = localStorage.getItem('display-settings')
  if (saved) {
    try {
      return JSON.parse(saved)
    } catch (e) {
      console.error('Failed to parse display settings:', e)
    }
  }
  return {
    theme: 'light',
    defaultView: 'grid',
    pageSize: 24,
    thumbnailQuality: 80,
    lazyLoad: true,
    showFileSize: true,
    showUploadDate: true
  }
}

export const useImageStore = defineStore('image', () => {
  const displaySettings = loadDisplaySettings()

  const albums = ref<Album[]>([])
  const currentAlbum = ref<Album | null>(null)
  const images = ref<Image[]>([])
  const loading = ref<boolean>(false)
  const page = ref<number>(1)
  const pageSize = ref<number>(displaySettings.pageSize) // 使用用户设置的每页数量
  const total = ref<number>(0)
  const sortBy = ref<string>('time')
  const order = ref<'asc' | 'desc'>('desc')

  // 加载所有相册
  const loadAlbums = async (): Promise<void> => {
    loading.value = true
    try {
      console.log('开始加载相册...')
      const res = await api.getAlbums()
      console.log('相册API响应:', res)
      albums.value = (res as any).data || []
      console.log('解析后的相册列表:', albums.value)
      if (albums.value.length > 0 && !currentAlbum.value) {
        currentAlbum.value = albums.value[0]
        console.log('设置当前相册:', currentAlbum.value)
      }
    } catch (error) {
      console.error('加载相册失败:', error)
    } finally {
      loading.value = false
    }
  }

  // 加载图片列表
  const loadImages = async (albumId?: number, keyword = '', p = 1): Promise<void> => {
    loading.value = true
    try {
      page.value = p
      console.log('开始加载图片，相册ID:', albumId, '关键词:', keyword, '页码:', p)
      const res = await api.getImages(albumId, keyword, page.value, pageSize.value, sortBy.value, order.value)
      console.log('图片API响应:', res)
      console.log('res.data:', (res as any).data)
      console.log('res.total:', (res as any).total)
      images.value = (res as any).data || []
      total.value = (res as any).total || 0
      console.log('解析后的图片列表:', images.value)
      console.log('图片总数:', total.value)
    } catch (error) {
      console.error('加载图片失败:', error)
    } finally {
      loading.value = false
    }
  }

  const loadMoreImages = async (albumId: number, keyword = ''): Promise<void> => {
    if (loading.value) return
    if (images.value.length >= total.value) return
    loading.value = true
    try {
      page.value = page.value + 1
      const res = await api.getImages(albumId, keyword, page.value, pageSize.value, sortBy.value, order.value)
      images.value = images.value.concat((res as any).data || [])
      total.value = (res as any).total || total.value
    } catch (error) {
      console.error('加载更多图片失败:', error)
      page.value = page.value - 1
    } finally {
      loading.value = false
    }
  }

  // 创建相册
  const createAlbum = async (data: Partial<Album>) => {
    try {
      const res = await api.createAlbum(data)
      await loadAlbums()
      return (res as any).data
    } catch (error) {
      console.error('创建相册失败:', error)
      throw error
    }
  }

  // 更新相册
  const updateAlbum = async (id: number, data: Partial<Album>) => {
    try {
      const res = await api.updateAlbum(id, data)
      await loadAlbums()
      return (res as any).data
    } catch (error) {
      console.error('更新相册失败:', error)
      throw error
    }
  }

  // 删除相册
  const removeAlbum = async (id: number) => {
    try {
      await api.deleteAlbum(id)
      await loadAlbums()
    } catch (error) {
      console.error('删除相册失败:', error)
      throw error
    }
  }

  // 上传图片
  const uploadImage = async (file: File, albumId: number) => {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('albumId', albumId.toString())

    try {
      const res = await api.uploadImage(formData)
      await loadImages(albumId)
      return (res as any).data
    } catch (error) {
      console.error('上传图片失败:', error)
      throw error
    }
  }

  // 批量上传图片
  const batchUploadImages = async (files: File[], albumId: number, enableShortLink?: boolean) => {
    const formData = new FormData()
    files.forEach((file: File) => {
      formData.append('files', file)
    })
    formData.append('albumId', albumId.toString())

    // 添加短链配置参数
    if (enableShortLink !== undefined) {
      formData.append('enableShortLink', enableShortLink.toString())
    }

    try {
      const res = await api.batchUpload(formData)
      await loadImages(albumId)
      return res
    } catch (error) {
      console.error('批量上传失败:', error)
      throw error
    }
  }

  // 删除图片
  const removeImage = async (id: number, albumId: number) => {
    try {
      await api.deleteImage(id)
      await loadImages(albumId)
    } catch (error) {
      console.error('删除图片失败:', error)
      throw error
    }
  }

  return {
    albums,
    currentAlbum,
    images,
    loading,
    page,
    pageSize,
    total,
    sortBy,
    order,
    loadAlbums,
    loadImages,
    loadMoreImages,
    createAlbum,
    updateAlbum,
    removeAlbum,
    uploadImage,
    batchUploadImages,
    removeImage
  }
})
