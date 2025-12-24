import request from '@/utils/request'
import type { Album, Image, Statistics, ApiResponse, PaginatedResponse } from '@/types'

// ========== 相册相关 API ==========

// 获取所有相册
export const getAlbums = () => {
  return request.get<ApiResponse<Album[]>>('/albums')
}

// 获取单个相册
export const getAlbum = (id: number) => {
  return request.get<ApiResponse<Album>>(`/albums/${id}`)
}

// 创建相册
export const createAlbum = (data: Partial<Album>) => {
  return request.post<ApiResponse<Album>>('/albums', data)
}

// 更新相册
export const updateAlbum = (id: number, data: Partial<Album>) => {
  return request.put<ApiResponse<Album>>(`/albums/${id}`, data)
}

// 删除相册
export const deleteAlbum = (id: number) => {
  return request.delete<ApiResponse>(`/albums/${id}`)
}

// ========== 图片相关 API ==========

// 获取图片列表
export const getImages = (
  albumId?: number,
  keyword = '',
  page = 1,
  pageSize = 24,
  sortBy = 'time',
  order = 'desc'
) => {
  const params: Record<string, any> = {}
  if (albumId) params.albumId = albumId
  if (keyword) params.keyword = keyword
  params.page = page
  params.pageSize = pageSize
  params.sortBy = sortBy
  params.order = order
  return request.get<PaginatedResponse<Image>>('/images', { params })
}

// 上传图片
export const uploadImage = (formData: FormData) => {
  return request.post<ApiResponse<Image>>('/images/upload', formData, {
    headers: {
      'Content-Type': 'multipart/form-data'
    }
  })
}

// 批量上传图片
export const batchUpload = (formData: FormData) => {
  return request.post<ApiResponse<{ uploaded: Image[], errors: string[] }>>('/images/batch-upload', formData, {
    headers: {
      'Content-Type': 'multipart/form-data'
    }
  })
}

// 删除图片
export const deleteImage = (id: number) => {
  return request.delete<ApiResponse>(`/images/${id}`)
}

// 移动图片
export const moveImage = (id: number, albumId: number) => {
  return request.put<ApiResponse>(`/images/${id}/move`, { albumId })
}

// 获取图片URL
export const getImageUrl = (id: number): string => {
  return `/api/images/${id}/file`
}

// ========== 统计相关 API ==========

// 获取统计数据
export const getStatistics = () => {
  return request.get<ApiResponse<Statistics>>('/statistics')
}

// 记录图片访问
export const recordView = (id: number) => {
  return request.post<ApiResponse>(`/statistics/view/${id}`)
}

// 记录图片下载
export const recordDownload = (id: number) => {
  return request.post<ApiResponse>(`/statistics/download/${id}`)
}

// 获取图片统计信息
export const getImageStats = (id: number) => {
  return request.get<ApiResponse<Image>>(`/statistics/image/${id}`)
}

// ========== 标签相关 API ==========

// 获取所有标签
export const getAllTags = () => {
  return request.get<ApiResponse<string[]>>('/tags')
}

// 按标签搜索图片
export const searchImagesByTag = (tag: string, albumId?: number) => {
  return request.get<PaginatedResponse<Image>>('/tags/search', { params: { tag, albumId } })
}

// 更新图片标签
export const updateImageTags = (id: number, tags: string) => {
  return request.put<ApiResponse<Image>>(`/images/${id}/tags`, { tags })
}

// ========== 图片编辑相关 API ==========

// 重命名图片
export const renameImage = (id: number, fileName: string) => {
  return request.put<ApiResponse<Image>>(`/images/${id}/rename`, { fileName })
}

// 更新图片文件（裁剪、滤镜等）
export const updateImageFile = (id: number, file: Blob) => {
  const formData = new FormData()
  formData.append('file', file)
  return request.put<ApiResponse<Image>>(`/images/${id}/file`, formData, {
    headers: {
      'Content-Type': 'multipart/form-data'
    }
  })
}

// ========== 防盗链相关 API ==========

// 获取签名URL
export const getSignedURL = (id: number, ttl = 3600) => {
  return request.get<ApiResponse<{ url: string, expires: number, expiresAt: string }>>(`/images/${id}/signed-url`, {
    params: { ttl }
  })
}

// ========== 图片格式相关 API ==========

// 获取支持的图片格式列表
export const getSupportedFormats = () => {
  return request.get<ApiResponse<{
    supported: string[],
    animated: string[]
  }>>('/images/formats')
}

// 单张图片格式转换
export const convertImageFormat = (id: number, targetFormat: string, quality?: number) => {
  return request.put<ApiResponse<Image>>(`/images/${id}/convert`, {
    targetFormat,
    quality
  })
}

// 批量图片格式转换
export const batchConvertFormat = (ids: number[], targetFormat: string, quality?: number) => {
  return request.post<ApiResponse<{
    converted: Image[],
    errors: string[]
  }>>('/images/batch-convert', {
    imageIds: ids,
    targetFormat,
    quality
  })
}

// ========== 用户认证相关 API ==========

import type { LoginRequest, RegisterRequest, AuthResponse, User, UserStats, ProfileUpdateRequest, ChangePasswordRequest } from '@/types'

// 用户登录
export const login = (data: LoginRequest) => {
  return request.post<ApiResponse<AuthResponse>>('/auth/login', data)
}

// 用户注册
export const register = (data: RegisterRequest) => {
  return request.post<ApiResponse<AuthResponse>>('/auth/register', data)
}

// 获取当前用户信息
export const getCurrentUser = () => {
  return request.get<ApiResponse<User>>('/auth/me')
}

// 登出
export const logout = () => {
  return request.post<ApiResponse<void>>('/auth/logout')
}

// ========== 用户管理相关 API ==========

// 获取用户列表（管理员）- 支持分页和搜索
export const getUsers = (params?: {
  page?: number
  pageSize?: number
  keyword?: string
  status?: string
  role?: string
}) => {
  return request.get<ApiResponse<{
    users: User[]
    total: number
    page: number
    pageSize: number
  }>>('/users', { params })
}

// 获取用户详情（管理员）
export const getUser = (id: number) => {
  return request.get<ApiResponse<User>>(`/users/${id}`)
}

// 获取用户统计信息（管理员）
export const getUserStats = (id: number) => {
  return request.get<ApiResponse<UserStats>>(`/users/${id}/stats`)
}

// 获取用户最近上传的图片（管理员）
export const getUserRecentImages = (id: number, limit: number = 6) => {
  return request.get<ApiResponse<Image[]>>(`/users/${id}/images`, {
    params: { limit }
  })
}

// 更新用户状态（管理员）
export const updateUserStatus = (id: number, status: string) => {
  return request.put<ApiResponse<User>>(`/users/${id}/status`, { status })
}

// 重置用户密码（管理员）
export const resetUserPassword = (id: number, newPassword: string) => {
  return request.post<ApiResponse<void>>(`/users/${id}/reset-password`, { newPassword })
}

// 删除用户（管理员）
export const deleteUser = (id: number) => {
  return request.delete<ApiResponse<void>>(`/users/${id}`)
}

// 更新用户角色（管理员）
export const updateUserRole = (id: number, role: string) => {
  return request.put<ApiResponse<User>>(`/users/${id}/role`, { role })
}

// 创建用户（管理员）
export const createUser = (data: {
  username: string
  email: string
  password: string
  role: string
}) => {
  return request.post<ApiResponse<User>>('/users', data)
}

// 更新用户信息（管理员）
export const updateUser = (id: number, data: {
  username: string
  email: string
  bio?: string
}) => {
  return request.put<ApiResponse<User>>(`/users/${id}`, data)
}

// ========== 个人资料相关 API ==========

// 更新个人资料
export const updateProfile = (data: ProfileUpdateRequest) => {
  return request.put<ApiResponse<User>>('/profile', data)
}

// 修改密码
export const changePassword = (data: ChangePasswordRequest) => {
  return request.post<ApiResponse<void>>('/profile/change-password', data)
}

// ========== 短链管理相关 API ==========

// 生成短链
export const generateShortLink = (imageId: number) => {
  return request.post<ApiResponse<{
    message: string
    short_link_code: string
    short_link_url: string
  }>>(`/images/${imageId}/shortlink`)
}

// 删除短链（解绑）
export const unbindShortLink = (imageId: number, permanent: boolean = false) => {
  return request.delete<ApiResponse<{
    message: string
  }>>(`/images/${imageId}/shortlink${permanent ? '?permanent=true' : ''}`)
}

// 转移短链到另一张图片
export const transferShortLink = (oldImageId: number, newImageIdOrUuid: number | string) => {
  const body = typeof newImageIdOrUuid === 'string'
    ? { target_uuid: newImageIdOrUuid }
    : { new_image_id: newImageIdOrUuid }

  return request.put<ApiResponse<{
    message: string
    short_link_code: string
    old_image_id: number
    new_image_id: number
  }>>(`/images/${oldImageId}/shortlink`, body)
}
