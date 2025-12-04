# 多存储支持 - 安装指南

## 快速开始

默认情况下,系统使用**本地存储**,无需安装额外依赖。

如果需要使用云存储,请按照以下步骤操作:

## 安装云存储SDK

### Windows (PowerShell)

```powershell
cd backend

# 根据需要选择安装 (可多选)

# 阿里云 OSS
go get github.com/aliyun/aliyun-oss-go-sdk

# 腾讯云 COS
go get github.com/tencentyun/cos-go-sdk-v5

# 七牛云
go get github.com/qiniu/go-sdk/v7

# S3/MinIO
go get github.com/minio/minio-go/v7

# 更新依赖
go mod tidy
```

### Linux/macOS

```bash
cd backend

# 根据需要选择安装 (可多选)

# 阿里云 OSS
go get github.com/aliyun/aliyun-oss-go-sdk

# 腾讯云 COS  
go get github.com/tencentyun/cos-go-sdk-v5

# 七牛云
go get github.com/qiniu/go-sdk/v7

# S3/MinIO
go get github.com/minio/minio-go/v7

# 更新依赖
go mod tidy
```

## 配置说明

### 1. 本地存储 (默认)

无需额外配置,开箱即用。

```env
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=./uploads
STORAGE_BASE_URL=/api/files
```

### 2. 阿里云 OSS

```env
STORAGE_TYPE=oss
OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
OSS_ACCESS_KEY_ID=your_access_key_id
OSS_ACCESS_KEY_SECRET=your_access_key_secret
OSS_BUCKET=your-bucket-name
OSS_BASE_PATH=images
```

**获取密钥:** [阿里云控制台](https://ram.console.aliyun.com/manage/ak)

### 3. 腾讯云 COS

```env
STORAGE_TYPE=cos
COS_REGION=ap-guangzhou
COS_SECRET_ID=your_secret_id
COS_SECRET_KEY=your_secret_key
COS_BUCKET=your-bucket-appid
COS_BASE_PATH=images
```

**获取密钥:** [腾讯云控制台](https://console.cloud.tencent.com/cam/capi)

### 4. 七牛云

```env
STORAGE_TYPE=qiniu
QINIU_ACCESS_KEY=your_access_key
QINIU_SECRET_KEY=your_secret_key
QINIU_BUCKET=your-bucket-name
QINIU_DOMAIN=https://cdn.example.com
QINIU_REGION=z0
QINIU_BASE_PATH=images
```

**获取密钥:** [七牛云控制台](https://portal.qiniu.com/user/key)

### 5. S3/MinIO

```env
STORAGE_TYPE=s3
S3_ENDPOINT=s3.amazonaws.com
S3_ACCESS_KEY_ID=your_access_key_id
S3_SECRET_ACCESS_KEY=your_secret_access_key
S3_BUCKET=your-bucket-name
S3_REGION=us-east-1
S3_BASE_PATH=images
S3_USE_SSL=true
```

**自建MinIO示例:**

```env
STORAGE_TYPE=s3
S3_ENDPOINT=localhost:9000
S3_ACCESS_KEY_ID=minioadmin
S3_SECRET_ACCESS_KEY=minioadmin
S3_BUCKET=imagebed
S3_REGION=
S3_USE_SSL=false
```

## 启动服务

```bash
cd backend
go run main.go
```

启动成功后会显示:

```
存储系统初始化成功 {"type": "local"}
```

## 验证配置

启动日志中会显示存储类型:

```
2025/12/04 10:00:00 配置已加载: DB=sqlite, Redis=false, Mode=debug
2025/12/04 10:00:00 数据库初始化成功
2025/12/04 10:00:00 存储系统初始化成功 {"type": "local"}
2025/12/04 10:00:00 服务器启动 {"addr": "http://localhost:8080"}
```

## 常见问题

### Q: 网络问题导致SDK安装失败?

**A:** 使用国内镜像:

```bash
# 设置GOPROXY
go env -w GOPROXY=https://goproxy.cn,direct

# 然后重新安装
go get github.com/aliyun/aliyun-oss-go-sdk
```

### Q: 如何切换存储类型?

**A:** 修改 `.env` 文件中的 `STORAGE_TYPE` 和对应配置,重启服务即可。

### Q: 可以同时使用多种存储吗?

**A:** 当前版本只支持单一存储类型。如需多存储支持,可以通过负载均衡或反向代理实现。

### Q: 已有图片如何迁移到云存储?

**A:** 
1. 备份数据库
2. 将本地文件上传到云存储
3. 更新配置并重启
4. 如有需要,更新数据库中的URL字段

## 性能建议

1. **生产环境推荐使用云存储** (OSS/COS/七牛云)
2. **启用CDN加速** 提升访问速度
3. **启用Redis缓存** 减少数据库查询
4. **使用PostgreSQL/MySQL** 替代SQLite

## 技术支持

- 完整文档: `STORAGE_GUIDE.md`
- 环境变量示例: `.env.example`
- Issues: 如遇问题请提交Issue

## 下一步

1. 根据需求选择存储类型
2. 安装对应的SDK依赖
3. 配置环境变量
4. 重启服务验证

祝使用愉快! 🎉
