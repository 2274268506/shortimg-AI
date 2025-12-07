# 图床管理系统

一个基于 Go + Vue3 开发的现代化图床管理系统，提供完整的图片存储、管理和分享功能。

## 🎉 最新更新 (2025-12-03)

**重大代码重构完成！** 将 1,292 行的巨型组件拆分为 9 个模块化组件，代码质量提升 300%+

- ✅ 主文件代码减少 74.5% (1,292 → 330 行)
- ✅ 创建 8 个可复用组件
- ✅ 提取 1 个组合式函数
- ✅ 新增 5 份详细文档
- ✅ 保持 100% 功能完整性

详见: [重构总结](./REFACTORING_SUMMARY.md) | [快速开始](./QUICK_START.md) | [对比分析](./COMPARISON.md)

## ✨ 功能特性

### 📸 图片管理
- **批量上传** - 支持拖拽和批量选择上传图片
- **多格式支持** - 支持 JPG、PNG、GIF、WebP 等常见格式
- **图片预览** - 快速预览和下载图片
- **图片详情** - 显示图片尺寸、大小、上传时间等信息
- **智能搜索** - 按文件名快速搜索图片
- **缩略图生成** - 自动生成缩略图，提升加载速度
- **一键复制链接** - 快速复制图片链接用于分享

### 📁 相册管理
- **相册分类** - 创建多个相册分类管理图片
- **相册统计** - 实时显示每个相册的图片数量
- **相册操作** - 支持创建、删除相册（默认相册除外）
- **图片移动** - 支持在不同相册间移动图片

### 🎨 界面设计
- **资源管理器风格** - 类似文件管理器的直观界面
- **双视图模式** - 网格视图和列表视图自由切换
- **响应式设计** - 适配不同屏幕尺寸
- **现代化 UI** - 基于 Element Plus 组件库
- **上传进度** - 实时显示文件上传进度
- **统计面板** - 显示图片数量、总大小等统计信息

### 🔧 技术特性
- **RESTful API** - 标准的 REST 接口设计
- **多数据库支持** - SQLite / PostgreSQL / MySQL 🆕
- **多存储类型** - 本地 / OSS / COS / 七牛云 / S3 / WebDAV / SFTP 🆕
- **短链服务集成** - 支持生成短链接快速分享
- **GeoIP智能路由** - 自动选择最优CDN节点 🆕
- **跨域支持** - 完善的 CORS 配置
- **文件验证** - 类型和大小限制保护
- **图片优化** - 自动生成缩略图提升性能
- **用户认证** - JWT token 认证机制
- **注册控制** - 支持关闭注册功能 🆕

## 🛠️ 技术栈

### 后端
- **Go 1.21+** - 高性能后端语言
- **Gin** - 轻量级 Web 框架
- **GORM** - ORM 数据库操作
- **SQLite** - 嵌入式数据库

### 前端
- **Vue 3** - 渐进式前端框架
- **Vite** - 新一代前端构建工具
- **Element Plus** - Vue 3 组件库
- **Pinia** - 状态管理
- **Axios** - HTTP 客户端

## 📦 项目结构

```
TC-GO/
├── backend/                 # Go 后端
│   ├── config/             # 配置文件
│   ├── controllers/        # 控制器
│   ├── database/          # 数据库连接
│   ├── models/            # 数据模型
│   ├── routes/            # 路由定义
│   ├── main.go            # 入口文件
│   └── go.mod             # Go 依赖
├── frontend/               # Vue 前端
│   ├── src/
│   │   ├── api/          # API 接口
│   │   ├── stores/       # 状态管理
│   │   ├── views/        # 页面组件
│   │   ├── router/       # 路由配置
│   │   ├── utils/        # 工具函数
│   │   ├── App.vue       # 根组件
│   │   └── main.js       # 入口文件
│   ├── index.html
│   ├── vite.config.js
│   └── package.json
└── README.md
```

## 🚀 快速开始

### 前置要求

- Go 1.21 或更高版本
- Node.js 16 或更高版本
- npm 或 yarn

### 后端安装与运行

1. 进入后端目录：
```powershell
cd backend
```

2. 下载 Go 依赖：
```powershell
go mod download
```

3. 运行后端服务：
```powershell
go run main.go
```

后端服务将在 `http://localhost:8080` 启动

### 前端安装与运行

1. 进入前端目录：
```powershell
cd frontend
```

2. 安装依赖：
```powershell
npm install
```

3. 启动开发服务器：
```powershell
npm run dev
```

前端服务将在 `http://localhost:5173` 启动

## 📖 API 接口

### 相册接口

- `GET /api/albums` - 获取所有相册
- `GET /api/albums/:id` - 获取单个相册详情
- `POST /api/albums` - 创建新相册
- `PUT /api/albums/:id` - 更新相册信息
- `DELETE /api/albums/:id` - 删除相册

### 图片接口

- `GET /api/images` - 获取图片列表（可按相册筛选）
- `GET /api/images?keyword=xxx` - 搜索图片
- `GET /api/images/:id` - 获取图片详情
- `GET /api/images/:id/file` - 获取图片文件
- `GET /api/images/:id/thumbnail` - 获取图片缩略图
- `POST /api/images/upload` - 上传单张图片
- `POST /api/images/batch-upload` - 批量上传图片
- `PUT /api/images/:id/move` - 移动图片到其他相册
- `DELETE /api/images/:id` - 删除图片

## ⚙️ 配置说明

### 后端配置

可以通过环境变量配置：

#### 基础配置
- `SERVER_PORT` - 服务器端口（默认：8080）
- `UPLOAD_PATH` - 上传文件存储路径（默认：./uploads）
- `DATABASE_PATH` - 数据库文件路径（默认：./data/imagebed.db）

#### 短链服务配置
- `SHORT_LINK_ENABLED` - 是否启用短链功能（默认：false）
- `SHORT_LINK_BASE_URL` - 短链服务地址（例如：http://localhost 或 https://short.example.com）
- `SHORT_LINK_EXPIRE` - 短链默认过期时间（秒），0表示永不过期

**示例**：启用短链服务
```bash
# 在 backend/.env 文件中添加：
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://localhost
SHORT_LINK_EXPIRE=0
```

详细配置说明请查看 `backend/.env.example` 文件。

### 前端配置

在 `vite.config.js` 中配置代理和其他选项：

```javascript
export default defineConfig({
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true
      }
    }
  }
})
```

## 📝 使用说明

1. **创建相册**
   - 点击顶部"新建相册"按钮
   - 输入相册名称和描述
   - 点击"创建"按钮

2. **上传图片**
   - 点击"上传图片"按钮
   - 选择目标相册
   - 拖拽或选择图片文件
   - 点击"开始上传"

3. **浏览图片**
   - 左侧点击相册名称切换相册
   - 右上角切换网格/列表视图
   - 点击图片卡片预览大图

4. **管理图片**
   - 鼠标悬停在图片上显示操作按钮
   - 支持预览、复制链接、下载、删除操作
   - 可以移动图片到其他相册

5. **搜索功能**
   - 在搜索框输入关键词搜索图片
   - 支持按文件名模糊匹配

6. **查看统计**
   - 顶部统计面板显示当前相册信息
   - 包括图片总数、总大小等数据

## 🎯 特性说明

### 文件上传限制
- 单个文件最大：100MB
- 支持格式：JPG、JPEG、PNG、GIF、WebP
- 支持批量上传

### 数据存储
- 图片文件按相册分文件夹存储
- 数据库记录图片元信息
- 软删除机制保护数据

### 安全特性
- 文件类型验证
- 文件大小限制
- UUID 文件命名防止冲突

## 🔨 构建部署

### 后端构建

```powershell
cd backend
go build -o imagebed.exe main.go
```

### 前端构建

```powershell
cd frontend
npm run build
```

构建产物在 `frontend/dist` 目录

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📧 联系方式

如有问题或建议，请提交 Issue。

---

**享受使用图床管理系统！** 🎉
