// 图片懒加载指令
import type { DirectiveBinding } from 'vue'

export const lazyLoad = {
  mounted(el: HTMLImageElement, binding: DirectiveBinding<string>) {
    const imageObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const img = entry.target as HTMLImageElement
          const src = binding.value
          
          // 添加加载状态
          img.classList.add('lazy-loading')
          
          // 创建临时图片对象预加载
          const tempImg = new Image()
          tempImg.onload = () => {
            img.src = src
            img.classList.remove('lazy-loading')
            img.classList.add('lazy-loaded')
          }
          tempImg.onerror = () => {
            img.classList.remove('lazy-loading')
            img.classList.add('lazy-error')
            // 设置错误占位图
            img.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"%3E%3Crect fill="%23f5f5f5" width="100" height="100"/%3E%3Ctext x="50" y="50" text-anchor="middle" dominant-baseline="middle" fill="%23999"%3E加载失败%3C/text%3E%3C/svg%3E'
          }
          tempImg.src = src
          
          // 停止观察
          imageObserver.unobserve(img)
        }
      })
    }, {
      rootMargin: '50px', // 提前50px开始加载
      threshold: 0.01
    })

    imageObserver.observe(el)
    
    // 保存 observer 以便后续清理
    ;(el as any)._imageObserver = imageObserver
  },
  
  unmounted(el: HTMLImageElement) {
    const observer = (el as any)._imageObserver
    if (observer) {
      observer.disconnect()
      delete (el as any)._imageObserver
    }
  }
}
