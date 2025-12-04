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

	// 文件上传配置
	UploadPath  string
	MaxFileSize int64 // MB

	// 存储配置
	StorageType string // local, oss, cos, qiniu, s3

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

	// 日志配置
	LogPath       string
	LogMaxSize    int // MB
	LogMaxAge     int // days
	LogMaxBackups int

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

		// 日志配置
		LogPath:       getEnv("LOG_PATH", "./logs/app.log"),
		LogMaxSize:    getEnvAsInt("LOG_MAX_SIZE", 100),
		LogMaxAge:     getEnvAsInt("LOG_MAX_AGE", 30),
		LogMaxBackups: getEnvAsInt("LOG_MAX_BACKUPS", 10),

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
