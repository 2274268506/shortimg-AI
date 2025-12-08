package config

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	// 数据库配置
	DatabaseType string // sqlite, postgres, mysql
	DatabaseDSN  string // 数据库连接字符串

	// Redis 配置
	RedisEnabled  bool
	RedisAddr     string
	RedisPassword string
	RedisDB       int
	CacheTTL      time.Duration // 缓存过期时间

	// 服务器配置
	ServerPort string
	ServerMode string // debug, release

	// JWT 配置
	JWTSecret     string
	JWTExpiration time.Duration

	// 用户管理配置
	AllowRegistration bool // 是否允许用户注册

	// 文件上传配置
	UploadPath  string
	MaxFileSize int64 // MB

	// 存储配置
	StorageType string // local, oss, cos, qiniu, s3, webdav, sftp

	// 本地存储配置
	StorageLocalPath string
	StorageBaseURL   string

	// OSS配置
	OSSEndpoint        string
	OSSAccessKeyID     string
	OSSAccessKeySecret string
	OSSBucket          string
	OSSBasePath        string

	// COS配置
	COSRegion    string
	COSSecretID  string
	COSSecretKey string
	COSBucket    string
	COSBasePath  string

	// 七牛云配置
	QiniuAccessKey string
	QiniuSecretKey string
	QiniuBucket    string
	QiniuDomain    string
	QiniuRegion    string
	QiniuBasePath  string

	// S3配置
	S3Endpoint        string
	S3AccessKeyID     string
	S3SecretAccessKey string
	S3Bucket          string
	S3Region          string
	S3BasePath        string
	S3UseSSL          bool

	// WebDAV配置
	WebDAVURL      string
	WebDAVUsername string
	WebDAVPassword string
	WebDAVBasePath string
	WebDAVBaseURL  string // 访问URL前缀

	// SFTP配置
	SFTPHost       string
	SFTPPort       int
	SFTPUsername   string
	SFTPPassword   string
	SFTPPrivateKey string // 私钥文件路径
	SFTPBasePath   string
	SFTPBaseURL    string // 访问URL前缀

	// 日志配置
	LogPath       string
	LogMaxSize    int // MB
	LogMaxAge     int // days
	LogMaxBackups int

	// 短链服务配置
	ShortLinkEnabled   bool   // 是否启用短链功能
	ShortLinkBaseURL   string // 短链服务 API 地址(后端调用用)
	ShortLinkPublicURL string // 短链公开访问地址(浏览器访问用)
	ShortLinkExpire    int64  // 短链默认过期时间（秒），0表示永不过期
	ShortLinkAPIKey    string // 短链服务API密钥

	// CORS 跨域配置
	CORSEnabled      bool     // 是否启用CORS
	CORSAllowOrigins []string // 允许的源
	CORSAllowMethods []string // 允许的HTTP方法
	CORSAllowHeaders []string // 允许的请求头
	CORSMaxAge       int      // 预检请求缓存时间（小时）

	// 默认管理员账户配置
	DefaultAdminUsername string // 默认管理员用户名
	DefaultAdminPassword string // 默认管理员密码
	DefaultAdminEmail    string // 默认管理员邮箱

	// 旧字段保持兼容性
	AllowedReferers []string
	DatabasePath    string // 兼容旧配置
	SecretKey       string // 兼容旧配置
}

var globalConfig *Config

func LoadConfig() *Config {
	// 加载 .env 文件
	if err := godotenv.Load(); err != nil {
		log.Println("未找到 .env 文件，使用默认配置或环境变量")
	}

	uploadPath := getEnv("UPLOAD_PATH", "./uploads")

	// 确保目录存在
	os.MkdirAll(uploadPath, 0755)
	os.MkdirAll("./data", 0755)
	os.MkdirAll("./logs", 0755)

	dbType := getEnv("DB_TYPE", "sqlite")
	var dbDSN string

	// 根据数据库类型设置默认 DSN
	switch dbType {
	case "postgres":
		dbDSN = getEnv("DB_DSN", "host=localhost port=5432 user=postgres password=postgres dbname=imagebed sslmode=disable")
	case "mysql":
		dbDSN = getEnv("DB_DSN", "root:password@tcp(localhost:3306)/imagebed?charset=utf8mb4&parseTime=True&loc=Local")
	default: // sqlite
		dbDSN = getEnv("DB_DSN", "./data/imagebed.db")
	}

	globalConfig = &Config{
		// 数据库配置
		DatabaseType: dbType,
		DatabaseDSN:  dbDSN,

		// Redis 配置
		RedisEnabled:  getEnvAsBool("REDIS_ENABLED", false),
		RedisAddr:     getEnv("REDIS_ADDR", "localhost:6379"),
		RedisPassword: getEnv("REDIS_PASSWORD", ""),
		RedisDB:       getEnvAsInt("REDIS_DB", 0),
		CacheTTL:      getEnvAsDuration("CACHE_TTL", "10m"),

		// 服务器配置
		ServerPort: getEnv("SERVER_PORT", "8080"),
		ServerMode: getEnv("SERVER_MODE", "debug"),

		// JWT 配置
		JWTSecret:     getEnv("JWT_SECRET", "your-secret-key-change-this-in-production"),
		JWTExpiration: getEnvAsDuration("JWT_EXPIRATION", "24h"),

		// 用户管理配置
		AllowRegistration: getEnvAsBool("ALLOW_REGISTRATION", true),

		// 文件上传配置
		UploadPath:  uploadPath,
		MaxFileSize: getEnvAsInt64("MAX_FILE_SIZE", 100),

		// 存储配置
		StorageType:      getEnv("STORAGE_TYPE", "local"),
		StorageLocalPath: getEnv("STORAGE_LOCAL_PATH", uploadPath),
		StorageBaseURL:   getEnv("STORAGE_BASE_URL", "/api/files"),

		// OSS配置
		OSSEndpoint:        getEnv("OSS_ENDPOINT", ""),
		OSSAccessKeyID:     getEnv("OSS_ACCESS_KEY_ID", ""),
		OSSAccessKeySecret: getEnv("OSS_ACCESS_KEY_SECRET", ""),
		OSSBucket:          getEnv("OSS_BUCKET", ""),
		OSSBasePath:        getEnv("OSS_BASE_PATH", ""),

		// COS配置
		COSRegion:    getEnv("COS_REGION", ""),
		COSSecretID:  getEnv("COS_SECRET_ID", ""),
		COSSecretKey: getEnv("COS_SECRET_KEY", ""),
		COSBucket:    getEnv("COS_BUCKET", ""),
		COSBasePath:  getEnv("COS_BASE_PATH", ""),

		// 七牛云配置
		QiniuAccessKey: getEnv("QINIU_ACCESS_KEY", ""),
		QiniuSecretKey: getEnv("QINIU_SECRET_KEY", ""),
		QiniuBucket:    getEnv("QINIU_BUCKET", ""),
		QiniuDomain:    getEnv("QINIU_DOMAIN", ""),
		QiniuRegion:    getEnv("QINIU_REGION", ""),
		QiniuBasePath:  getEnv("QINIU_BASE_PATH", ""),

		// S3配置
		S3Endpoint:        getEnv("S3_ENDPOINT", ""),
		S3AccessKeyID:     getEnv("S3_ACCESS_KEY_ID", ""),
		S3SecretAccessKey: getEnv("S3_SECRET_ACCESS_KEY", ""),
		S3Bucket:          getEnv("S3_BUCKET", ""),
		S3Region:          getEnv("S3_REGION", ""),
		S3BasePath:        getEnv("S3_BASE_PATH", ""),
		S3UseSSL:          getEnvAsBool("S3_USE_SSL", true),

		// WebDAV配置
		WebDAVURL:      getEnv("WEBDAV_URL", ""),
		WebDAVUsername: getEnv("WEBDAV_USERNAME", ""),
		WebDAVPassword: getEnv("WEBDAV_PASSWORD", ""),
		WebDAVBasePath: getEnv("WEBDAV_BASE_PATH", "/imagebed/"),
		WebDAVBaseURL:  getEnv("WEBDAV_BASE_URL", ""),

		// SFTP配置
		SFTPHost:       getEnv("SFTP_HOST", ""),
		SFTPPort:       getEnvAsInt("SFTP_PORT", 22),
		SFTPUsername:   getEnv("SFTP_USERNAME", ""),
		SFTPPassword:   getEnv("SFTP_PASSWORD", ""),
		SFTPPrivateKey: getEnv("SFTP_PRIVATE_KEY", ""),
		SFTPBasePath:   getEnv("SFTP_BASE_PATH", "/imagebed/"),
		SFTPBaseURL:    getEnv("SFTP_BASE_URL", ""),

		// 日志配置
		LogPath:       getEnv("LOG_PATH", "./logs/app.log"),
		LogMaxSize:    getEnvAsInt("LOG_MAX_SIZE", 100),
		LogMaxAge:     getEnvAsInt("LOG_MAX_AGE", 30),
		LogMaxBackups: getEnvAsInt("LOG_MAX_BACKUPS", 10),

		// 短链服务配置
		ShortLinkEnabled:   getEnvAsBool("SHORT_LINK_ENABLED", true),
		ShortLinkBaseURL:   getEnv("SHORT_LINK_BASE_URL", "http://localhost:8081"),
		ShortLinkPublicURL: getEnv("SHORT_LINK_PUBLIC_URL", ""), // 默认为空,使用 ShortLinkBaseURL
		ShortLinkExpire:    getEnvAsInt64("SHORT_LINK_EXPIRE", 0),
		ShortLinkAPIKey:    getEnv("SHORT_LINK_API_KEY", ""),

		// CORS 跨域配置
		CORSEnabled:      getEnvAsBool("CORS_ENABLED", true),
		CORSAllowOrigins: getEnvAsSlice("CORS_ALLOW_ORIGINS", "http://localhost:5173,http://localhost:5174,http://localhost:3000,http://127.0.0.1:5173,http://127.0.0.1:5174,http://127.0.0.1:3000"),
		CORSAllowMethods: getEnvAsSlice("CORS_ALLOW_METHODS", "GET,POST,PUT,PATCH,DELETE,OPTIONS"),
		CORSAllowHeaders: getEnvAsSlice("CORS_ALLOW_HEADERS", "Origin,Content-Type,Accept,Authorization"),
		CORSMaxAge:       getEnvAsInt("CORS_MAX_AGE", 12),

		// 默认管理员账户配置
		DefaultAdminUsername: getEnv("DEFAULT_ADMIN_USERNAME", "admin"),
		DefaultAdminPassword: getEnv("DEFAULT_ADMIN_PASSWORD", "admin123"),
		DefaultAdminEmail:    getEnv("DEFAULT_ADMIN_EMAIL", "admin@example.com"),

		// 兼容旧配置
		AllowedReferers: []string{"localhost", "127.0.0.1"},
		DatabasePath:    dbDSN, // 兼容性
		SecretKey:       getEnv("JWT_SECRET", "your-secret-key-change-this-in-production"),
	}

	log.Printf("配置已加载: DB=%s, Redis=%v, Mode=%s",
		globalConfig.DatabaseType, globalConfig.RedisEnabled, globalConfig.ServerMode)

	// 验证配置
	if err := globalConfig.Validate(); err != nil {
		log.Printf("配置验证警告: %v", err)
	}

	return globalConfig
}

func GetConfig() *Config {
	if globalConfig == nil {
		return LoadConfig()
	}
	return globalConfig
}

// Validate 验证配置有效性
func (c *Config) Validate() error {
	// 检查数据库配置
	if c.DatabaseType == "postgres" || c.DatabaseType == "mysql" {
		if c.DatabaseDSN == "" || c.DatabaseDSN == "./data/imagebed.db" {
			return fmt.Errorf("使用 %s 数据库时必须配置正确的 DB_DSN", c.DatabaseType)
		}
	}

	// 检查JWT密钥安全性
	if c.JWTSecret == "your-secret-key-change-this-in-production" ||
		c.JWTSecret == "dev-secret-key-for-testing-only" {
		if c.ServerMode == "release" {
			log.Fatal("❌ 生产环境必须修改 JWT_SECRET 为强随机字符串")
		}
		log.Println("⚠️  警告: 使用默认JWT密钥，生产环境请务必修改!")
	}

	// 检查JWT密钥长度（强制要求）
	if len(c.JWTSecret) < 32 {
		if c.ServerMode == "release" {
			log.Fatalf("❌ JWT 密钥长度必须至少32位，当前仅%d位", len(c.JWTSecret))
		}
		log.Printf("⚠️  警告: JWT密钥长度建议至少32位，当前仅%d位", len(c.JWTSecret))
	}

	// 检查密钥复杂度（生产环境）
	if c.ServerMode == "release" && !isStrongSecret(c.JWTSecret) {
		log.Println("⚠️  警告: JWT 密钥应包含大小写字母、数字和特殊字符")
	}

	// 检查Redis配置
	if c.RedisEnabled && c.RedisAddr == "" {
		return fmt.Errorf("启用Redis时必须配置 REDIS_ADDR")
	}

	// 检查端口配置
	if c.ServerPort == "" {
		return fmt.Errorf("SERVER_PORT 不能为空")
	}

	// 检查文件大小限制
	if c.MaxFileSize <= 0 {
		log.Println("⚠️  警告: MAX_FILE_SIZE 应该大于0，已设置为默认值100MB")
		c.MaxFileSize = 100
	}

	if c.MaxFileSize > 1000 {
		log.Printf("⚠️  警告: MAX_FILE_SIZE=%dMB 过大，可能导致内存问题", c.MaxFileSize)
	}

	return nil
}

// GetStorageConfig 获取存储配置
func (c *Config) GetStorageConfig() interface{} {
	// 这里返回interface{}是为了避免循环依赖
	// 实际使用时需要在storage包中转换
	return map[string]interface{}{
		"Type":               c.StorageType,
		"LocalPath":          c.StorageLocalPath,
		"BaseURL":            c.StorageBaseURL,
		"OSSEndpoint":        c.OSSEndpoint,
		"OSSAccessKeyID":     c.OSSAccessKeyID,
		"OSSAccessKeySecret": c.OSSAccessKeySecret,
		"OSSBucket":          c.OSSBucket,
		"OSSBasePath":        c.OSSBasePath,
		"COSRegion":          c.COSRegion,
		"COSSecretID":        c.COSSecretID,
		"COSSecretKey":       c.COSSecretKey,
		"COSBucket":          c.COSBucket,
		"COSBasePath":        c.COSBasePath,
		"QiniuAccessKey":     c.QiniuAccessKey,
		"QiniuSecretKey":     c.QiniuSecretKey,
		"QiniuBucket":        c.QiniuBucket,
		"QiniuDomain":        c.QiniuDomain,
		"QiniuRegion":        c.QiniuRegion,
		"QiniuBasePath":      c.QiniuBasePath,
		"S3Endpoint":         c.S3Endpoint,
		"S3AccessKeyID":      c.S3AccessKeyID,
		"S3SecretAccessKey":  c.S3SecretAccessKey,
		"S3Bucket":           c.S3Bucket,
		"S3Region":           c.S3Region,
		"S3BasePath":         c.S3BasePath,
		"S3UseSSL":           c.S3UseSSL,
		"WebDAVURL":          c.WebDAVURL,
		"WebDAVUsername":     c.WebDAVUsername,
		"WebDAVPassword":     c.WebDAVPassword,
		"WebDAVBasePath":     c.WebDAVBasePath,
		"WebDAVBaseURL":      c.WebDAVBaseURL,
		"SFTPHost":           c.SFTPHost,
		"SFTPPort":           c.SFTPPort,
		"SFTPUsername":       c.SFTPUsername,
		"SFTPPassword":       c.SFTPPassword,
		"SFTPPrivateKey":     c.SFTPPrivateKey,
		"SFTPBasePath":       c.SFTPBasePath,
		"SFTPBaseURL":        c.SFTPBaseURL,
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	valueStr := getEnv(key, "")
	if value, err := strconv.Atoi(valueStr); err == nil {
		return value
	}
	return defaultValue
}

func getEnvAsInt64(key string, defaultValue int64) int64 {
	valueStr := getEnv(key, "")
	if value, err := strconv.ParseInt(valueStr, 10, 64); err == nil {
		return value
	}
	return defaultValue
}

func getEnvAsBool(key string, defaultValue bool) bool {
	valueStr := getEnv(key, "")
	if value, err := strconv.ParseBool(valueStr); err == nil {
		return value
	}
	return defaultValue
}

func getEnvAsDuration(key, defaultValue string) time.Duration {
	valueStr := getEnv(key, defaultValue)
	if value, err := time.ParseDuration(valueStr); err == nil {
		return value
	}
	// 如果解析失败，尝试解析默认值
	if value, err := time.ParseDuration(defaultValue); err == nil {
		return value
	}
	return 10 * time.Minute // 最终默认值
}

// getEnvAsSlice 从环境变量读取逗号分隔的字符串并转换为切片
func getEnvAsSlice(key, defaultValue string) []string {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		valueStr = defaultValue
	}

	// 分割字符串
	parts := []string{}
	for _, part := range splitAndTrim(valueStr, ",") {
		if part != "" {
			parts = append(parts, part)
		}
	}
	return parts
}

// splitAndTrim 分割字符串并去除空格
func splitAndTrim(s, sep string) []string {
	parts := []string{}
	for _, part := range splitString(s, sep) {
		trimmed := trimSpace(part)
		if trimmed != "" {
			parts = append(parts, trimmed)
		}
	}
	return parts
}

// splitString 简单的字符串分割
func splitString(s, sep string) []string {
	if s == "" {
		return []string{}
	}

	parts := []string{}
	start := 0
	for i := 0; i < len(s); i++ {
		if i+len(sep) <= len(s) && s[i:i+len(sep)] == sep {
			parts = append(parts, s[start:i])
			start = i + len(sep)
			i += len(sep) - 1
		}
	}
	parts = append(parts, s[start:])
	return parts
}

// trimSpace 去除字符串两端空格
func trimSpace(s string) string {
	start := 0
	end := len(s)

	for start < end && (s[start] == ' ' || s[start] == '\t' || s[start] == '\n' || s[start] == '\r') {
		start++
	}

	for end > start && (s[end-1] == ' ' || s[end-1] == '\t' || s[end-1] == '\n' || s[end-1] == '\r') {
		end--
	}

	return s[start:end]
}

// isStrongSecret 检查密钥是否足够强
func isStrongSecret(secret string) bool {
	hasUpper := false
	hasLower := false
	hasDigit := false
	hasSpecial := false

	for _, char := range secret {
		switch {
		case char >= 'A' && char <= 'Z':
			hasUpper = true
		case char >= 'a' && char <= 'z':
			hasLower = true
		case char >= '0' && char <= '9':
			hasDigit = true
		case char >= '!' && char <= '/' || char >= ':' && char <= '@' || char >= '[' && char <= '`' || char >= '{' && char <= '~':
			hasSpecial = true
		}
	}

	// 至少包含3种类型的字符
	count := 0
	if hasUpper {
		count++
	}
	if hasLower {
		count++
	}
	if hasDigit {
		count++
	}
	if hasSpecial {
		count++
	}

	return count >= 3
}

// GetJWTSecret 获取JWT密钥
func GetJWTSecret() []byte {
	config := GetConfig()
	return []byte(config.JWTSecret)
}
