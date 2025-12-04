package storage

import (
	"context"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"strings"

	"github.com/tencentyun/cos-go-sdk-v5"
)

// COSStorage 腾讯云COS存储实现
type COSStorage struct {
	client   *cos.Client
	basePath string
	baseURL  string
}

// NewCOSStorage 创建COS存储实例
func NewCOSStorage(cfg *Config) (*COSStorage, error) {
	if cfg.COSRegion == "" || cfg.COSSecretID == "" ||
		cfg.COSSecretKey == "" || cfg.COSBucket == "" {
		return nil, fmt.Errorf("COS配置不完整")
	}

	// 构建Bucket URL
	bucketURL := fmt.Sprintf("https://%s.cos.%s.myqcloud.com", cfg.COSBucket, cfg.COSRegion)
	u, err := url.Parse(bucketURL)
	if err != nil {
		return nil, fmt.Errorf("解析Bucket URL失败: %w", err)
	}

	// 创建COS客户端
	b := &cos.BaseURL{BucketURL: u}
	client := cos.NewClient(b, &http.Client{
		Transport: &cos.AuthorizationTransport{
			SecretID:  cfg.COSSecretID,
			SecretKey: cfg.COSSecretKey,
		},
	})

	return &COSStorage{
		client:   client,
		basePath: strings.Trim(cfg.COSBasePath, "/"),
		baseURL:  bucketURL,
	}, nil
}

// Save 保存文件
func (s *COSStorage) Save(path string, file *multipart.FileHeader) (string, error) {
	objectKey := s.getObjectKey(path)

	src, err := file.Open()
	if err != nil {
		return "", fmt.Errorf("打开上传文件失败: %w", err)
	}
	defer src.Close()

	_, err = s.client.Object.Put(context.Background(), objectKey, src, nil)
	if err != nil {
		return "", fmt.Errorf("上传到COS失败: %w", err)
	}

	return s.GetURL(path), nil
}

// SaveFromReader 从Reader保存文件
func (s *COSStorage) SaveFromReader(path string, reader io.Reader, size int64) (string, error) {
	objectKey := s.getObjectKey(path)

	_, err := s.client.Object.Put(context.Background(), objectKey, reader, nil)
	if err != nil {
		return "", fmt.Errorf("上传到COS失败: %w", err)
	}

	return s.GetURL(path), nil
}

// Get 获取文件
func (s *COSStorage) Get(path string) (io.ReadCloser, error) {
	objectKey := s.getObjectKey(path)

	resp, err := s.client.Object.Get(context.Background(), objectKey, nil)
	if err != nil {
		return nil, fmt.Errorf("从COS获取文件失败: %w", err)
	}

	return resp.Body, nil
}

// Delete 删除文件
func (s *COSStorage) Delete(path string) error {
	objectKey := s.getObjectKey(path)

	_, err := s.client.Object.Delete(context.Background(), objectKey)
	if err != nil {
		return fmt.Errorf("从COS删除文件失败: %w", err)
	}

	return nil
}

// Exists 检查文件是否存在
func (s *COSStorage) Exists(path string) (bool, error) {
	objectKey := s.getObjectKey(path)

	_, err := s.client.Object.Head(context.Background(), objectKey, nil)
	if err != nil {
		if cos.IsNotFoundError(err) {
			return false, nil
		}
		return false, fmt.Errorf("检查COS文件是否存在失败: %w", err)
	}

	return true, nil
}

// GetURL 获取访问URL
func (s *COSStorage) GetURL(path string) string {
	objectKey := s.getObjectKey(path)
	return fmt.Sprintf("%s/%s", strings.TrimRight(s.baseURL, "/"), objectKey)
}

// GetType 获取存储类型
func (s *COSStorage) GetType() StorageType {
	return StorageTypeCOS
}

// getObjectKey 获取对象键
func (s *COSStorage) getObjectKey(path string) string {
	path = strings.Trim(path, "/")
	if s.basePath != "" {
		return s.basePath + "/" + path
	}
	return path
}
