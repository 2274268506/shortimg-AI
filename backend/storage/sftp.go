package storage

import (
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path"
	"strings"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
)

// SFTPStorage SFTP存储实现
type SFTPStorage struct {
	client   *sftp.Client
	sshConn  *ssh.Client
	basePath string // SFTP服务器上的基础路径
	baseURL  string // 访问基础URL
}

// NewSFTPStorage 创建SFTP存储实例
func NewSFTPStorage(cfg *Config) (*SFTPStorage, error) {
	if cfg.SFTPHost == "" {
		return nil, fmt.Errorf("SFTP主机地址不能为空")
	}

	port := cfg.SFTPPort
	if port == 0 {
		port = 22
	}

	// 配置SSH认证
	var authMethods []ssh.AuthMethod

	// 优先使用私钥认证
	if cfg.SFTPPrivateKey != "" {
		key, err := os.ReadFile(cfg.SFTPPrivateKey)
		if err != nil {
			return nil, fmt.Errorf("读取SSH私钥失败: %w", err)
		}

		signer, err := ssh.ParsePrivateKey(key)
		if err != nil {
			return nil, fmt.Errorf("解析SSH私钥失败: %w", err)
		}

		authMethods = append(authMethods, ssh.PublicKeys(signer))
	}

	// 密码认证
	if cfg.SFTPPassword != "" {
		authMethods = append(authMethods, ssh.Password(cfg.SFTPPassword))
	}

	if len(authMethods) == 0 {
		return nil, fmt.Errorf("必须提供密码或私钥进行认证")
	}

	// SSH客户端配置
	sshConfig := &ssh.ClientConfig{
		User:            cfg.SFTPUsername,
		Auth:            authMethods,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), // 生产环境应该验证主机密钥
	}

	// 连接SSH服务器
	addr := fmt.Sprintf("%s:%d", cfg.SFTPHost, port)
	sshConn, err := ssh.Dial("tcp", addr, sshConfig)
	if err != nil {
		return nil, fmt.Errorf("连接SSH服务器失败: %w", err)
	}

	// 创建SFTP客户端
	client, err := sftp.NewClient(sshConn)
	if err != nil {
		sshConn.Close()
		return nil, fmt.Errorf("创建SFTP客户端失败: %w", err)
	}

	basePath := cfg.SFTPBasePath
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
		if err := client.MkdirAll(basePath); err != nil {
			client.Close()
			sshConn.Close()
			return nil, fmt.Errorf("创建SFTP基础目录失败: %w", err)
		}
	}

	baseURL := cfg.SFTPBaseURL
	if baseURL == "" {
		baseURL = fmt.Sprintf("sftp://%s%s", cfg.SFTPHost, basePath)
	}

	return &SFTPStorage{
		client:   client,
		sshConn:  sshConn,
		basePath: basePath,
		baseURL:  baseURL,
	}, nil
}

// Save 保存文件
func (s *SFTPStorage) Save(filePath string, file *multipart.FileHeader) (string, error) {
	// 打开上传的文件
	src, err := file.Open()
	if err != nil {
		return "", fmt.Errorf("打开上传文件失败: %w", err)
	}
	defer src.Close()

	return s.SaveFromReader(filePath, src, file.Size)
}

// SaveFromReader 从Reader保存文件
func (s *SFTPStorage) SaveFromReader(filePath string, reader io.Reader, size int64) (string, error) {
	// 清理路径
	safePath := s.sanitizePath(filePath)
	fullPath := path.Join(s.basePath, safePath)

	// 创建父目录
	dir := path.Dir(fullPath)
	if dir != "/" && dir != s.basePath {
		if err := s.client.MkdirAll(dir); err != nil {
			return "", fmt.Errorf("创建SFTP目录失败: %w", err)
		}
	}

	// 创建远程文件
	dst, err := s.client.Create(fullPath)
	if err != nil {
		return "", fmt.Errorf("创建SFTP文件失败: %w", err)
	}
	defer dst.Close()

	// 复制数据
	if _, err := io.Copy(dst, reader); err != nil {
		return "", fmt.Errorf("上传到SFTP失败: %w", err)
	}

	return s.GetURL(safePath), nil
}

// Get 获取文件
func (s *SFTPStorage) Get(filePath string) (io.ReadCloser, error) {
	safePath := s.sanitizePath(filePath)
	fullPath := path.Join(s.basePath, safePath)

	// 打开远程文件
	file, err := s.client.Open(fullPath)
	if err != nil {
		return nil, fmt.Errorf("从SFTP打开文件失败: %w", err)
	}

	return file, nil
}

// Delete 删除文件
func (s *SFTPStorage) Delete(filePath string) error {
	safePath := s.sanitizePath(filePath)
	fullPath := path.Join(s.basePath, safePath)

	if err := s.client.Remove(fullPath); err != nil {
		return fmt.Errorf("从SFTP删除文件失败: %w", err)
	}

	return nil
}

// Exists 检查文件是否存在
func (s *SFTPStorage) Exists(filePath string) (bool, error) {
	safePath := s.sanitizePath(filePath)
	fullPath := path.Join(s.basePath, safePath)

	// 尝试获取文件信息
	_, err := s.client.Stat(fullPath)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		return false, fmt.Errorf("检查SFTP文件失败: %w", err)
	}

	return true, nil
}

// GetURL 获取文件访问URL
func (s *SFTPStorage) GetURL(filePath string) string {
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
func (s *SFTPStorage) GetType() StorageType {
	return StorageTypeSFTP
}

// Close 关闭连接
func (s *SFTPStorage) Close() error {
	if s.client != nil {
		s.client.Close()
	}
	if s.sshConn != nil {
		s.sshConn.Close()
	}
	return nil
}

// sanitizePath 清理路径，防止路径遍历攻击
func (s *SFTPStorage) sanitizePath(p string) string {
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
