package storage

import (
	"fmt"
	"io"
	"mime/multipart"
	"strings"

	"github.com/aliyun/aliyun-oss-go-sdk/oss"
)

// OSSStorage 阿里云OSS存储实现
type OSSStorage struct {
	client   *oss.Client
	bucket   *oss.Bucket
	basePath string
}

// NewOSSStorage 创建OSS存储实例
func NewOSSStorage(cfg *Config) (*OSSStorage, error) {
	if cfg.OSSEndpoint == "" || cfg.OSSAccessKeyID == "" ||
		cfg.OSSAccessKeySecret == "" || cfg.OSSBucket == "" {
		return nil, fmt.Errorf("OSS配置不完整")
	}

	client, err := oss.New(cfg.OSSEndpoint, cfg.OSSAccessKeyID, cfg.OSSAccessKeySecret)
	if err != nil {
		return nil, fmt.Errorf("创建OSS客户端失败: %w", err)
	}

	bucket, err := client.Bucket(cfg.OSSBucket)
	if err != nil {
		return nil, fmt.Errorf("获取OSS Bucket失败: %w", err)
	}

	return &OSSStorage{
		client:   client,
		bucket:   bucket,
		basePath: strings.Trim(cfg.OSSBasePath, "/"),
	}, nil
}

// Save 保存文件
func (s *OSSStorage) Save(path string, file *multipart.FileHeader) (string, error) {
	objectKey := s.getObjectKey(path)

	src, err := file.Open()
	if err != nil {
		return "", fmt.Errorf("打开上传文件失败: %w", err)
	}
	defer src.Close()

	if err := s.bucket.PutObject(objectKey, src); err != nil {
		return "", fmt.Errorf("上传到OSS失败: %w", err)
	}

	return s.GetURL(path), nil
}

// SaveFromReader 从Reader保存文件
func (s *OSSStorage) SaveFromReader(path string, reader io.Reader, size int64) (string, error) {
	objectKey := s.getObjectKey(path)

	if err := s.bucket.PutObject(objectKey, reader); err != nil {
		return "", fmt.Errorf("上传到OSS失败: %w", err)
	}

	return s.GetURL(path), nil
}

// Get 获取文件
func (s *OSSStorage) Get(path string) (io.ReadCloser, error) {
	objectKey := s.getObjectKey(path)

	body, err := s.bucket.GetObject(objectKey)
	if err != nil {
		return nil, fmt.Errorf("从OSS获取文件失败: %w", err)
	}

	return body, nil
}

// Delete 删除文件
func (s *OSSStorage) Delete(path string) error {
	objectKey := s.getObjectKey(path)

	if err := s.bucket.DeleteObject(objectKey); err != nil {
		return fmt.Errorf("从OSS删除文件失败: %w", err)
	}

	return nil
}

// Exists 检查文件是否存在
func (s *OSSStorage) Exists(path string) (bool, error) {
	objectKey := s.getObjectKey(path)

	exists, err := s.bucket.IsObjectExist(objectKey)
	if err != nil {
		return false, fmt.Errorf("检查OSS文件是否存在失败: %w", err)
	}

	return exists, nil
}

// GetURL 获取访问URL
func (s *OSSStorage) GetURL(path string) string {
	objectKey := s.getObjectKey(path)
	// 返回公共访问URL
	// 格式: https://{bucket}.{endpoint}/{objectKey}
	endpoint := strings.TrimPrefix(s.client.Config.Endpoint, "http://")
	endpoint = strings.TrimPrefix(endpoint, "https://")
	return fmt.Sprintf("https://%s.%s/%s", s.bucket.BucketName, endpoint, objectKey)
}

// GetType 获取存储类型
func (s *OSSStorage) GetType() StorageType {
	return StorageTypeOSS
}

// getObjectKey 获取对象键
func (s *OSSStorage) getObjectKey(path string) string {
	path = strings.Trim(path, "/")
	if s.basePath != "" {
		return s.basePath + "/" + path
	}
	return path
}
