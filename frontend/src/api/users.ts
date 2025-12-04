import request from '@/utils/request'

export interface User {
  id: number
  username: string
  email: string
  role: string
  createdAt: string
  updatedAt: string
}

export interface UserListResponse {
  data: User[]
  total?: number
}

// 获取用户列表
export function getUsers(params?: {
  keyword?: string
  page?: number
  pageSize?: number
}) {
  return request.get<UserListResponse>('/users', { params })
}

// 获取当前用户信息
export function getCurrentUser() {
  return request.get<{ data: User }>('/auth/me')
}

// 删除用户
export function deleteUser(id: number) {
  return request.delete(`/users/${id}`)
}

// 更新用户角色
export function updateUserRole(id: number, role: string) {
  return request.put(`/users/${id}/role`, { role })
}
