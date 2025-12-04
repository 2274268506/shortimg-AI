// 相册类型
export interface Album {
  id: number
  name: string
  description: string
  coverImage: string
  imageCount: number
  createdAt: string
  updatedAt: string
}

// 图片类型
export interface Image {
  id: number
  uuid: string
  albumId: number
  fileName: string
  originalName: string
  filePath: string
  fileSize: number
  mimeType: string
  width: number
  height: number
  thumbnail: string
  url: string
  viewCount: number
  downloadCount: number
  lastViewAt: string | null
  tags: string
  createdAt: string
  updatedAt: string
}

// 统计数据类型
export interface StatisticsOverview {
  totalImages: number
  totalSize: number
  totalViews: number
  totalDownloads: number
}

export interface StatisticsToday {
  images: number
  views: number
  downloads: number
  traffic: number
}

export interface TopImage {
  id: number
  uuid: string
  fileName: string
  originalName: string
  url: string
  viewCount: number
  downloadCount: number
}

export interface DayStats {
  date: string
  views: number
  downloads: number
  traffic: number
}

export interface AlbumStats {
  id: number
  name: string
  imageCount: number
  totalSize: number
  totalViews: number
}

export interface Statistics {
  overview: StatisticsOverview
  today: StatisticsToday
  topImages: TopImage[]
  recent7Days: DayStats[]
  recent30Days: DayStats[]
  albumStats: AlbumStats[]
}

// 用户类型
export interface User {
  id: number
  username: string
  email: string
  role: string
  status?: string
  avatar?: string
  bio?: string
  lastLogin?: string
  loginIP?: string
  createdAt: string
  updatedAt: string
}

// 用户统计类型
export interface UserStats {
  userId: number
  totalImages: number
  totalAlbums: number
  totalStorage: number
  totalViews: number
  totalDownloads: number
}

export interface LoginRequest {
  username: string
  password: string
}

export interface RegisterRequest {
  username: string
  email: string
  password: string
}

export interface AuthResponse {
  token: string
  user: User
}

// 系统配置类型
export interface SystemConfig {
  backendUrl: string
}

// API 响应类型
export interface ApiResponse<T = any> {
  data?: T
  error?: string
  message?: string
}

export interface PaginatedResponse<T> {
  data: T[]
  total: number
  page: number
  pageSize: number
}

// 个人资料更新请求
export interface ProfileUpdateRequest {
  avatar?: string
  bio?: string
}

// 修改密码请求
export interface ChangePasswordRequest {
  oldPassword: string
  newPassword: string
}

