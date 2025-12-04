# 日志系统文档

## 系统概览

本项目实现了一个完整的三层日志系统：
1. **后端结构化日志**（使用 zap）
2. **数据库操作日志**（OperationLog 和 SystemLog）
3. **前端日志系统**（客户端日志）

---

## 后端日志系统

### 1. 结构化日志（zap）

#### 特性
- ✅ 高性能结构化日志
- ✅ JSON 格式输出到文件
- ✅ 彩色控制台输出
- ✅ 自动日志轮转（lumberjack）
- ✅ 多级别日志（Debug, Info, Warn, Error, Fatal）

#### 配置
```go
// backend/logger/logger.go
- 文件路径: ./logs/app.log
- 最大大小: 100MB
- 保留备份: 30个
- 保留天数: 90天
- 压缩: 启用
```

#### 使用方法
```go
import (
    "imagebed/logger"
    "go.uber.org/zap"
)

// 简单日志
logger.Info("服务器启动", zap.String("addr", ":8080"))
logger.Error("数据库错误", zap.Error(err))

// 带字段的日志
logger.Debug("用户登录", 
    zap.Uint("user_id", userID),
    zap.String("ip", clientIP),
)
```

### 2. 日志中间件

#### LoggerMiddleware
自动记录所有 HTTP 请求：
- 请求方法和路径
- 状态码
- 响应时间
- 客户端 IP
- 用户信息（如已登录）
- 错误信息

#### RecoveryMiddleware
捕获panic并记录：
- 错误详情
- 请求路径
- 客户端信息

---

## 数据库日志表

### OperationLog（操作日志）

记录用户的业务操作：

```go
type OperationLog struct {
    ID          uint      // 主键
    CreatedAt   time.Time // 创建时间
    
    // 用户信息
    UserID      uint      // 用户ID
    Username    string    // 用户名
    
    // 操作信息
    Action      string    // 操作类型: create, update, delete, upload, download
    Module      string    // 模块: image, album, user
    ResourceID  uint      // 资源ID
    Description string    // 操作描述
    
    // 请求信息
    Method      string    // HTTP方法
    Path        string    // 请求路径
    IP          string    // 客户端IP
    UserAgent   string    // 用户代理
    
    // 结果信息
    Status      int       // HTTP状态码
    Error       string    // 错误信息
    Latency     int64     // 响应时间（毫秒）
    Extra       string    // 额外信息（JSON）
}
```

### SystemLog（系统日志）

记录系统级别的日志：

```go
type SystemLog struct {
    ID        uint      // 主键
    CreatedAt time.Time // 创建时间
    
    Level     string    // 日志级别: debug, info, warn, error, fatal
    Module    string    // 模块名称
    Message   string    // 日志消息
    Error     string    // 错误堆栈
    Extra     string    // 额外信息（JSON）
}
```

---

## API 接口

### 获取操作日志
```http
GET /api/logs/operations
Authorization: Bearer <token>  (管理员)

Query Parameters:
- page: 页码（默认1）
- pageSize: 每页数量（默认20）
- module: 模块筛选（image/album/user）
- action: 操作筛选（create/update/delete/upload/download）
- user_id: 用户ID筛选

Response:
{
  "data": [...],
  "pagination": {
    "total": 100,
    "page": 1,
    "page_size": 20
  }
}
```

### 获取系统日志
```http
GET /api/logs/system
Authorization: Bearer <token>  (管理员)

Query Parameters:
- page: 页码
- pageSize: 每页数量
- level: 级别筛选（debug/info/warn/error）
- module: 模块筛选
```

### 清理旧日志
```http
POST /api/logs/clear?days=90
Authorization: Bearer <token>  (管理员)

删除指定天数之前的日志
```

---

## 前端日志系统

### 特性
- ✅ 客户端日志记录
- ✅ localStorage 持久化
- ✅ 自动日志轮转（最多1000条）
- ✅ 全局错误捕获
- ✅ 日志导出功能

### 使用方法

```typescript
import { logger } from '@/utils/logger'

// 记录不同级别的日志
logger.debug('调试信息', 'ModuleName', { data: 'some data' })
logger.info('普通信息', 'ModuleName')
logger.warn('警告信息', 'ModuleName')
logger.error('错误信息', 'ModuleName', error)

// 获取日志
const allLogs = logger.getLogs()
const errorLogs = logger.getLogs(LogLevel.ERROR)
const moduleLogs = logger.getLogs(undefined, 'ModuleName')

// 管理日志
logger.clearLogs()          // 清空日志
logger.downloadLogs()       // 下载日志文件
logger.exportLogs()         // 导出JSON字符串
```

### 自动错误捕获

```typescript
// 全局错误
window.addEventListener('error', (event) => {
  logger.error('Uncaught error', 'Global', event.error)
})

// Promise 拒绝
window.addEventListener('unhandledrejection', (event) => {
  logger.error('Unhandled promise rejection', 'Global', event.reason)
})
```

---

## 日志管理页面

### 访问路径
```
http://localhost:5173/logs
```

### 权限要求
仅管理员可访问

### 功能
1. **操作日志**
   - 查看所有用户操作
   - 按模块、操作类型筛选
   - 查看IP、状态码、响应时间

2. **系统日志**
   - 查看系统级别日志
   - 按级别、模块筛选
   - 查看错误堆栈

3. **前端日志**
   - 查看浏览器端日志
   - 按级别筛选
   - 下载日志文件
   - 清空日志

4. **批量操作**
   - 导出日志（JSON格式）
   - 清理90天前的旧日志

---

## 日志文件位置

### 后端日志
```
backend/logs/
├── app.log              # 当前日志
├── app.log.2024-12-01   # 轮转日志（压缩）
├── app.log.2024-12-02
└── ...
```

### 前端日志
存储在浏览器 localStorage：
```
Key: app_logs
Value: JSON array of log entries
```

---

## 最佳实践

### 1. 日志级别使用

- **Debug**: 调试信息，开发环境使用
- **Info**: 正常业务流程
- **Warn**: 警告信息，不影响功能
- **Error**: 错误信息，需要关注
- **Fatal**: 致命错误，程序无法继续

### 2. 日志内容

**好的日志：**
```go
logger.Info("用户上传图片",
    zap.Uint("user_id", userID),
    zap.String("filename", filename),
    zap.Int64("size", size),
    zap.String("album", albumName),
)
```

**避免：**
```go
logger.Info("上传成功") // 缺少上下文
```

### 3. 性能考虑

- 使用 zap 的字段方式，避免字符串拼接
- 生产环境关闭 Debug 级别
- 定期清理旧日志

### 4. 敏感信息

**不要记录：**
- 密码
- Token
- 个人隐私信息
- 完整的信用卡号

---

## 监控和告警

### 建议实施

1. **日志聚合**
   - 使用 ELK Stack（Elasticsearch, Logstash, Kibana）
   - 或使用 Grafana Loki

2. **告警规则**
   - Error 日志超过阈值
   - 响应时间过长
   - 特定错误模式

3. **日志分析**
   - 定期分析错误日志
   - 识别性能瓶颈
   - 用户行为分析

---

## 故障排查

### 查看最近的错误
```bash
# 后端日志
tail -f backend/logs/app.log | grep ERROR

# 或使用 jq 解析 JSON
tail -f backend/logs/app.log | jq 'select(.level=="error")'
```

### 数据库查询
```sql
-- 查询最近的错误操作
SELECT * FROM operation_logs 
WHERE status >= 400 
ORDER BY created_at DESC 
LIMIT 20;

-- 查询特定用户的操作
SELECT * FROM operation_logs 
WHERE user_id = 1 
ORDER BY created_at DESC;

-- 统计错误类型
SELECT module, action, COUNT(*) as count 
FROM operation_logs 
WHERE status >= 400 
GROUP BY module, action;
```

---

## 配置选项

### 环境变量

```bash
# .env 文件
LOG_LEVEL=info              # 日志级别
LOG_PATH=./logs/app.log     # 日志文件路径
LOG_MAX_SIZE=100            # 最大文件大小（MB）
LOG_MAX_AGE=90              # 保留天数
LOG_MAX_BACKUPS=30          # 备份文件数量
LOG_COMPRESS=true           # 是否压缩
```

---

## 总结

✅ **已实现功能**
- 完整的三层日志系统
- 自动日志轮转
- 日志查询和筛选
- 日志导出
- 全局错误捕获
- 管理界面

🔄 **后续优化**
- 日志聚合和分析
- 实时告警
- 日志可视化
- 性能监控集成

现在你的系统拥有了企业级的日志系统！🎉
