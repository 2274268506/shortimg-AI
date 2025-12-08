# 📁 短链服务配置文件说明

## 📋 使用 `short.oxvxo.link` 域名的配置清单

### ✅ **必须使用的配置文件**

#### 1. `conf/config.lua` ⭐ **核心配置**

**用途：** Lua 脚本的主配置文件，包含所有服务配置

**关键配置：**
```lua
-- 第 9 行：短链服务域名
domain = os.getenv("REDIRECT_DOMAIN") or "short.oxvxo.link",

-- 第 11 行：协议
protocol = os.getenv("REDIRECT_PROTOCOL") or "https",

-- 第 49 行：图床主服务器
tc_go_primary = {
    domain = os.getenv("TC_GO_PRIMARY_DOMAIN") or "img.oxvxo.link",
    protocol = os.getenv("TC_GO_PRIMARY_PROTOCOL") or "https",
},

-- 第 134-145 行：Redis 配置
_M.redis = {
    host = os.getenv("REDIS_HOST") or "127.0.0.1",
    port = tonumber(os.getenv("REDIS_PORT")) or 6379,
    password = os.getenv("REDIS_PASSWORD") or nil,
    database = tonumber(os.getenv("REDIS_DATABASE")) or 0,
}

-- 第 147-157 行：MySQL 配置
_M.mysql = {
    host = os.getenv("MYSQL_HOST") or "127.0.0.1",
    port = tonumber(os.getenv("MYSQL_PORT")) or 3306,
    database = os.getenv("MYSQL_DATABASE") or "short_links",
    user = os.getenv("MYSQL_USER") or "root",
    password = os.getenv("MYSQL_PASSWORD") or "",
}
```

**修改建议：** 
- ✅ 通过环境变量配置，无需直接修改此文件
- ✅ 在 `.env` 文件中设置所有配置项

---

#### 2. `conf/nginx.conf` ⭐ **OpenResty 主配置**

**用途：** OpenResty 的核心 Nginx 配置文件

**关键功能：**
- Lua 模块路径配置
- 共享内存字典（缓存、限流、统计）
- 日志格式定义
- 请求路由规则
- 健康检查端点
- Prometheus 监控端点

**是否需要修改：** ❌ **无需修改**
- 所有域名相关配置通过环境变量控制
- 路由逻辑与域名无关

---

#### 3. `conf/upstream.conf` ⚠️ **需要修改**

**用途：** 定义上游服务器（CDN、图床等）

**需要修改的地方：**

```nginx
# 图床服务器 - TC-GO 集成
upstream tc_go_imagebed {
    least_conn;
    keepalive 32;

    # ⚠️ 修改为你的图床地址
    server img.oxvxo.link:443 weight=5 max_fails=3 fail_timeout=30s;
}
```

**测试环境占位符说明：**
```nginx
# CDN 服务器组 - 北方电信
upstream cdn_north_telecom {
    # 如果不使用 CDN 分流，保持默认即可
    server www.example.com:80 weight=5 max_fails=3 fail_timeout=30s;
}
```

**修改建议：**
- ✅ 必须修改 `tc_go_imagebed` 指向实际的图床服务器
- ⭕ CDN 相关的 upstream 如果不用可以保持默认

---

### ❌ **不需要使用的配置文件**

#### 4. `conf/https.conf` ❌ **不需要（已废弃）**

**原因：** 
- SSL/TLS 已在外部 Nginx（`/etc/nginx/sites-available/short.oxvxo.link.conf`）配置
- OpenResty 容器只监听 HTTP（端口 8081）
- 外部 Nginx 处理 HTTPS → 代理到 OpenResty HTTP
- `nginx.conf` 中未引用此文件

**架构：**
```
用户 HTTPS 请求
    ↓
外部 Nginx (443) ← 处理 SSL/TLS
    ↓
OpenResty (8081) ← 处理短链逻辑（仅 HTTP）
    ↓
重定向到图床
```

**文件状态：**
- ✅ 已从 `docker-compose.yml` 和 `docker-compose.prod.yml` 中移除挂载
- ✅ 文件保留作为参考（如需容器内 HTTPS 可参考）
- ❌ 不会被加载或使用

---

## 🔧 环境变量配置（`.env.prod`）

### 核心配置项

```bash
# ==================== 短链服务配置 ====================
REDIRECT_DOMAIN=short.oxvxo.link          # 短链域名
REDIRECT_PROTOCOL=https                    # 协议
REDIRECT_PORT=8081                         # OpenResty HTTP 端口

# ==================== 图床服务配置 ====================
TC_GO_PRIMARY_DOMAIN=img.oxvxo.link       # 图床域名（重定向目标）
TC_GO_PRIMARY_PROTOCOL=https               # 图床协议

# ==================== 数据库配置 ====================
MYSQL_HOST=shortlink-mysql-prod
MYSQL_PORT=3306
MYSQL_DATABASE=short_links
MYSQL_USER=short_link
MYSQL_PASSWORD=your_secure_password        # ⚠️ 必须修改

REDIS_HOST=shortlink-redis-prod
REDIS_PORT=6379
REDIS_PASSWORD=your_secure_password        # ⚠️ 必须修改
REDIS_DB=1

# ==================== API 集成 ====================
API_KEY=your_api_key_minimum_32_chars      # ⚠️ 必须修改
```

---

## 📂 外部 Nginx 配置

### 文件位置
```
c:\Users\DXY\Documents\shortimg-AI\nginx\short.oxvxo.link.conf
```

### 部署步骤

1. **复制配置到服务器：**
```bash
sudo cp short.oxvxo.link.conf /etc/nginx/sites-available/
```

2. **创建软链接：**
```bash
sudo ln -s /etc/nginx/sites-available/short.oxvxo.link.conf /etc/nginx/sites-enabled/
```

3. **申请 SSL 证书：**
```bash
sudo certbot certonly --webroot -w /var/www/certbot \
  -d short.oxvxo.link \
  --email your-email@example.com \
  --agree-tos
```

4. **测试并重载 Nginx：**
```bash
sudo nginx -t
sudo nginx -s reload
```

---

## 🔄 配置文件关系图

```
.env.prod (环境变量)
    ↓
conf/config.lua (读取环境变量)
    ↓
conf/nginx.conf (引用 config.lua)
    ↓
conf/upstream.conf (上游服务器定义)
    ↓
OpenResty 容器 (端口 8081)
    ↓
外部 Nginx (short.oxvxo.link:443)
    ↓
用户访问
```

---

## ✅ 配置检查清单

### 部署前检查

- [ ] 修改 `.env.prod` → `.env`
- [ ] 设置 `REDIRECT_DOMAIN=short.oxvxo.link`
- [ ] 设置 `TC_GO_PRIMARY_DOMAIN=img.oxvxo.link`
- [ ] 修改所有密码（MySQL、Redis、API Key）
- [ ] 检查 `conf/upstream.conf` 中的 `tc_go_imagebed`
- [ ] 复制外部 Nginx 配置到 `/etc/nginx/sites-available/`
- [ ] 申请 SSL 证书
- [ ] 配置 DNS（short.oxvxo.link → 服务器 IP）

### 部署后验证

```bash
# 1. 检查容器状态
docker-compose -f docker-compose.prod.yml ps

# 2. 测试内部健康检查
curl http://localhost:8081/health

# 3. 测试外部 HTTPS 访问
curl https://short.oxvxo.link/health

# 4. 查看日志
docker-compose -f docker-compose.prod.yml logs -f openresty

# 5. 测试短链接重定向（需先创建短链接）
curl -I https://short.oxvxo.link/abc123
```

---

## 🎯 总结

### 必须使用的文件：
1. ✅ `conf/config.lua` - 核心配置（通过环境变量配置）
2. ✅ `conf/nginx.conf` - OpenResty 主配置（无需修改）
3. ✅ `conf/upstream.conf` - 上游服务器（需修改图床地址）

### 不需要的文件：
4. ❌ `conf/https.conf` - SSL 由外部 Nginx 处理（已废弃）

### 额外需要的文件：
5. ✅ `nginx/short.oxvxo.link.conf` - 外部 Nginx 反向代理配置
6. ✅ `.env` - 环境变量配置（从 `.env.prod` 复制）

### 域名变更总结：
- ✅ 已将所有配置从 `s.img.oxvxo.link` 改为 `short.oxvxo.link`
- ✅ 已重命名 Nginx 配置文件
- ✅ 已更新文档和环境变量模板

🚀 **现在可以使用 `short.oxvxo.link` 进行部署了！**
