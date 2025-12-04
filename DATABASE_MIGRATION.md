# 数据库迁移指南

本文档介绍如何将 TC-GO 图床系统从 SQLite 迁移到 PostgreSQL 或 MySQL。

## 目录
- [PostgreSQL 迁移](#postgresql-迁移)
- [MySQL 迁移](#mysql-迁移)
- [数据导入导出](#数据导入导出)
- [性能优化建议](#性能优化建议)

---

## PostgreSQL 迁移

### 1. 安装 PostgreSQL
```bash
# Ubuntu/Debian
sudo apt-get install postgresql postgresql-contrib

# macOS (使用 Homebrew)
brew install postgresql

# Windows
# 下载安装包: https://www.postgresql.org/download/windows/
```

### 2. 创建数据库和用户
```sql
-- 连接到 PostgreSQL
psql -U postgres

-- 创建数据库
CREATE DATABASE imagebed;

-- 创建用户(可选)
CREATE USER imagebed_user WITH PASSWORD 'your_password';

-- 授予权限
GRANT ALL PRIVILEGES ON DATABASE imagebed TO imagebed_user;

-- 退出
\q
```

### 3. 配置环境变量
在 `.env` 文件中设置:
```bash
DB_TYPE=postgres
DB_DSN=host=localhost port=5432 user=imagebed_user password=your_password dbname=imagebed sslmode=disable
```

### 4. 启动应用
```bash
cd backend
go run main.go
```

GORM 会自动创建所有表结构。

---

## MySQL 迁移

### 1. 安装 MySQL
```bash
# Ubuntu/Debian
sudo apt-get install mysql-server

# macOS (使用 Homebrew)
brew install mysql

# Windows
# 下载安装包: https://dev.mysql.com/downloads/mysql/
```

### 2. 创建数据库和用户
```sql
-- 连接到 MySQL
mysql -u root -p

-- 创建数据库
CREATE DATABASE imagebed CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建用户(可选)
CREATE USER 'imagebed_user'@'localhost' IDENTIFIED BY 'your_password';

-- 授予权限
GRANT ALL PRIVILEGES ON imagebed.* TO 'imagebed_user'@'localhost';

-- 刷新权限
FLUSH PRIVILEGES;

-- 退出
EXIT;
```

### 3. 配置环境变量
在 `.env` 文件中设置:
```bash
DB_TYPE=mysql
DB_DSN=imagebed_user:your_password@tcp(localhost:3306)/imagebed?charset=utf8mb4&parseTime=True&loc=Local
```

### 4. 启动应用
```bash
cd backend
go run main.go
```

---

## 数据导入导出

### 从 SQLite 导出数据

#### 方法 1: 使用 sqlite3 命令
```bash
# 导出为 SQL 文件
sqlite3 ./data/imagebed.db .dump > imagebed_backup.sql

# 只导出数据(不含建表语句)
sqlite3 ./data/imagebed.db <<EOF
.mode insert
.out imagebed_data.sql
SELECT * FROM users;
SELECT * FROM albums;
SELECT * FROM images;
SELECT * FROM statistics;
SELECT * FROM operation_logs;
SELECT * FROM system_logs;
.quit
EOF
```

#### 方法 2: 使用 Go 脚本导出
```go
// 创建 backend/cmd/export_data/main.go
package main

import (
	"encoding/json"
	"fmt"
	"imagebed/database"
	"imagebed/models"
	"os"
)

func main() {
	// 连接 SQLite 数据库
	database.InitDatabase("./data/imagebed.db")
	
	// 导出用户
	var users []models.User
	database.DB.Find(&users)
	saveJSON("users.json", users)
	
	// 导出相册
	var albums []models.Album
	database.DB.Find(&albums)
	saveJSON("albums.json", albums)
	
	// 导出图片
	var images []models.Image
	database.DB.Find(&images)
	saveJSON("images.json", images)
	
	fmt.Println("数据导出完成!")
}

func saveJSON(filename string, data interface{}) {
	file, _ := os.Create(filename)
	defer file.Close()
	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	encoder.Encode(data)
}
```

### 导入数据到 PostgreSQL/MySQL

#### 方法 1: 使用应用自动迁移
应用启动时会自动创建表结构,然后手动导入数据:

```go
// 创建 backend/cmd/import_data/main.go
package main

import (
	"encoding/json"
	"imagebed/database"
	"imagebed/models"
	"os"
)

func main() {
	// 连接目标数据库(通过环境变量配置)
	database.InitDatabase()
	
	// 导入用户
	var users []models.User
	loadJSON("users.json", &users)
	for _, user := range users {
		database.DB.Create(&user)
	}
	
	// 导入相册
	var albums []models.Album
	loadJSON("albums.json", &albums)
	for _, album := range albums {
		database.DB.Create(&album)
	}
	
	// 导入图片
	var images []models.Image
	loadJSON("images.json", &images)
	for _, image := range images {
		database.DB.Create(&image)
	}
}

func loadJSON(filename string, v interface{}) {
	file, _ := os.Open(filename)
	defer file.Close()
	json.NewDecoder(file).Decode(v)
}
```

#### 方法 2: 使用数据库工具
对于 PostgreSQL:
```bash
psql -U imagebed_user -d imagebed < imagebed_backup.sql
```

对于 MySQL:
```bash
mysql -u imagebed_user -p imagebed < imagebed_backup.sql
```

---

## 性能优化建议

### 1. 数据库索引
系统已自动创建以下索引:
- `idx_albums_owner_id` - 相册所有者查询
- `idx_albums_is_private` - 相册隐私过滤
- `idx_images_owner_id` - 图片所有者查询
- `idx_images_is_private` - 图片隐私过滤
- `idx_images_album_id` - 相册图片关联

### 2. 启用 Redis 缓存
强烈建议在生产环境启用 Redis:
```bash
# .env
REDIS_ENABLED=true
REDIS_ADDR=localhost:6379
CACHE_TTL=10m
```

### 3. PostgreSQL 优化
```sql
-- 调整 PostgreSQL 配置(/etc/postgresql/xx/main/postgresql.conf)
shared_buffers = 256MB          # 共享缓冲区
effective_cache_size = 1GB      # 有效缓存大小
work_mem = 16MB                 # 工作内存
maintenance_work_mem = 128MB    # 维护内存

-- 重启服务
sudo systemctl restart postgresql
```

### 4. MySQL 优化
```sql
-- 调整 MySQL 配置(/etc/mysql/my.cnf)
[mysqld]
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
max_connections = 200
query_cache_size = 64M
```

### 5. 连接池配置
在 `database/database.go` 中添加:
```go
sqlDB, err := DB.DB()
if err == nil {
    sqlDB.SetMaxIdleConns(10)           // 最大空闲连接数
    sqlDB.SetMaxOpenConns(100)          // 最大打开连接数
    sqlDB.SetConnMaxLifetime(time.Hour) // 连接最大生命周期
}
```

---

## 故障排查

### 问题 1: PostgreSQL 连接被拒绝
```bash
# 检查服务状态
sudo systemctl status postgresql

# 启动服务
sudo systemctl start postgresql

# 检查监听端口
sudo netstat -plnt | grep 5432
```

### 问题 2: MySQL 认证失败
```sql
-- MySQL 8.0+ 需要修改认证方式
ALTER USER 'imagebed_user'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your_password';
FLUSH PRIVILEGES;
```

### 问题 3: 字符编码问题
确保数据库使用 UTF-8:
- PostgreSQL: 创建数据库时指定 `ENCODING 'UTF8'`
- MySQL: 使用 `CHARACTER SET utf8mb4`

---

## 回滚到 SQLite
如果遇到问题,可以随时回滚:
```bash
# .env
DB_TYPE=sqlite
DB_DSN=./data/imagebed.db
```

重启应用即可。

---

## 备份策略

### PostgreSQL 自动备份
```bash
# 创建备份脚本 backup.sh
#!/bin/bash
pg_dump -U imagebed_user imagebed > backup_$(date +%Y%m%d).sql

# 添加到 crontab (每天凌晨2点)
0 2 * * * /path/to/backup.sh
```

### MySQL 自动备份
```bash
# 创建备份脚本 backup.sh
#!/bin/bash
mysqldump -u imagebed_user -p'your_password' imagebed > backup_$(date +%Y%m%d).sql

# 添加到 crontab
0 2 * * * /path/to/backup.sh
```

---

## 需要帮助?
如果在迁移过程中遇到问题,请检查:
1. 数据库服务是否运行
2. 连接字符串是否正确
3. 用户权限是否足够
4. 防火墙是否允许连接
5. 查看应用日志: `./logs/app.log`
