import axios, { type AxiosInstance, type InternalAxiosRequestConfig, type AxiosResponse } from 'axios'
import { ElMessage } from 'element-plus'
import { getConfig, getToken } from './config'

const createRequest = (): AxiosInstance => {
  const config = getConfig()
  
  const request = axios.create({
    baseURL: `${config.backendUrl}/api`,
    timeout: 30000
  })

  // 请求拦截器
  request.interceptors.request.use(
    (config: InternalAxiosRequestConfig) => {
      // 添加 token
      const token = getToken()
      if (token && config.headers) {
        config.headers.Authorization = `Bearer ${token}`
      }
      return config
    },
    (error: any) => {
      console.error('请求错误:', error)
      return Promise.reject(error)
    }
  )

  // 响应拦截器
  request.interceptors.response.use(
    (response: AxiosResponse) => {
      return response.data
    },
    (error: any) => {
      const message = error.response?.data?.error || '请求失败'
      
      // 401 未授权，跳转到登录页
      if (error.response?.status === 401) {
        ElMessage.error('请先登录')
        // 可以在这里跳转到登录页
        // router.push('/login')
      } else {
        ElMessage.error(message)
      }
      
      return Promise.reject(error)
    }
  )
  
  return request
}

const request = createRequest()

// 更新 baseURL 的方法
export const updateBaseURL = (url: string) => {
  request.defaults.baseURL = `${url}/api`
}

export default request
