# 多存储类型支持 - 更新说明

## 🎉 新功能

TC-GO 图床系统现已支持多种存储类型!

### 支持的存储类型

| 存储类型 | 代码 | 适用场景 | 需要依赖 |
|---------|------|---------|---------|
| 本地存储 | `local` | 开发/小型部署 | ❌ 无需安装 |
| 阿里云OSS | `oss` | 国内生产环境 | ✅ 需要安装 |
| 腾讯云COS | `cos` | 国内生产环境 | ✅ 需要安装 |
| 七牛云 | `qiniu` | 国内生产环境 | ✅ 需要安装 |
| S3/MinIO | `s3` | 国际/自建存储 | ✅ 需要安装 |

## 📁 新增文件

```
backend/
├── storage/
│   ├── storage.go    # 存储接口定义
│   ├── local.go      # 本地存储实现 ✅
│   ├── oss.go        # 阿里云OSS实现
│   ├── cos.go        # 腾讯云COS实现
│   ├── qiniu.go      # 七牛云实现
│   └── s3.go         # S3/MinIO实现
└── config/config.go  # 新增存储配置字段

文档/
├── STORAGE_GUIDE.md    # 完整使用指南
└── STORAGE_INSTALL.md  # 快速安装指南
```

## 🔧 配置更新

### .env 新增配置项

```env
# 存储类型选择
STORAGE_TYPE=local  # local, oss, cos, qiniu, s3

# 本地存储配置
STORAGE_LOCAL_PATH=./uploads
STORAGE_BASE_URL=/api/files

# 云存储配置 (按需配置)
# 详见 .env.example
```

### config.Config 新增字段

```go
type Config struct {
    // ... 其他字段
    
    // 存储配置
    StorageType      string
    StorageLocalPath string
    StorageBaseURL   string
    
    // OSS配置
    OSSEndpoint        string
    OSSAccessKeyID     string
    OSSAccessKeySecret string
    OSSBucket          string
    OSSBasePath        string
    
    // COS配置
    COSRegion    string
    COSSecretID  string
    COSSecretKey string
    COSBucket    string
    COSBasePath  string
    
    // 七牛云配置
    QiniuAccessKey string
    QiniuSecretKey string
    QiniuBucket    string
    QiniuDomain    string
    QiniuRegion    string
    QiniuBasePath  string
    
    // S3配置
    S3Endpoint        string
    S3AccessKeyID     string
    S3SecretAccessKey string
    S3Bucket          string
    S3Region          string
    S3BasePath        string
    S3UseSSL          bool
}
```

## 💡 使用方式

### 默认使用 (本地存储)

无需任何修改,系统默认使用本地存储:

```bash
cd backend
go run main.go
```

### 切换到云存储

1. **安装对应SDK** (仅首次需要):

```bash
# 例如使用阿里云OSS
go get github.com/aliyun/aliyun-oss-go-sdk
go mod tidy
```

2. **配置环境变量** (修改 `.env`):

```env
STORAGE_TYPE=oss
OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
OSS_ACCESS_KEY_ID=your_key
OSS_ACCESS_KEY_SECRET=your_secret
OSS_BUCKET=your-bucket
```

3. **重启服务**:

```bash
go run main.go
```

## 🎯 特性

### 统一接口

所有存储类型都实现了统一的 `Storage` 接口:

```go
type Storage interface {
    Save(path string, file *multipart.FileHeader) (string, error)
    SaveFromReader(path string, reader io.Reader, size int64) (string, error)
    Get(path string) (io.ReadCloser, error)
    Delete(path string) error
    Exists(path string) (bool, error)
    GetURL(path string) string
    GetType() StorageType
}
```

### 透明切换

对上层代码完全透明,无需修改控制器逻辑:

```go
// 使用统一API
stor := storage.GetStorage()
url, err := stor.Save("album_1/image.jpg", fileHeader)
```

### 灵活配置

支持环境变量配置,方便在不同环境使用不同存储:

- **开发环境:** 本地存储
- **测试环境:** MinIO
- **生产环境:** 阿里云OSS/腾讯云COS

## 📊 对比

| 特性 | 本地存储 | 云存储 (OSS/COS/七牛云) |
|------|---------|----------------------|
| 配置难度 | ⭐ 简单 | ⭐⭐⭐ 中等 |
| 成本 | 💰 免费 | 💰💰 按量付费 |
| 扩展性 | ❌ 受限 | ✅ 无限扩展 |
| CDN加速 | ❌ 不支持 | ✅ 支持 |
| 高可用 | ❌ 单点 | ✅ 99.99% |
| 带宽限制 | ⚠️ 服务器带宽 | ✅ 无限制 |

## 🔄 迁移指南

### 从本地存储迁移到云存储

1. **备份数据:**
   ```bash
   cp -r ./uploads ./uploads_backup
   ```

2. **配置云存储并重启服务**

3. **验证新上传的文件使用云存储**

4. **迁移历史文件:** (可选)
   - 编写迁移脚本上传历史文件到云存储
   - 更新数据库中的文件路径

### 从云存储切换到另一个云存储

1. **修改配置:**
   ```env
   # 从 OSS 切换到 COS
   STORAGE_TYPE=cos  # 原来是 oss
   COS_REGION=ap-guangzhou
   COS_SECRET_ID=...
   # ...其他COS配置
   ```

2. **重启服务**

3. **同步数据:** 使用云服务商提供的迁移工具

## ⚠️ 注意事项

1. **云存储SDK是可选依赖:**
   - 默认只包含本地存储,无需安装SDK
   - 使用云存储时才需要安装对应SDK

2. **配置安全:**
   - 不要将密钥提交到Git
   - `.env` 文件已加入 `.gitignore`
   - 生产环境使用密钥管理服务

3. **网络问题:**
   - 如遇SDK安装失败,设置GOPROXY:
     ```bash
     go env -w GOPROXY=https://goproxy.cn,direct
     ```

4. **成本控制:**
   - 云存储按流量/存储计费
   - 建议设置费用告警
   - 启用生命周期管理

## 📖 文档

- **完整使用指南:** `STORAGE_GUIDE.md`
- **快速安装:** `STORAGE_INSTALL.md`
- **配置示例:** `.env.example`

## 🚀 下一步

1. 选择合适的存储类型
2. 查看 `STORAGE_INSTALL.md` 快速开始
3. 参考 `STORAGE_GUIDE.md` 深入了解

## ❓ 常见问题

**Q: 本地存储可以继续使用吗?**  
A: 完全可以!本地存储是默认选项,无需任何修改。

**Q: 必须安装所有云存储SDK吗?**  
A: 不需要!只安装你要使用的存储类型对应的SDK。

**Q: 可以在不重启的情况下切换存储吗?**  
A: 当前版本需要重启服务。未来可能支持热切换。

**Q: 数据库需要迁移吗?**  
A: 不需要!存储层的改变不影响数据库结构。

---

**版本:** v2.0.0  
**更新时间:** 2025-12-04  
**作者:** TC-GO Team
