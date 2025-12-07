package storage

import (
	"io"
	"mime/multipart"
	"strconv"
)

// StorageType 存储类型
type StorageType string

const (
	StorageTypeLocal  StorageType = "local"  // 本地存储
	StorageTypeOSS    StorageType = "oss"    // 阿里云 OSS
	StorageTypeCOS    StorageType = "cos"    // 腾讯云 COS
	StorageTypeQiniu  StorageType = "qiniu"  // 七牛云
	StorageTypeS3     StorageType = "s3"     // AWS S3 / MinIO
	StorageTypeWebDAV StorageType = "webdav" // WebDAV
	StorageTypeSFTP   StorageType = "sftp"   // SFTP
)

// Storage 存储接口
type Storage interface {
	// Save 保存文件
	// path: 存储路径(相对路径)
	// file: 上传的文件
	// 返回: 访问URL, 错误
	Save(path string, file *multipart.FileHeader) (string, error)

	// SaveFromReader 从Reader保存文件
	SaveFromReader(path string, reader io.Reader, size int64) (string, error)

	// Get 获取文件
	// path: 存储路径
	// 返回: 文件内容, 错误
	Get(path string) (io.ReadCloser, error)

	// Delete 删除文件
	Delete(path string) error

	// Exists 检查文件是否存在
	Exists(path string) (bool, error)

	// GetURL 获取访问URL
	// path: 存储路径
	// 返回: 可访问的URL
	GetURL(path string) string

	// GetType 获取存储类型
	GetType() StorageType
}

// Config 存储配置
type Config struct {
	Type StorageType `json:"type"`

	// 本地存储配置
	LocalPath string `json:"localPath"`
	BaseURL   string `json:"baseUrl"` // 本地存储的基础URL

	// OSS配置
	OSSEndpoint        string `json:"ossEndpoint"`
	OSSAccessKeyID     string `json:"ossAccessKeyId"`
	OSSAccessKeySecret string `json:"ossAccessKeySecret"`
	OSSBucket          string `json:"ossBucket"`
	OSSBasePath        string `json:"ossBasePath"` // OSS内的基础路径

	// COS配置
	COSRegion    string `json:"cosRegion"`
	COSSecretID  string `json:"cosSecretId"`
	COSSecretKey string `json:"cosSecretKey"`
	COSBucket    string `json:"cosBucket"`
	COSBasePath  string `json:"cosBasePath"`

	// 七牛云配置
	QiniuAccessKey string `json:"qiniuAccessKey"`
	QiniuSecretKey string `json:"qiniuSecretKey"`
	QiniuBucket    string `json:"qiniuBucket"`
	QiniuDomain    string `json:"qiniuDomain"` // 七牛云绑定的域名
	QiniuRegion    string `json:"qiniuRegion"` // 存储区域
	QiniuBasePath  string `json:"qiniuBasePath"`

	// S3配置 (支持AWS S3, MinIO等)
	S3Endpoint        string `json:"s3Endpoint"`
	S3AccessKeyID     string `json:"s3AccessKeyId"`
	S3SecretAccessKey string `json:"s3SecretAccessKey"`
	S3Bucket          string `json:"s3Bucket"`
	S3Region          string `json:"s3Region"`
	S3BasePath        string `json:"s3BasePath"`
	S3UseSSL          bool   `json:"s3UseSSL"` // 是否使用HTTPS

	// WebDAV配置
	WebDAVURL      string `json:"webdavUrl"`      // WebDAV服务器地址
	WebDAVUsername string `json:"webdavUsername"` // 用户名
	WebDAVPassword string `json:"webdavPassword"` // 密码
	WebDAVBasePath string `json:"webdavBasePath"` // 服务器上的基础路径
	WebDAVBaseURL  string `json:"webdavBaseUrl"`  // 访问基础URL

	// SFTP配置
	SFTPHost       string `json:"sftpHost"`       // SFTP服务器地址
	SFTPPort       int    `json:"sftpPort"`       // 端口(默认22)
	SFTPUsername   string `json:"sftpUsername"`   // 用户名
	SFTPPassword   string `json:"sftpPassword"`   // 密码
	SFTPPrivateKey string `json:"sftpPrivateKey"` // 私钥路径
	SFTPBasePath   string `json:"sftpBasePath"`   // 服务器上的基础路径
	SFTPBaseURL    string `json:"sftpBaseUrl"`    // 访问基础URL
}

var globalStorage Storage

// InitStorage 初始化存储
func InitStorage(cfg *Config) error {
	var err error

	switch cfg.Type {
	case StorageTypeLocal:
		globalStorage, err = NewLocalStorage(cfg)
	case StorageTypeOSS:
		globalStorage, err = NewOSSStorage(cfg)
	case StorageTypeCOS:
		globalStorage, err = NewCOSStorage(cfg)
	case StorageTypeQiniu:
		globalStorage, err = NewQiniuStorage(cfg)
	case StorageTypeS3:
		globalStorage, err = NewS3Storage(cfg)
	case StorageTypeWebDAV:
		globalStorage, err = NewWebDAVStorage(cfg)
	case StorageTypeSFTP:
		globalStorage, err = NewSFTPStorage(cfg)
	default:
		// 默认使用本地存储
		globalStorage, err = NewLocalStorage(cfg)
	}

	return err
}

// InitStorageFromMap 从map初始化存储(用于避免循环依赖)
func InitStorageFromMap(configMap map[string]interface{}) error {
	cfg := &Config{
		Type:               StorageType(getStringFromMap(configMap, "Type", "local")),
		LocalPath:          getStringFromMap(configMap, "LocalPath", "./uploads"),
		BaseURL:            getStringFromMap(configMap, "BaseURL", "/api/files"),
		OSSEndpoint:        getStringFromMap(configMap, "OSSEndpoint", ""),
		OSSAccessKeyID:     getStringFromMap(configMap, "OSSAccessKeyID", ""),
		OSSAccessKeySecret: getStringFromMap(configMap, "OSSAccessKeySecret", ""),
		OSSBucket:          getStringFromMap(configMap, "OSSBucket", ""),
		OSSBasePath:        getStringFromMap(configMap, "OSSBasePath", ""),
		COSRegion:          getStringFromMap(configMap, "COSRegion", ""),
		COSSecretID:        getStringFromMap(configMap, "COSSecretID", ""),
		COSSecretKey:       getStringFromMap(configMap, "COSSecretKey", ""),
		COSBucket:          getStringFromMap(configMap, "COSBucket", ""),
		COSBasePath:        getStringFromMap(configMap, "COSBasePath", ""),
		QiniuAccessKey:     getStringFromMap(configMap, "QiniuAccessKey", ""),
		QiniuSecretKey:     getStringFromMap(configMap, "QiniuSecretKey", ""),
		QiniuBucket:        getStringFromMap(configMap, "QiniuBucket", ""),
		QiniuDomain:        getStringFromMap(configMap, "QiniuDomain", ""),
		QiniuRegion:        getStringFromMap(configMap, "QiniuRegion", ""),
		QiniuBasePath:      getStringFromMap(configMap, "QiniuBasePath", ""),
		S3Endpoint:         getStringFromMap(configMap, "S3Endpoint", ""),
		S3AccessKeyID:      getStringFromMap(configMap, "S3AccessKeyID", ""),
		S3SecretAccessKey:  getStringFromMap(configMap, "S3SecretAccessKey", ""),
		S3Bucket:           getStringFromMap(configMap, "S3Bucket", ""),
		S3Region:           getStringFromMap(configMap, "S3Region", ""),
		S3BasePath:         getStringFromMap(configMap, "S3BasePath", ""),
		S3UseSSL:           getBoolFromMap(configMap, "S3UseSSL", true),
		WebDAVURL:          getStringFromMap(configMap, "WebDAVURL", ""),
		WebDAVUsername:     getStringFromMap(configMap, "WebDAVUsername", ""),
		WebDAVPassword:     getStringFromMap(configMap, "WebDAVPassword", ""),
		WebDAVBasePath:     getStringFromMap(configMap, "WebDAVBasePath", ""),
		WebDAVBaseURL:      getStringFromMap(configMap, "WebDAVBaseURL", ""),
		SFTPHost:           getStringFromMap(configMap, "SFTPHost", ""),
		SFTPPort:           getIntFromMap(configMap, "SFTPPort", 22),
		SFTPUsername:       getStringFromMap(configMap, "SFTPUsername", ""),
		SFTPPassword:       getStringFromMap(configMap, "SFTPPassword", ""),
		SFTPPrivateKey:     getStringFromMap(configMap, "SFTPPrivateKey", ""),
		SFTPBasePath:       getStringFromMap(configMap, "SFTPBasePath", ""),
		SFTPBaseURL:        getStringFromMap(configMap, "SFTPBaseURL", ""),
	}

	return InitStorage(cfg)
}

// GetStorage 获取存储实例
func GetStorage() Storage {
	return globalStorage
}

// 辅助函数
func getStringFromMap(m map[string]interface{}, key string, defaultValue string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return defaultValue
}

func getBoolFromMap(m map[string]interface{}, key string, defaultValue bool) bool {
	if v, ok := m[key]; ok {
		if b, ok := v.(bool); ok {
			return b
		}
	}
	return defaultValue
}

func getIntFromMap(m map[string]interface{}, key string, defaultValue int) int {
	if v, ok := m[key]; ok {
		// 尝试多种类型转换
		switch val := v.(type) {
		case int:
			return val
		case int64:
			return int(val)
		case float64:
			return int(val)
		case string:
			// 尝试解析字符串
			if i, err := strconv.Atoi(val); err == nil {
				return i
			}
		}
	}
	return defaultValue
}
