# 🔐 默认管理员账户配置指南

## 📋 概述

ShortImg-AI 支持通过环境变量自定义默认管理员账户。首次部署时，系统会自动创建一个管理员账户供您登录。

## ⚙️ 配置方式

### 方法 1: 修改 `.env` 文件（推荐）

编辑后端目录下的 `.env` 文件：

```bash
# ==================== 默认管理员账户配置 ====================
# ⚠️ 首次部署会自动创建此账户，请务必修改默认密码！

# 默认管理员用户名
DEFAULT_ADMIN_USERNAME=admin

# 默认管理员密码（请修改为强密码）
DEFAULT_ADMIN_PASSWORD=your_strong_password_here

# 默认管理员邮箱
DEFAULT_ADMIN_EMAIL=your-email@example.com
```

### 方法 2: 环境变量（Docker）

在 `docker-compose.prod.yml` 中已自动配置，从 `.env` 文件读取：

```yaml
environment:
  DEFAULT_ADMIN_USERNAME: ${DEFAULT_ADMIN_USERNAME:-admin}
  DEFAULT_ADMIN_PASSWORD: ${DEFAULT_ADMIN_PASSWORD:-admin123}
  DEFAULT_ADMIN_EMAIL: ${DEFAULT_ADMIN_EMAIL:-admin@example.com}
```

### 方法 3: 直接设置环境变量

```bash
export DEFAULT_ADMIN_USERNAME=myadmin
export DEFAULT_ADMIN_PASSWORD=MySecurePassword123!
export DEFAULT_ADMIN_EMAIL=admin@mydomain.com
```

## 🔒 安全建议

### ⚠️ 重要：生产环境必须修改！

**默认值（仅用于开发）：**
- 用户名: `admin`
- 密码: `admin123`
- 邮箱: `admin@example.com`

### ✅ 安全密码要求

强密码应满足以下条件：
- ✅ 至少 12 个字符
- ✅ 包含大写字母 (A-Z)
- ✅ 包含小写字母 (a-z)
- ✅ 包含数字 (0-9)
- ✅ 包含特殊字符 (!@#$%^&*...)

**推荐密码示例：**
```bash
MySecurePassword@2024!
Admin#ShortImg$2024
P@ssw0rd!Complex#123
```

### 🛡️ 生成强密码

**方法 1: 使用 OpenSSL**
```bash
openssl rand -base64 24
```

**方法 2: 使用 Python**
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(24))"
```

**方法 3: 在线生成器**
- https://passwordsgenerator.net/
- https://www.random.org/passwords/

## 📝 配置示例

### 开发环境 (`.env`)

```bash
# 开发环境 - 简单密码便于测试
DEFAULT_ADMIN_USERNAME=admin
DEFAULT_ADMIN_PASSWORD=admin123
DEFAULT_ADMIN_EMAIL=admin@localhost
ALLOW_REGISTRATION=true
```

### 生产环境 (`.env.prod`)

```bash
# 生产环境 - 强密码 + 禁止注册
DEFAULT_ADMIN_USERNAME=administrator
DEFAULT_ADMIN_PASSWORD=MyVerySecurePassword@2024!#ShortImg
DEFAULT_ADMIN_EMAIL=admin@img.oxvxo.link
ALLOW_REGISTRATION=false
```

## 🚀 部署流程

### 1️⃣ 首次部署前配置

```bash
# 1. 编辑 .env 文件
cd backend
nano .env  # 或 vim .env

# 2. 修改默认管理员配置
DEFAULT_ADMIN_USERNAME=yourusername
DEFAULT_ADMIN_PASSWORD=YourStrongPassword123!
DEFAULT_ADMIN_EMAIL=your-email@example.com

# 3. 保存并启动服务
docker-compose -f docker-compose.prod.yml up -d
```

### 2️⃣ 首次登录

访问前端页面，使用配置的账户登录：
```
用户名: yourusername
密码: YourStrongPassword123!
```

### 3️⃣ 修改密码（推荐）

登录后立即修改密码：
1. 进入 **个人中心** 或 **设置**
2. 选择 **修改密码**
3. 输入当前密码和新密码
4. 保存更改

## 🔍 工作原理

### 自动创建逻辑

系统启动时会检查数据库：

```go
// 检查是否已有用户
var userCount int64
DB.Model(&models.User{}).Count(&userCount)

if userCount == 0 {
    // 没有用户，创建默认管理员
    cfg := config.GetConfig()
    adminUser := models.User{
        Username: cfg.DefaultAdminUsername,
        Email:    cfg.DefaultAdminEmail,
        Role:     "admin",
    }
    adminUser.HashPassword(cfg.DefaultAdminPassword)
    DB.Create(&adminUser)
    log.Printf("✅ 已创建默认管理员账号 - 用户名: %s", cfg.DefaultAdminUsername)
}
```

### 配置优先级

1. **环境变量** (最高优先级)
2. **`.env` 文件**
3. **代码默认值** (admin/admin123)

## ❓ 常见问题

### Q1: 忘记管理员密码怎么办？

**方法 A: 重置数据库（开发环境）**
```bash
# 删除数据库文件，重新初始化
docker-compose down -v
docker-compose up -d
```

**方法 B: 直接修改数据库（生产环境）**
```sql
-- 连接数据库
docker exec -it shortimg-mysql-prod mysql -u root -p

-- 使用数据库
USE imagebed;

-- 查看管理员用户
SELECT id, username, email, role FROM users WHERE role='admin';

-- 重置密码为 newpassword123
-- 注意：需要使用正确的哈希值，建议使用应用程序提供的重置功能
```

**方法 C: 临时开放注册（推荐）**
```bash
# 1. 修改 .env
ALLOW_REGISTRATION=true

# 2. 重启服务
docker-compose restart backend

# 3. 注册新的管理员账户
# 4. 在数据库中将新用户角色改为 admin

# 5. 关闭注册
ALLOW_REGISTRATION=false
docker-compose restart backend
```

### Q2: 如何添加更多管理员？

**方法 A: 通过界面（如果有用户管理功能）**
1. 以管理员身份登录
2. 进入用户管理
3. 修改用户角色为 `admin`

**方法 B: 直接修改数据库**
```sql
-- 将用户 ID 为 2 的用户设为管理员
UPDATE users SET role='admin' WHERE id=2;
```

### Q3: 默认账户配置不生效？

**检查清单：**

1. ✅ 确认 `.env` 文件在正确位置
```bash
ls -la backend/.env
```

2. ✅ 确认配置已加载
```bash
docker exec shortimg-backend-prod printenv | grep DEFAULT_ADMIN
```

3. ✅ 确认数据库为空（首次部署）
```bash
# 如果数据库已有用户，默认账户不会创建
docker exec -it shortimg-mysql-prod mysql -u root -p -e "SELECT COUNT(*) FROM imagebed.users;"
```

4. ✅ 查看日志确认
```bash
docker logs shortimg-backend-prod | grep "管理员"
```

### Q4: 密码哈希如何工作？

系统使用 bcrypt 算法加密密码：
- ✅ 单向加密，无法反向解密
- ✅ 每次加密结果不同（加盐）
- ✅ 自动验证时间复杂度防暴力破解

```go
// 密码加密
func (u *User) HashPassword(password string) error {
    hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    if err != nil {
        return err
    }
    u.Password = string(hashedPassword)
    return nil
}

// 密码验证
func (u *User) CheckPassword(password string) bool {
    err := bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(password))
    return err == nil
}
```

## 📊 安全检查清单

部署前请确认：

- [ ] 已修改默认管理员密码
- [ ] 密码符合强密码要求（12+ 字符，大小写+数字+符号）
- [ ] 已设置真实邮箱地址
- [ ] `ALLOW_REGISTRATION=false`（除非需要公开注册）
- [ ] JWT_SECRET 已修改为随机字符串（32+ 字符）
- [ ] 数据库密码已修改
- [ ] 定期备份数据库

## 🔗 相关文档

- [生产环境部署指南](PRODUCTION_DEPLOY.md)
- [安全配置最佳实践](SECURITY_BEST_PRACTICES.md)
- [用户管理文档](USER_MANAGEMENT.md)

## 💡 最佳实践

1. **使用密码管理器** - 如 1Password、LastPass、Bitwarden
2. **定期更换密码** - 建议每 90 天更换一次
3. **启用双因素认证** (如果支持)
4. **记录管理员操作** - 审计日志
5. **最小权限原则** - 仅授予必要权限
6. **备份恢复测试** - 定期测试备份恢复流程

## 📞 获取帮助

如有问题，请：
1. 查看日志: `docker logs shortimg-backend-prod`
2. 检查配置: `docker exec shortimg-backend-prod printenv`
3. 提交 Issue: [GitHub Issues](https://github.com/your-repo/issues)
