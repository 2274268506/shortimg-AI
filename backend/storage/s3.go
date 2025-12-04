package storage

import (
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"strings"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// S3Storage S3存储实现(支持AWS S3, MinIO等)
type S3Storage struct {
	client   *minio.Client
	bucket   string
	basePath string
	useSSL   bool
	endpoint string
}

// NewS3Storage 创建S3存储实例
func NewS3Storage(cfg *Config) (*S3Storage, error) {
	if cfg.S3Endpoint == "" || cfg.S3AccessKeyID == "" ||
		cfg.S3SecretAccessKey == "" || cfg.S3Bucket == "" {
		return nil, fmt.Errorf("S3配置不完整")
	}

	client, err := minio.New(cfg.S3Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.S3AccessKeyID, cfg.S3SecretAccessKey, ""),
		Secure: cfg.S3UseSSL,
		Region: cfg.S3Region,
	})
	if err != nil {
		return nil, fmt.Errorf("创建S3客户端失败: %w", err)
	}

	// 检查bucket是否存在
	ctx := context.Background()
	exists, err := client.BucketExists(ctx, cfg.S3Bucket)
	if err != nil {
		return nil, fmt.Errorf("检查S3 Bucket失败: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("S3 Bucket %s 不存在", cfg.S3Bucket)
	}

	return &S3Storage{
		client:   client,
		bucket:   cfg.S3Bucket,
		basePath: strings.Trim(cfg.S3BasePath, "/"),
		useSSL:   cfg.S3UseSSL,
		endpoint: cfg.S3Endpoint,
	}, nil
}

// Save 保存文件
func (s *S3Storage) Save(path string, file *multipart.FileHeader) (string, error) {
	objectKey := s.getObjectKey(path)

	src, err := file.Open()
	if err != nil {
		return "", fmt.Errorf("打开上传文件失败: %w", err)
	}
	defer src.Close()

	ctx := context.Background()
	_, err = s.client.PutObject(ctx, s.bucket, objectKey, src, file.Size, minio.PutObjectOptions{
		ContentType: file.Header.Get("Content-Type"),
	})
	if err != nil {
		return "", fmt.Errorf("上传到S3失败: %w", err)
	}

	return s.GetURL(path), nil
}

// SaveFromReader 从Reader保存文件
func (s *S3Storage) SaveFromReader(path string, reader io.Reader, size int64) (string, error) {
	objectKey := s.getObjectKey(path)

	ctx := context.Background()
	_, err := s.client.PutObject(ctx, s.bucket, objectKey, reader, size, minio.PutObjectOptions{})
	if err != nil {
		return "", fmt.Errorf("上传到S3失败: %w", err)
	}

	return s.GetURL(path), nil
}

// Get 获取文件
func (s *S3Storage) Get(path string) (io.ReadCloser, error) {
	objectKey := s.getObjectKey(path)

	ctx := context.Background()
	obj, err := s.client.GetObject(ctx, s.bucket, objectKey, minio.GetObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("从S3获取文件失败: %w", err)
	}

	return obj, nil
}

// Delete 删除文件
func (s *S3Storage) Delete(path string) error {
	objectKey := s.getObjectKey(path)

	ctx := context.Background()
	err := s.client.RemoveObject(ctx, s.bucket, objectKey, minio.RemoveObjectOptions{})
	if err != nil {
		return fmt.Errorf("从S3删除文件失败: %w", err)
	}

	return nil
}

// Exists 检查文件是否存在
func (s *S3Storage) Exists(path string) (bool, error) {
	objectKey := s.getObjectKey(path)

	ctx := context.Background()
	_, err := s.client.StatObject(ctx, s.bucket, objectKey, minio.StatObjectOptions{})
	if err != nil {
		errResponse := minio.ToErrorResponse(err)
		if errResponse.Code == "NoSuchKey" {
			return false, nil
		}
		return false, fmt.Errorf("检查S3文件是否存在失败: %w", err)
	}

	return true, nil
}

// GetURL 获取访问URL
func (s *S3Storage) GetURL(path string) string {
	objectKey := s.getObjectKey(path)
	protocol := "http"
	if s.useSSL {
		protocol = "https"
	}
	return fmt.Sprintf("%s://%s/%s/%s", protocol, s.endpoint, s.bucket, objectKey)
}

// GetType 获取存储类型
func (s *S3Storage) GetType() StorageType {
	return StorageTypeS3
}

// getObjectKey 获取对象键
func (s *S3Storage) getObjectKey(path string) string {
	path = strings.Trim(path, "/")
	if s.basePath != "" {
		return s.basePath + "/" + path
	}
	return path
}
