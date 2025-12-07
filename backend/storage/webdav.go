package storage

import (
	"bytes"
	"fmt"
	"io"
	"mime/multipart"
	"path"
	"strings"

	"github.com/studio-b12/gowebdav"
)

// WebDAVStorage WebDAV存储实现
type WebDAVStorage struct {
	client   *gowebdav.Client
	basePath string // WebDAV服务器上的基础路径
	baseURL  string // 访问基础URL
}

// NewWebDAVStorage 创建WebDAV存储实例
func NewWebDAVStorage(cfg *Config) (*WebDAVStorage, error) {
	if cfg.WebDAVURL == "" {
		return nil, fmt.Errorf("WebDAV URL不能为空")
	}

	// 创建WebDAV客户端
	client := gowebdav.NewClient(cfg.WebDAVURL, cfg.WebDAVUsername, cfg.WebDAVPassword)

	// 测试连接
	if err := client.Connect(); err != nil {
		return nil, fmt.Errorf("连接WebDAV服务器失败: %w", err)
	}

	basePath := cfg.WebDAVBasePath
	if basePath == "" {
		basePath = "/"
	}
	// 确保路径以 / 开头
	if !strings.HasPrefix(basePath, "/") {
		basePath = "/" + basePath
	}
	// 确保路径以 / 结尾
	if !strings.HasSuffix(basePath, "/") {
		basePath = basePath + "/"
	}

	// 创建基础目录
	if basePath != "/" {
		if err := client.MkdirAll(basePath, 0755); err != nil {
			return nil, fmt.Errorf("创建WebDAV基础目录失败: %w", err)
		}
	}

	baseURL := cfg.WebDAVBaseURL
	if baseURL == "" {
		baseURL = cfg.WebDAVURL + basePath
	}

	return &WebDAVStorage{
		client:   client,
		basePath: basePath,
		baseURL:  baseURL,
	}, nil
}

// Save 保存文件
func (s *WebDAVStorage) Save(filePath string, file *multipart.FileHeader) (string, error) {
	// 打开上传的文件
	src, err := file.Open()
	if err != nil {
		return "", fmt.Errorf("打开上传文件失败: %w", err)
	}
	defer src.Close()

	return s.SaveFromReader(filePath, src, file.Size)
}

// SaveFromReader 从Reader保存文件
func (s *WebDAVStorage) SaveFromReader(filePath string, reader io.Reader, size int64) (string, error) {
	// 清理路径
	safePath := s.sanitizePath(filePath)
	fullPath := path.Join(s.basePath, safePath)

	// 创建父目录
	dir := path.Dir(fullPath)
	if dir != "/" && dir != s.basePath {
		if err := s.client.MkdirAll(dir, 0755); err != nil {
			return "", fmt.Errorf("创建WebDAV目录失败: %w", err)
		}
	}

	// 读取数据到内存（WebDAV需要完整数据）
	data, err := io.ReadAll(reader)
	if err != nil {
		return "", fmt.Errorf("读取文件数据失败: %w", err)
	}

	// 上传文件
	if err := s.client.Write(fullPath, data, 0644); err != nil {
		return "", fmt.Errorf("上传到WebDAV失败: %w", err)
	}

	return s.GetURL(safePath), nil
}

// Get 获取文件
func (s *WebDAVStorage) Get(filePath string) (io.ReadCloser, error) {
	safePath := s.sanitizePath(filePath)
	fullPath := path.Join(s.basePath, safePath)

	// 读取文件
	data, err := s.client.Read(fullPath)
	if err != nil {
		return nil, fmt.Errorf("从WebDAV读取文件失败: %w", err)
	}

	return io.NopCloser(bytes.NewReader(data)), nil
}

// Delete 删除文件
func (s *WebDAVStorage) Delete(filePath string) error {
	safePath := s.sanitizePath(filePath)
	fullPath := path.Join(s.basePath, safePath)

	if err := s.client.Remove(fullPath); err != nil {
		return fmt.Errorf("从WebDAV删除文件失败: %w", err)
	}

	return nil
}

// Exists 检查文件是否存在
func (s *WebDAVStorage) Exists(filePath string) (bool, error) {
	safePath := s.sanitizePath(filePath)
	fullPath := path.Join(s.basePath, safePath)

	// 尝试获取文件信息
	_, err := s.client.Stat(fullPath)
	if err != nil {
		// 如果是404错误，说明文件不存在
		if strings.Contains(err.Error(), "404") {
			return false, nil
		}
		return false, fmt.Errorf("检查WebDAV文件失败: %w", err)
	}

	return true, nil
}

// GetURL 获取文件访问URL
func (s *WebDAVStorage) GetURL(filePath string) string {
	safePath := s.sanitizePath(filePath)
	// 确保baseURL以/结尾
	baseURL := s.baseURL
	if !strings.HasSuffix(baseURL, "/") {
		baseURL = baseURL + "/"
	}
	// 确保safePath不以/开头
	safePath = strings.TrimPrefix(safePath, "/")
	return baseURL + safePath
}

// GetType 获取存储类型
func (s *WebDAVStorage) GetType() StorageType {
	return StorageTypeWebDAV
}

// sanitizePath 清理路径，防止路径遍历攻击
func (s *WebDAVStorage) sanitizePath(p string) string {
	// 移除开头的斜杠
	p = strings.TrimPrefix(p, "/")
	// 清理路径
	p = path.Clean(p)
	// 再次确保没有..
	parts := strings.Split(p, "/")
	var cleanParts []string
	for _, part := range parts {
		if part != "" && part != "." && part != ".." {
			cleanParts = append(cleanParts, part)
		}
	}
	return strings.Join(cleanParts, "/")
}
