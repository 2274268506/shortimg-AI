# WebDAV 和 SFTP 快速部署指南

## 快速开始

### 1️⃣ 拉取最新代码

```bash
cd TC-GO/backend
git pull
```

### 2️⃣ 安装新依赖

```bash
go get github.com/studio-b12/gowebdav@v0.11.0
go get github.com/pkg/sftp@v1.13.10
go get golang.org/x/crypto/ssh
```

### 3️⃣ 编译测试

```bash
go build -o imagebed
```

如果编译成功，表示所有依赖已正确安装。

---

## 配置示例

### 坚果云 WebDAV (推荐个人用户)

**1. 获取应用密码**
- 登录坚果云网页版：https://www.jianguoyun.com/
- 账户信息 → 安全选项 → 第三方应用管理
- 添加应用 → 输入 `imagebed` → 生成密码
- 复制密码备用

**2. 修改 `.env` 文件**
```bash
# 基础配置
DATABASE_TYPE=sqlite
DATABASE_PATH=./data/imagebed.db
SERVER_PORT=8080

# 存储配置 - 坚果云
STORAGE_TYPE=webdav
WEBDAV_URL=https://dav.jianguoyun.com/dav/
WEBDAV_USERNAME=your_email@example.com
WEBDAV_PASSWORD=abc123xyz456  # 应用密码（不是登录密码）
WEBDAV_BASE_PATH=/imagebed/
WEBDAV_BASE_URL=

# 短链服务
SHORT_LINK_BASE_URL=http://your-shortlink-service.com
SHORT_LINK_API_KEY=your-api-key
```

**3. 启动服务**
```bash
./imagebed
```

---

### VPS SFTP (推荐 VPS 用户)

**1. 生成 SSH 密钥（推荐）**
```bash
# 在本机生成密钥
ssh-keygen -t ed25519 -C "imagebed@yourserver.com"

# 复制公钥到服务器
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@your-server.com
```

**2. 修改 `.env` 文件（密钥认证）**
```bash
# 基础配置
DATABASE_TYPE=postgres
DATABASE_DSN=postgres://user:pass@localhost:5432/imagebed?sslmode=disable
SERVER_PORT=8080

# 存储配置 - SFTP
STORAGE_TYPE=sftp
SFTP_HOST=123.45.67.89
SFTP_PORT=22
SFTP_USERNAME=imagebed
SFTP_PRIVATE_KEY=/root/.ssh/id_ed25519  # 私钥路径
SFTP_PASSWORD=  # 留空（使用密钥认证）
SFTP_BASE_PATH=/var/www/html/images/
SFTP_BASE_URL=https://img.yourserver.com/

# 短链服务
SHORT_LINK_BASE_URL=http://short.yourserver.com
SHORT_LINK_API_KEY=secret-key-123
```

**3. 创建远程目录（可选）**
```bash
ssh user@your-server.com "mkdir -p /var/www/html/images"
```

**4. 启动服务**
```bash
./imagebed
```

---

## 验证部署

### 方法1: 使用测试脚本

**Linux/macOS:**
```bash
chmod +x test_storage.sh
./test_storage.sh
```

**Windows (PowerShell):**
```powershell
.\test_storage.ps1
```

### 方法2: 手动测试

**WebDAV:**
```bash
curl -X PROPFIND \
  -u "username:password" \
  "https://dav.jianguoyun.com/dav/"
```

**SFTP:**
```bash
# 测试 SSH 连接
ssh -p 22 user@your-server.com "echo 'Connection OK'"

# 测试 SFTP
echo "ls" | sftp -P 22 user@your-server.com
```

### 方法3: 上传测试图片

1. 访问 `http://localhost:8080`
2. 登录系统
3. 上传一张图片
4. 检查文件是否出现在 WebDAV/SFTP 服务器
5. 验证返回的 URL 是否可访问

---

## 切换存储类型

如果想从其他存储类型切换到 WebDAV/SFTP：

1. **备份数据库**
```bash
cp data/imagebed.db data/imagebed.db.backup
```

2. **修改 `.env` 配置**
```bash
# 修改 STORAGE_TYPE 和对应配置
STORAGE_TYPE=webdav  # 或 sftp
```

3. **重启服务**
```bash
# 停止服务
Ctrl+C

# 重新启动
./imagebed
```

4. **数据迁移（可选）**
- 新上传的文件会存储到新位置
- 旧文件需要手动迁移或保留在原存储

---

## 常见问题

### ❓ 坚果云连接失败？
**检查清单:**
- ✅ 使用的是**应用密码**（非登录密码）
- ✅ 用户名是**邮箱地址**
- ✅ URL 格式正确：`https://dav.jianguoyun.com/dav/`

### ❓ SFTP 连接超时？
**检查清单:**
- ✅ 服务器 IP 和端口正确
- ✅ 防火墙已开放 SSH 端口
- ✅ SSH 服务正在运行：`systemctl status sshd`

### ❓ 密钥认证失败？
**检查清单:**
- ✅ 私钥文件路径正确
- ✅ 私钥权限为 600：`chmod 600 ~/.ssh/id_rsa`
- ✅ 公钥已添加到服务器：`~/.ssh/authorized_keys`
- ✅ authorized_keys 权限为 600

### ❓ 文件上传成功但无法访问？
**检查清单:**
- ✅ `WEBDAV_BASE_URL` 或 `SFTP_BASE_URL` 配置正确
- ✅ Web 服务器（Nginx/Apache）已配置对应目录
- ✅ 目录权限允许 Web 服务器读取

---

## 性能对比

| 存储类型 | 上传速度 | 下载速度 | 延迟 | 成本 |
|---------|---------|---------|------|------|
| 本地 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 最低 | 免费 |
| OSS/COS | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 低 | 付费 |
| 坚果云 | ⭐⭐⭐ | ⭐⭐⭐ | 中等 | 免费/付费 |
| SFTP | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 中等 | VPS费用 |
| S3 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 低 | 付费 |

---

## 安全建议

### WebDAV 安全
- ✅ 使用应用密码，定期更换
- ✅ 确保使用 HTTPS 协议
- ✅ 不要在公共环境配置

### SFTP 安全
- ✅ **优先使用密钥认证**
- ✅ 禁用 root 登录
- ✅ 修改默认 SSH 端口
- ✅ 配置 fail2ban 防暴力破解
- ✅ 定期更新系统
- ✅ 私钥文件权限 600

### 通用安全
- ✅ `.env` 文件加入 `.gitignore`
- ✅ 不要将密钥提交到版本控制
- ✅ 生产环境使用环境变量
- ✅ 定期备份数据库

---

## 技术支持

- 📖 详细文档：`STORAGE_GUIDE.md`
- 🐛 问题反馈：GitHub Issues
- 💬 讨论交流：GitHub Discussions

---

## 更新日志

查看完整更新内容：`CHANGELOG.md`

**v1.6.0 主要更新:**
- ✅ 新增 WebDAV 存储支持
- ✅ 新增 SFTP 存储支持
- ✅ 支持 7 种存储类型
- ✅ 完善文档和测试工具
