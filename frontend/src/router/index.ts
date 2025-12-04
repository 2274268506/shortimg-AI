import { createRouter, createWebHistory } from 'vue-router'
import ImageManager from '../views/ImageManager.vue'
import Statistics from '../views/Statistics.vue'
import Settings from '../views/Settings.vue'
import Login from '../views/Login.vue'
import Users from '../views/Users.vue'
import Logs from '../views/Logs.vue'
import Profile from '../views/Profile.vue'
import { getToken, getUser } from '@/utils/config'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: Login,
      meta: { requiresAuth: false }
    },
    {
      path: '/',
      name: 'home',
      component: ImageManager,
      meta: { requiresAuth: true }
    },
    {
      path: '/statistics',
      name: 'statistics',
      component: Statistics,
      meta: { requiresAuth: true }
    },
    {
      path: '/profile',
      name: 'profile',
      component: Profile,
      meta: { requiresAuth: true }
    },
    {
      path: '/settings',
      name: 'settings',
      component: Settings,
      meta: { requiresAuth: true }
    },
    {
      path: '/users',
      name: 'users',
      component: Users,
      meta: { requiresAuth: true, requiresAdmin: true }
    },
    {
      path: '/logs',
      name: 'logs',
      component: Logs,
      meta: { requiresAuth: true, requiresAdmin: true }
    }
  ]
})

// 路由守卫
router.beforeEach((to, _from, next) => {
  const token = getToken()
  const user = getUser()

  // 需要认证的页面
  if (to.meta.requiresAuth && !token) {
    next('/login')
    return
  }

  // 需要管理员权限的页面
  if (to.meta.requiresAdmin) {
    if (!user || user.role !== 'admin') {
      // 非管理员用户，重定向到首页并提示
      console.warn('访问管理员页面需要管理员权限')
      next('/')
      return
    }
  }

  // 已登录用户访问登录页，重定向到首页
  if (to.path === '/login' && token) {
    next('/')
    return
  }

  next()
})

export default router

