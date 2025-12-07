# 短链服务配置优化更新日志

## 更新日期
2025-12-03

## 更新内容

### ✨ 新功能
图床后端现在支持通过环境变量配置短链服务器地址，不再硬编码在代码中。

### 📝 修改文件

#### 1. `backend/controllers/image_controller.go`
**修改内容**：
- 将硬编码的短链服务器地址 `http://localhost` 替换为从配置读取 `cfg.ShortLinkBaseURL`
- 单张图片上传（第 190 行）
- 批量上传（第 591 行）

**修改前**：
```go
shortLinkClient := utils.NewShortLinkClient("http://localhost")
```

**修改后**：
```go
shortLinkClient := utils.NewShortLinkClient(cfg.ShortLinkBaseURL)
```

#### 2. `README.md`
**修改内容**：
- 添加短链服务配置说明
- 提供配置示例

### ⚙️ 配置使用

#### 环境变量配置

在 `backend/.env` 文件中添加以下配置：

```bash
# ==================== 短链服务配置 ====================
# 是否启用短链功能 (true/false)
SHORT_LINK_ENABLED=true

# 短链服务基础URL (例如: http://localhost 或 https://short.example.com)
SHORT_LINK_BASE_URL=http://localhost

# 短链默认过期时间（秒），0表示永不过期
# 7天: 604800, 30天: 2592000, 365天: 31536000
SHORT_LINK_EXPIRE=0
```

#### 配置说明

| 配置项 | 说明 | 默认值 | 示例 |
|--------|------|--------|------|
| `SHORT_LINK_ENABLED` | 是否启用短链功能 | `false` | `true` |
| `SHORT_LINK_BASE_URL` | 短链服务器地址 | `http://localhost` | `https://s.yourdomain.com` |
| `SHORT_LINK_EXPIRE` | 短链过期时间（秒） | `0`（永不过期） | `604800`（7天） |

#### 配置示例

**本地开发环境**：
```bash
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=http://localhost
SHORT_LINK_EXPIRE=0
```

**生产环境**：
```bash
SHORT_LINK_ENABLED=true
SHORT_LINK_BASE_URL=https://s.yourdomain.com
SHORT_LINK_EXPIRE=2592000  # 30天过期
```

### 🔍 技术细节

#### 配置读取流程
1. 应用启动时，`config.LoadConfig()` 从环境变量读取配置
2. `image_controller.go` 在初始化时接收配置对象 `cfg`
3. 创建短链客户端时使用 `cfg.ShortLinkBaseURL`

#### 向后兼容性
- 所有配置项都有默认值
- 不配置短链服务器地址时，默认使用 `http://localhost`
- 可以通过 `SHORT_LINK_ENABLED=false` 关闭短链功能

### 📋 完整的配置文件

完整的环境变量配置请参考 `backend/.env.example` 文件，包含：
- 数据库配置（SQLite/PostgreSQL/MySQL）
- Redis 缓存配置
- 服务器配置
- JWT 配置
- 文件上传配置
- 存储配置（本地/OSS/COS/七牛/S3）
- 日志配置
- **短链服务配置** ← 本次新增说明

### 🚀 使用建议

1. **开发环境**：使用默认的 `http://localhost` 即可
2. **生产环境**：建议使用独立域名（如 `https://s.yourdomain.com`）
3. **安全性**：如果短链服务需要认证，请在 `shortlink_client.go` 中添加认证逻辑
4. **高可用**：生产环境建议使用负载均衡和多实例部署短链服务

### 🔄 迁移指南

如果你之前使用的是硬编码的短链服务器地址，现在需要：

1. **复制示例配置文件**：
   ```bash
   cd backend
   cp .env.example .env
   ```

2. **编辑配置文件**：
   ```bash
   # 修改 .env 文件，设置短链服务器地址
   SHORT_LINK_ENABLED=true
   SHORT_LINK_BASE_URL=http://your-shortlink-server
   ```

3. **重启应用**：
   ```bash
   go run main.go
   ```

### ✅ 测试验证

1. 启动图床后端服务
2. 上传一张图片到启用短链的相册
3. 检查是否成功生成短链
4. 验证短链跳转是否正常

### 📚 相关文档

- [完整配置说明](backend/.env.example)
- [短链服务文档](redirect-service/README.md)
- [主要功能说明](README.md)

---

**注意**：配置完成后需要重启应用才能生效。
