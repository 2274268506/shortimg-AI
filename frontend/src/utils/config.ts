import type { SystemConfig } from '@/types'

const CONFIG_KEY = 'imagebed_config'
const TOKEN_KEY = 'imagebed_token'
const USER_KEY = 'imagebed_user'

// 默认配置
// 在生产环境中使用空字符串，这样会使用相对路径 /api
// 在开发环境中使用 localhost
const DEFAULT_CONFIG: SystemConfig = {
  backendUrl: process.env.NODE_ENV === 'production' ? '' : 'http://localhost:8080'
}

// 获取配置
export const getConfig = (): SystemConfig => {
  const saved = localStorage.getItem(CONFIG_KEY)
  if (saved) {
    try {
      return { ...DEFAULT_CONFIG, ...JSON.parse(saved) }
    } catch {
      return DEFAULT_CONFIG
    }
  }
  return DEFAULT_CONFIG
}

// 保存配置
export const saveConfig = (config: Partial<SystemConfig>): void => {
  const current = getConfig()
  const updated = { ...current, ...config }
  localStorage.setItem(CONFIG_KEY, JSON.stringify(updated))
}

// Token 管理
export const getToken = (): string | null => {
  return localStorage.getItem(TOKEN_KEY)
}

export const setToken = (token: string): void => {
  localStorage.setItem(TOKEN_KEY, token)
}

export const removeToken = (): void => {
  localStorage.removeItem(TOKEN_KEY)
}

// 用户信息管理
export const getUser = (): any => {
  const saved = localStorage.getItem(USER_KEY)
  if (saved) {
    try {
      return JSON.parse(saved)
    } catch {
      return null
    }
  }
  return null
}

export const setUser = (user: any): void => {
  localStorage.setItem(USER_KEY, JSON.stringify(user))
}

export const removeUser = (): void => {
  localStorage.removeItem(USER_KEY)
}

// 清除所有认证信息
export const clearAuth = (): void => {
  removeToken()
  removeUser()
}
