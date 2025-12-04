import request from '@/utils/request'

export interface OperationLog {
  id: number
  created_at: string
  user_id: number
  username: string
  action: string
  module: string
  resource_id: number
  description: string
  method: string
  path: string
  ip: string
  user_agent: string
  status: number
  error: string
  latency: number
  extra: string
}

export interface SystemLog {
  id: number
  created_at: string
  level: string
  module: string
  message: string
  error: string
  extra: string
}

export interface LogListResponse {
  data: OperationLog[] | SystemLog[]
  pagination: {
    total: number
    page: number
    page_size: number
  }
}

// 获取操作日志
export function getOperationLogs(params: {
  page?: number
  pageSize?: number
  module?: string
  action?: string
  user_id?: string
}) {
  return request.get<LogListResponse>('/logs/operations', { params })
}

// 获取系统日志
export function getSystemLogs(params: {
  page?: number
  pageSize?: number
  level?: string
  module?: string
}) {
  return request.get<LogListResponse>('/logs/system', { params })
}

// 清理旧日志
export function clearOldLogs(days: number = 90) {
  return request.post(`/logs/clear?days=${days}`)
}
