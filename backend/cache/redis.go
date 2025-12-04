package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"imagebed/config"
	"log"
	"time"

	"github.com/redis/go-redis/v9"
)

var (
	redisClient *redis.Client
	ctx         = context.Background()
)

// InitRedis 初始化Redis连接
func InitRedis() error {
	cfg := config.GetConfig()

	if !cfg.RedisEnabled {
		log.Println("Redis 缓存未启用")
		return nil
	}

	redisClient = redis.NewClient(&redis.Options{
		Addr:     cfg.RedisAddr,
		Password: cfg.RedisPassword,
		DB:       cfg.RedisDB,
	})

	// 测试连接
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Printf("Redis 连接失败: %v", err)
		return err
	}

	log.Printf("Redis 缓存已启用: %s", cfg.RedisAddr)
	return nil
}

// IsEnabled 检查Redis是否启用
func IsEnabled() bool {
	return redisClient != nil && config.GetConfig().RedisEnabled
}

// Ping 检查 Redis 连接状态
func Ping() error {
	if !IsEnabled() {
		return fmt.Errorf("redis not enabled")
	}
	return redisClient.Ping(ctx).Err()
}

// Set 设置缓存
func Set(key string, value interface{}, expiration time.Duration) error {
	if !IsEnabled() {
		return nil
	}

	data, err := json.Marshal(value)
	if err != nil {
		return err
	}

	if expiration == 0 {
		expiration = config.GetConfig().CacheTTL
	}

	return redisClient.Set(ctx, key, data, expiration).Err()
}

// Get 获取缓存
func Get(key string, dest interface{}) error {
	if !IsEnabled() {
		return redis.Nil
	}

	data, err := redisClient.Get(ctx, key).Result()
	if err != nil {
		return err
	}

	return json.Unmarshal([]byte(data), dest)
}

// Delete 删除缓存
func Delete(keys ...string) error {
	if !IsEnabled() {
		return nil
	}

	return redisClient.Del(ctx, keys...).Err()
}

// DeletePattern 根据模式删除缓存
func DeletePattern(pattern string) error {
	if !IsEnabled() {
		return nil
	}

	var cursor uint64
	for {
		var keys []string
		var err error
		keys, cursor, err = redisClient.Scan(ctx, cursor, pattern, 100).Result()
		if err != nil {
			return err
		}

		if len(keys) > 0 {
			if err := redisClient.Del(ctx, keys...).Err(); err != nil {
				return err
			}
		}

		if cursor == 0 {
			break
		}
	}

	return nil
}

// Exists 检查键是否存在
func Exists(key string) bool {
	if !IsEnabled() {
		return false
	}

	count, err := redisClient.Exists(ctx, key).Result()
	return err == nil && count > 0
}

// Incr 自增计数器
func Incr(key string) (int64, error) {
	if !IsEnabled() {
		return 0, fmt.Errorf("redis not enabled")
	}

	return redisClient.Incr(ctx, key).Result()
}

// Expire 设置过期时间
func Expire(key string, expiration time.Duration) error {
	if !IsEnabled() {
		return nil
	}

	return redisClient.Expire(ctx, key, expiration).Err()
}

// Close 关闭Redis连接
func Close() error {
	if redisClient != nil {
		return redisClient.Close()
	}
	return nil
}

// CacheKey 生成缓存键
type CacheKey struct{}

func (CacheKey) Albums() string {
	return "albums:all"
}

func (CacheKey) Album(id uint) string {
	return fmt.Sprintf("album:%d", id)
}

func (CacheKey) AlbumImages(albumID uint) string {
	return fmt.Sprintf("album:%d:images", albumID)
}

func (CacheKey) Images() string {
	return "images:all"
}

func (CacheKey) Image(id uint) string {
	return fmt.Sprintf("image:%d", id)
}

func (CacheKey) User(id uint) string {
	return fmt.Sprintf("user:%d", id)
}

func (CacheKey) Statistics() string {
	return "statistics:all"
}
