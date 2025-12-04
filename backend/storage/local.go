package storage

import (
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"
)

// LocalStorage 本地存储实现
type LocalStorage struct {
	basePath string // 存储根目录
	baseURL  string // 访问基础URL
}

// NewLocalStorage 创建本地存储实例
func NewLocalStorage(cfg *Config) (*LocalStorage, error) {
	basePath := cfg.LocalPath
	if basePath == "" {
		basePath = "./uploads"
	}

	// 创建目录
	if err := os.MkdirAll(basePath, 0755); err != nil {
		return nil, fmt.Errorf("创建存储目录失败: %w", err)
	}

	baseURL := cfg.BaseURL
	if baseURL == "" {
		baseURL = "/api/files" // 默认URL前缀
	}

	return &LocalStorage{
		basePath: basePath,
		baseURL:  baseURL,
	}, nil
}

// Save 保存文件
func (s *LocalStorage) Save(path string, file *multipart.FileHeader) (string, error) {
	// 确保路径安全
	safePath := s.sanitizePath(path)
	fullPath := filepath.Join(s.basePath, safePath)

	// 创建目录
	dir := filepath.Dir(fullPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", fmt.Errorf("创建目录失败: %w", err)
	}

	// 保存文件
	src, err := file.Open()
	if err != nil {
		return "", fmt.Errorf("打开上传文件失败: %w", err)
	}
	defer src.Close()

	dst, err := os.Create(fullPath)
	if err != nil {
		return "", fmt.Errorf("创建文件失败: %w", err)
	}
	defer dst.Close()

	if _, err := io.Copy(dst, src); err != nil {
		return "", fmt.Errorf("保存文件失败: %w", err)
	}

	return s.GetURL(safePath), nil
}

// SaveFromReader 从Reader保存文件
func (s *LocalStorage) SaveFromReader(path string, reader io.Reader, size int64) (string, error) {
	safePath := s.sanitizePath(path)
	fullPath := filepath.Join(s.basePath, safePath)

	// 创建目录
	dir := filepath.Dir(fullPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", fmt.Errorf("创建目录失败: %w", err)
	}

	// 保存文件
	dst, err := os.Create(fullPath)
	if err != nil {
		return "", fmt.Errorf("创建文件失败: %w", err)
	}
	defer dst.Close()

	if _, err := io.Copy(dst, reader); err != nil {
		return "", fmt.Errorf("保存文件失败: %w", err)
	}

	return s.GetURL(safePath), nil
}

// Get 获取文件
func (s *LocalStorage) Get(path string) (io.ReadCloser, error) {
	safePath := s.sanitizePath(path)
	fullPath := filepath.Join(s.basePath, safePath)

	file, err := os.Open(fullPath)
	if err != nil {
		return nil, fmt.Errorf("打开文件失败: %w", err)
	}

	return file, nil
}

// Delete 删除文件
func (s *LocalStorage) Delete(path string) error {
	safePath := s.sanitizePath(path)
	fullPath := filepath.Join(s.basePath, safePath)

	if err := os.Remove(fullPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("删除文件失败: %w", err)
	}

	return nil
}

// Exists 检查文件是否存在
func (s *LocalStorage) Exists(path string) (bool, error) {
	safePath := s.sanitizePath(path)
	fullPath := filepath.Join(s.basePath, safePath)

	_, err := os.Stat(fullPath)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}

// GetURL 获取访问URL
func (s *LocalStorage) GetURL(path string) string {
	// 统一使用正斜杠
	normalizedPath := filepath.ToSlash(s.sanitizePath(path))
	return strings.TrimRight(s.baseURL, "/") + "/" + strings.TrimLeft(normalizedPath, "/")
}

// GetType 获取存储类型
func (s *LocalStorage) GetType() StorageType {
	return StorageTypeLocal
}

// sanitizePath 清理路径,防止路径遍历攻击
func (s *LocalStorage) sanitizePath(path string) string {
	// 移除路径中的 ../ 等危险字符
	safePath := filepath.Clean(path)
	// 移除开头的斜杠
	safePath = strings.TrimPrefix(safePath, "/")
	safePath = strings.TrimPrefix(safePath, "\\")
	return safePath
}
