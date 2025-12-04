# 多存储类型支持文档

## 概述

TC-GO 图床系统现已支持多种存储类型,包括:

1. **本地存储** (local) - 默认,无需额外配置
2. **阿里云 OSS** (oss) - 适合国内用户
3. **腾讯云 COS** (cos) - 适合国内用户  
4. **七牛云** (qiniu) - 适合国内用户
5. **S3/MinIO** (s3) - 适合国际用户或自建对象存储

## 架构设计

### 存储接口

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

### 目录结构

```
backend/
└── storage/
    ├── storage.go    # 存储接口和初始化
    ├── local.go      # 本地存储实现
    ├── oss.go        # 阿里云OSS实现
    ├── cos.go        # 腾讯云COS实现
    ├── qiniu.go      # 七牛云实现
    └── s3.go         # S3/MinIO实现
```

## 使用方法

### 1. 本地存储 (默认)

本地存储无需安装额外依赖,开箱即用。

**.env 配置:**

```env
STORAGE_TYPE=local
STORAGE_LOCAL_PATH=./uploads
STORAGE_BASE_URL=/api/files
```

**特点:**
- ✅ 无需额外费用
- ✅ 配置简单
- ❌ 扩展性受限
- ❌ 不支持CDN加速

### 2. 阿里云 OSS

**.env 配置:**

```env
STORAGE_TYPE=oss
OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
OSS_ACCESS_KEY_ID=your_access_key_id
OSS_ACCESS_KEY_SECRET=your_access_key_secret
OSS_BUCKET=your-bucket-name
OSS_BASE_PATH=images
```

**安装依赖:**

```bash
go get github.com/aliyun/aliyun-oss-go-sdk
```

**然后在 go.mod 中取消注释对应行:**

```go
require (
    // ...其他依赖
    github.com/aliyun/aliyun-oss-go-sdk v3.0.2+incompatible
)
```

**特点:**
- ✅ 国内访问速度快
- ✅ 支持CDN加速
- ✅ 高可用性
- ❌ 需要付费

### 3. 腾讯云 COS

**.env 配置:**

```env
STORAGE_TYPE=cos
COS_REGION=ap-guangzhou
COS_SECRET_ID=your_secret_id
COS_SECRET_KEY=your_secret_key
COS_BUCKET=your-bucket-appid
COS_BASE_PATH=images
```

**安装依赖:**

```bash
go get github.com/tencentyun/cos-go-sdk-v5
```

**特点:**
- ✅ 与腾讯云生态集成好
- ✅ 支持CDN加速
- ✅ 价格相对较低
- ❌ 需要付费

### 4. 七牛云

**.env 配置:**

```env
STORAGE_TYPE=qiniu
QINIU_ACCESS_KEY=your_access_key
QINIU_SECRET_KEY=your_secret_key
QINIU_BUCKET=your-bucket-name
QINIU_DOMAIN=https://cdn.example.com
QINIU_REGION=z0
QINIU_BASE_PATH=images
```

**区域代码:**
- `z0` 或 `huadong` - 华东
- `z1` 或 `huabei` - 华北
- `z2` 或 `huanan` - 华南
- `na0` 或 `beimei` - 北美
- `as0` 或 `xinjiapo` - 新加坡

**安装依赖:**

```bash
go get github.com/qiniu/go-sdk/v7
```

**特点:**
- ✅ CDN加速效果好
- ✅ 有免费额度
- ✅ 国内访问速度快
- ❌ 需要绑定域名

### 5. S3 / MinIO

**.env 配置:**

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

**MinIO 配置示例:**

```env
STORAGE_TYPE=s3
S3_ENDPOINT=minio.example.com:9000
S3_ACCESS_KEY_ID=minioadmin
S3_SECRET_ACCESS_KEY=minioadmin
S3_BUCKET=imagebed
S3_REGION=
S3_BASE_PATH=
S3_USE_SSL=false
```

**安装依赖:**

```bash
go get github.com/minio/minio-go/v7
```

**特点:**
- ✅ 兼容AWS S3和MinIO
- ✅ 可自建私有云存储
- ✅ 国际化支持好
- ❌ 国内访问AWS S3较慢

## 配置验证

系统启动时会自动验证存储配置是否正确:

```
2025/12/04 10:00:00 存储系统初始化成功 {"type": "local"}
```

如果配置错误,会输出错误信息:

```
2025/12/04 10:00:00 存储系统初始化失败: OSS配置不完整
```

## 切换存储类型

### 运行时切换

修改 `.env` 文件中的 `STORAGE_TYPE` 和对应配置,重启服务即可。

### 数据迁移

如果需要从一种存储类型迁移到另一种:

1. **保留旧数据:** 暂时不要删除旧存储中的文件
2. **切换配置:** 修改 `.env` 配置并重启
3. **数据迁移:** 可以编写脚本将旧存储的文件上传到新存储
4. **更新数据库:** 更新数据库中的文件URL(如果需要)

## API 使用

存储层对上层代码透明,控制器中使用统一的API:

```go
import "imagebed/storage"

// 获取存储实例
stor := storage.GetStorage()

// 保存文件
url, err := stor.Save("album_1/image.jpg", fileHeader)

// 获取文件
reader, err := stor.Get("album_1/image.jpg")

// 删除文件
err := stor.Delete("album_1/image.jpg")

// 检查文件是否存在
exists, err := stor.Exists("album_1/image.jpg")

// 获取访问URL
url := stor.GetURL("album_1/image.jpg")
```

## 安全建议

1. **密钥安全:**
   - 不要将密钥提交到版本控制系统
   - 使用 `.env` 文件并加入 `.gitignore`
   - 生产环境使用密钥管理服务

2. **访问控制:**
   - 配置Bucket访问策略
   - 启用防盗链
   - 设置合理的CORS策略

3. **成本控制:**
   - 设置流量限制
   - 启用生命周期管理
   - 监控存储使用量

## 故障排查

### 1. 云存储SDK导入失败

**错误:**
```
could not import github.com/aliyun/aliyun-oss-go-sdk/oss
```

**解决:**
```bash
# 安装对应的SDK
go get github.com/aliyun/aliyun-oss-go-sdk

# 更新依赖
go mod tidy
```

### 2. 配置不完整

**错误:**
```
存储系统初始化失败: OSS配置不完整
```

**解决:** 检查 `.env` 文件,确保所有必需的配置项都已填写。

### 3. 网络连接失败

**错误:**
```
上传到OSS失败: RequestTimeout
```

**解决:**
- 检查网络连接
- 检查Endpoint是否正确
- 检查防火墙设置

### 4. 权限错误

**错误:**
```
上传到S3失败: AccessDenied
```

**解决:**
- 检查Access Key和Secret Key是否正确
- 检查Bucket策略是否允许上传
- 检查IAM权限配置

## 性能优化

1. **启用CDN:** 所有云存储都支持CDN加速
2. **压缩传输:** 启用gzip压缩
3. **并发上传:** 使用分片上传处理大文件
4. **缓存策略:** 设置合理的Cache-Control头

## 未来扩展

系统架构支持轻松添加新的存储类型:

1. 创建新的存储实现文件 (如 `storage/azure.go`)
2. 实现 `Storage` 接口
3. 在 `storage.go` 中添加初始化逻辑
4. 在 `config.go` 中添加配置项

欢迎贡献更多存储类型的实现!

## 参考链接

- [阿里云OSS文档](https://help.aliyun.com/product/31815.html)
- [腾讯云COS文档](https://cloud.tencent.com/document/product/436)
- [七牛云对象存储文档](https://developer.qiniu.com/kodo)
- [AWS S3文档](https://docs.aws.amazon.com/s3/)
- [MinIO文档](https://min.io/docs/minio/linux/index.html)
