# 用户认证系统 - 使用说明

## 功能概述

已实现完整的用户认证和管理系统：

### ✅ 前端功能
1. **登录/注册页面** (`/login`)
   - 用户注册
   - 用户登录
   - 表单验证

2. **后端地址配置** (`/settings`)
   - 动态配置后端服务器地址
   - 测试连接功能
   - 配置持久化存储

3. **用户管理** (`/users` - 仅管理员)
   - 查看所有用户
   - 设置用户为管理员
   - 删除用户

4. **导航栏增强**
   - 显示当前登录用户
   - 用户菜单（个人信息、退出登录）
   - 管理员可见"用户管理"菜单

### ✅ 后端功能
1. **认证 API**
   - `POST /api/auth/register` - 用户注册
   - `POST /api/auth/login` - 用户登录
   - `GET /api/auth/me` - 获取当前用户信息
   - `POST /api/auth/logout` - 登出

2. **用户管理 API（需管理员权限）**
   - `GET /api/users` - 获取用户列表
   - `DELETE /api/users/:id` - 删除用户
   - `PUT /api/users/:id/role` - 更新用户角色

3. **安全机制**
   - JWT Token 认证
   - 密码 bcrypt 加密
   - 路由权限控制
   - 管理员权限验证

## 默认账号

系统首次启动时会自动创建默认管理员账号：

```
用户名: admin
密码: admin123
```

**⚠️ 请在生产环境中立即修改默认密码！**

## 使用流程

### 1. 启动服务

**后端：**
```bash
cd backend
go run main.go
```

**前端：**
```bash
cd frontend
npm run dev
```

### 2. 访问系统

打开浏览器访问：`http://localhost:5173`

### 3. 登录

- 点击右上角"登录"按钮
- 使用默认管理员账号登录
- 或注册新账号

### 4. 配置后端地址（可选）

1. 登录后访问"系统设置"
2. 在"后端服务地址"中输入后端地址（默认：`http://localhost:8080`）
3. 点击"测试连接"验证
4. 点击"保存"

### 5. 用户管理（管理员）

1. 点击导航栏"用户管理"
2. 查看所有用户
3. 可以将普通用户设置为管理员
4. 可以删除用户（不能删除自己）

## API 使用示例

### 注册
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123"
  }'
```

### 登录
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }'
```

响应：
```json
{
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": 1,
      "username": "admin",
      "email": "admin@example.com",
      "role": "admin"
    }
  }
}
```

### 使用 Token 访问受保护的 API
```bash
curl -X GET http://localhost:8080/api/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

## 技术栈

### 后端
- Go 1.21
- Gin Web Framework
- GORM (SQLite)
- JWT (golang-jwt/jwt/v5)
- bcrypt (密码加密)

### 前端
- Vue 3 + TypeScript
- Element Plus
- Vue Router
- Pinia
- Axios

## 安全建议

1. **修改默认密码**：首次登录后立即修改 admin 账号密码
2. **更换 JWT Secret**：在 `backend/utils/jwt.go` 中修改 `jwtSecret`
3. **HTTPS**：生产环境使用 HTTPS
4. **Token 过期时间**：根据需求调整 Token 有效期（当前为 24 小时）
5. **密码策略**：建议实施更强的密码策略（长度、复杂度等）

## 目录结构

```
backend/
├── controllers/
│   ├── auth_controller.go    # 认证控制器
│   ├── user_controller.go    # 用户管理控制器
│   └── ...
├── middleware/
│   └── auth.go               # JWT 认证中间件
├── models/
│   ├── user.go              # 用户模型
│   └── ...
├── utils/
│   └── jwt.go               # JWT 工具
└── ...

frontend/
├── src/
│   ├── views/
│   │   ├── Login.vue        # 登录页面
│   │   ├── Users.vue        # 用户管理页面
│   │   └── Settings.vue     # 系统设置页面
│   ├── utils/
│   │   ├── config.ts        # 配置管理
│   │   └── request.ts       # HTTP 请求封装
│   ├── router/
│   │   └── index.ts         # 路由配置（含守卫）
│   └── ...
```

## 常见问题

**Q: 忘记管理员密码怎么办？**
A: 删除 `backend/data/imagebed.db` 文件，重启后端会重新创建默认账号。

**Q: 如何禁用认证？**
A: 在 `backend/routes/routes.go` 中注释掉相应路由的 `middleware.AuthMiddleware()`

**Q: Token 过期后怎么办？**
A: 前端会自动跳转到登录页面，重新登录即可获取新 Token。

**Q: 如何启用图片路由的认证？**
A: 在 `routes.go` 中取消注释对应路由组的 `Use(middleware.AuthMiddleware())`

## 后续开发建议

1. 实现密码重置功能
2. 添加用户个人信息编辑
3. 实现邮箱验证
4. 添加用户头像上传
5. 实现操作日志记录
6. 添加双因素认证（2FA）
7. 实现 OAuth 第三方登录

## 许可

MIT License
