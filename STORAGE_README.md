# 多存储类型支持 🚀

TC-GO 图床系统现已支持**5种存储类型**!

## 快速开始

### ⚡ 本地存储 (默认,开箱即用)

```bash
cd backend
go run main.go
```

就这么简单!无需任何配置。

### ☁️ 云存储 (可选)

如果需要使用云存储,请查看:

📖 **[快速安装指南](./STORAGE_INSTALL.md)** - 5分钟上手  
📚 **[完整使用手册](./STORAGE_GUIDE.md)** - 详细文档  
📝 **[更新说明](./STORAGE_UPDATE.md)** - 架构设计

## 支持的存储

| 存储 | 代码 | 适合 | SDK |
|------|------|------|-----|
| 本地存储 | `local` | 开发/小型 | ❌ 无需 |
| 阿里云OSS | `oss` | 国内生产 | ✅ 需要 |
| 腾讯云COS | `cos` | 国内生产 | ✅ 需要 |
| 七牛云 | `qiniu` | 国内生产 | ✅ 需要 |
| S3/MinIO | `s3` | 国际/自建 | ✅ 需要 |

## 配置示例

### 本地存储
```env
STORAGE_TYPE=local
```

### 阿里云OSS
```env
STORAGE_TYPE=oss
OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
OSS_ACCESS_KEY_ID=your_key
OSS_ACCESS_KEY_SECRET=your_secret
OSS_BUCKET=your-bucket
```

更多配置示例: [`.env.example`](./backend/.env.example)

## 特性

✅ **统一接口** - 所有存储类型使用相同API  
✅ **零配置启动** - 本地存储开箱即用  
✅ **按需安装** - 只安装需要的SDK  
✅ **一键切换** - 修改配置即可切换存储  
✅ **安全可靠** - 路径检查,配置验证  

## 文档

- 📖 [快速安装](./STORAGE_INSTALL.md) - 5分钟上手
- 📚 [使用指南](./STORAGE_GUIDE.md) - 完整文档
- 📝 [更新说明](./STORAGE_UPDATE.md) - 架构设计
- ✅ [实现完成](./STORAGE_COMPLETE.md) - 技术细节

## 常见问题

**Q: 必须安装云存储SDK吗?**  
A: 不需要!默认使用本地存储,无需安装任何SDK。

**Q: 如何切换到云存储?**  
A: 安装对应SDK,修改`.env`配置,重启服务即可。

**Q: 已有文件如何迁移?**  
A: 详见 [STORAGE_GUIDE.md](./STORAGE_GUIDE.md) 的迁移指南。

## 下一步

1. 🎯 默认使用本地存储,无需操作
2. 📖 需要云存储?查看 [STORAGE_INSTALL.md](./STORAGE_INSTALL.md)
3. 🚀 开始使用: `cd backend && go run main.go`

祝使用愉快! 🎉
