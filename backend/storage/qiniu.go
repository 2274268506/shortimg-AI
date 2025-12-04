package storage

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"strings"

	"github.com/qiniu/go-sdk/v7/auth/qbox"
	"github.com/qiniu/go-sdk/v7/storage"
)

// QiniuStorage 七牛云存储实现
type QiniuStorage struct {
	mac      *qbox.Mac
	bucket   string
	domain   string
	basePath string
	region   *storage.Region
}

// NewQiniuStorage 创建七牛云存储实例
func NewQiniuStorage(cfg *Config) (*QiniuStorage, error) {
	if cfg.QiniuAccessKey == "" || cfg.QiniuSecretKey == "" ||
		cfg.QiniuBucket == "" || cfg.QiniuDomain == "" {
		return nil, fmt.Errorf("七牛云配置不完整")
	}

	mac := qbox.NewMac(cfg.QiniuAccessKey, cfg.QiniuSecretKey)

	// 解析区域
	var region *storage.Region
	switch cfg.QiniuRegion {
	case "z0", "huadong":
		region = &storage.ZoneHuadong
	case "z1", "huabei":
		region = &storage.ZoneHuabei
	case "z2", "huanan":
		region = &storage.ZoneHuanan
	case "na0", "beimei":
		region = &storage.ZoneBeimei
	case "as0", "xinjiapo":
		region = &storage.ZoneXinjiapo
	default:
		region = &storage.ZoneHuadong // 默认华东
	}

	return &QiniuStorage{
		mac:      mac,
		bucket:   cfg.QiniuBucket,
		domain:   strings.TrimRight(cfg.QiniuDomain, "/"),
		basePath: strings.Trim(cfg.QiniuBasePath, "/"),
		region:   region,
	}, nil
}

// Save 保存文件
func (s *QiniuStorage) Save(path string, file *multipart.FileHeader) (string, error) {
	src, err := file.Open()
	if err != nil {
		return "", fmt.Errorf("打开上传文件失败: %w", err)
	}
	defer src.Close()

	// 读取文件内容
	buf := new(bytes.Buffer)
	size, err := io.Copy(buf, src)
	if err != nil {
		return "", fmt.Errorf("读取文件失败: %w", err)
	}

	return s.SaveFromReader(path, buf, size)
}

// SaveFromReader 从Reader保存文件
func (s *QiniuStorage) SaveFromReader(path string, reader io.Reader, size int64) (string, error) {
	objectKey := s.getObjectKey(path)

	putPolicy := storage.PutPolicy{
		Scope: s.bucket,
	}
	upToken := putPolicy.UploadToken(s.mac)

	cfg := storage.Config{
		Zone:          s.region,
		UseCdnDomains: false,
		UseHTTPS:      true,
	}

	formUploader := storage.NewFormUploader(&cfg)
	ret := storage.PutRet{}

	err := formUploader.Put(context.Background(), &ret, upToken, objectKey, reader, size, nil)
	if err != nil {
		return "", fmt.Errorf("上传到七牛云失败: %w", err)
	}

	return s.GetURL(path), nil
}

// Get 获取文件
func (s *QiniuStorage) Get(path string) (io.ReadCloser, error) {
	// 七牛云通过CDN直接访问,这里返回错误提示使用GetURL
	return nil, fmt.Errorf("七牛云存储请使用GetURL获取访问链接")
}

// Delete 删除文件
func (s *QiniuStorage) Delete(path string) error {
	objectKey := s.getObjectKey(path)

	cfg := storage.Config{
		Zone: s.region,
	}

	bucketManager := storage.NewBucketManager(s.mac, &cfg)
	err := bucketManager.Delete(s.bucket, objectKey)
	if err != nil {
		return fmt.Errorf("从七牛云删除文件失败: %w", err)
	}

	return nil
}

// Exists 检查文件是否存在
func (s *QiniuStorage) Exists(path string) (bool, error) {
	objectKey := s.getObjectKey(path)

	cfg := storage.Config{
		Zone: s.region,
	}

	bucketManager := storage.NewBucketManager(s.mac, &cfg)
	_, err := bucketManager.Stat(s.bucket, objectKey)
	if err != nil {
		if strings.Contains(err.Error(), "no such file or directory") {
			return false, nil
		}
		return false, fmt.Errorf("检查七牛云文件是否存在失败: %w", err)
	}

	return true, nil
}

// GetURL 获取访问URL
func (s *QiniuStorage) GetURL(path string) string {
	objectKey := s.getObjectKey(path)
	return fmt.Sprintf("%s/%s", s.domain, objectKey)
}

// GetType 获取存储类型
func (s *QiniuStorage) GetType() StorageType {
	return StorageTypeQiniu
}

// getObjectKey 获取对象键
func (s *QiniuStorage) getObjectKey(path string) string {
	path = strings.Trim(path, "/")
	if s.basePath != "" {
		return s.basePath + "/" + path
	}
	return path
}
