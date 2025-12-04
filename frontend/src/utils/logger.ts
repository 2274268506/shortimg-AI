// 前端日志工具

export enum LogLevel {
  DEBUG = 'debug',
  INFO = 'info',
  WARN = 'warn',
  ERROR = 'error'
}

export interface LogEntry {
  level: LogLevel
  message: string
  timestamp: string
  module?: string
  data?: any
  error?: Error
}

class Logger {
  private logs: LogEntry[] = []
  private maxLogs = 1000 // 最多保存1000条日志
  private enableConsole = true // 是否输出到控制台

  constructor() {
    // 从 localStorage 恢复日志
    this.loadLogs()
  }

  private loadLogs() {
    try {
      const saved = localStorage.getItem('app_logs')
      if (saved) {
        this.logs = JSON.parse(saved)
      }
    } catch (error) {
      console.error('Failed to load logs:', error)
    }
  }

  private saveLogs() {
    try {
      // 只保存最近的日志
      const logsToSave = this.logs.slice(-this.maxLogs)
      localStorage.setItem('app_logs', JSON.stringify(logsToSave))
    } catch (error) {
      console.error('Failed to save logs:', error)
    }
  }

  private addLog(level: LogLevel, message: string, module?: string, data?: any, error?: Error) {
    const entry: LogEntry = {
      level,
      message,
      timestamp: new Date().toISOString(),
      module,
      data,
      error
    }

    this.logs.push(entry)

    // 保持日志数量限制
    if (this.logs.length > this.maxLogs) {
      this.logs.shift()
    }

    // 保存到 localStorage
    this.saveLogs()

    // 输出到控制台
    if (this.enableConsole) {
      this.logToConsole(entry)
    }
  }

  private logToConsole(entry: LogEntry) {
    const prefix = `[${entry.timestamp}] [${entry.level.toUpperCase()}]${entry.module ? ` [${entry.module}]` : ''}`
    
    switch (entry.level) {
      case LogLevel.DEBUG:
        console.debug(prefix, entry.message, entry.data || '')
        break
      case LogLevel.INFO:
        console.info(prefix, entry.message, entry.data || '')
        break
      case LogLevel.WARN:
        console.warn(prefix, entry.message, entry.data || '')
        break
      case LogLevel.ERROR:
        console.error(prefix, entry.message, entry.error || entry.data || '')
        break
    }
  }

  debug(message: string, module?: string, data?: any) {
    this.addLog(LogLevel.DEBUG, message, module, data)
  }

  info(message: string, module?: string, data?: any) {
    this.addLog(LogLevel.INFO, message, module, data)
  }

  warn(message: string, module?: string, data?: any) {
    this.addLog(LogLevel.WARN, message, module, data)
  }

  error(message: string, module?: string, error?: Error | any) {
    this.addLog(LogLevel.ERROR, message, module, undefined, error instanceof Error ? error : undefined)
  }

  // 获取所有日志
  getLogs(level?: LogLevel, module?: string): LogEntry[] {
    let filtered = this.logs

    if (level) {
      filtered = filtered.filter(log => log.level === level)
    }

    if (module) {
      filtered = filtered.filter(log => log.module === module)
    }

    return filtered
  }

  // 清空日志
  clearLogs() {
    this.logs = []
    localStorage.removeItem('app_logs')
  }

  // 导出日志
  exportLogs(): string {
    return JSON.stringify(this.logs, null, 2)
  }

  // 下载日志文件
  downloadLogs() {
    const dataStr = this.exportLogs()
    const dataBlob = new Blob([dataStr], { type: 'application/json' })
    const url = URL.createObjectURL(dataBlob)
    const link = document.createElement('a')
    link.href = url
    link.download = `app-logs-${new Date().toISOString()}.json`
    link.click()
    URL.revokeObjectURL(url)
  }
}

// 创建全局 logger 实例
export const logger = new Logger()

// 全局错误处理
window.addEventListener('error', (event) => {
  logger.error('Uncaught error', 'Global', event.error)
})

window.addEventListener('unhandledrejection', (event) => {
  logger.error('Unhandled promise rejection', 'Global', event.reason)
})
