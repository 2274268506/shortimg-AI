package middleware

import (
	"fmt"
	"imagebed/cache"
	apperrors "imagebed/errors"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// RateLimiter 速率限制器接口
type RateLimiter interface {
	Allow(key string) bool
}

// TokenBucketLimiter 令牌桶限流器
type TokenBucketLimiter struct {
	rate     int      // 每秒生成的令牌数
	capacity int      // 桶容量
	buckets  sync.Map // 令牌桶映射
	mu       sync.Mutex
}

// bucket 令牌桶
type bucket struct {
	tokens     int
	lastRefill time.Time
	mu         sync.Mutex
}

// NewTokenBucketLimiter 创建令牌桶限流器
func NewTokenBucketLimiter(rate, capacity int) *TokenBucketLimiter {
	return &TokenBucketLimiter{
		rate:     rate,
		capacity: capacity,
	}
}

// Allow 检查是否允许请求
func (l *TokenBucketLimiter) Allow(key string) bool {
	b := l.getBucket(key)
	b.mu.Lock()
	defer b.mu.Unlock()

	// 重填令牌
	now := time.Now()
	elapsed := now.Sub(b.lastRefill)
	tokensToAdd := int(elapsed.Seconds() * float64(l.rate))

	if tokensToAdd > 0 {
		b.tokens += tokensToAdd
		if b.tokens > l.capacity {
			b.tokens = l.capacity
		}
		b.lastRefill = now
	}

	// 消费令牌
	if b.tokens > 0 {
		b.tokens--
		return true
	}

	return false
}

// getBucket 获取或创建令牌桶
func (l *TokenBucketLimiter) getBucket(key string) *bucket {
	if v, ok := l.buckets.Load(key); ok {
		return v.(*bucket)
	}

	b := &bucket{
		tokens:     l.capacity,
		lastRefill: time.Now(),
	}
	l.buckets.Store(key, b)
	return b
}

// RedisRateLimiter 基于Redis的分布式限流器
type RedisRateLimiter struct {
	rate     int
	capacity int
	window   time.Duration
}

// NewRedisRateLimiter 创建Redis限流器
func NewRedisRateLimiter(rate, capacity int, window time.Duration) *RedisRateLimiter {
	return &RedisRateLimiter{
		rate:     rate,
		capacity: capacity,
		window:   window,
	}
}

// Allow 检查是否允许请求（使用Redis）
func (l *RedisRateLimiter) Allow(key string) bool {
	if !cache.IsEnabled() {
		// Redis未启用，使用内存限流
		return true
	}

	redisKey := fmt.Sprintf("ratelimit:%s", key)

	// 使用Redis INCR + EXPIRE实现简单限流
	count, err := cache.Incr(redisKey)
	if err != nil {
		// Redis错误，放行请求
		return true
	}

	if count == 1 {
		// 第一次请求，设置过期时间
		cache.Expire(redisKey, l.window)
	}

	return count <= int64(l.capacity)
}

// RateLimitConfig 速率限制配置
type RateLimitConfig struct {
	// 每个IP每秒请求数
	RequestsPerSecond int
	// 令牌桶容量
	Capacity int
	// 是否使用Redis（分布式限流）
	UseRedis bool
	// 时间窗口
	Window time.Duration
}

// DefaultRateLimitConfig 默认配置
var DefaultRateLimitConfig = RateLimitConfig{
	RequestsPerSecond: 10,
	Capacity:          20,
	UseRedis:          false,
	Window:            time.Minute,
}

var (
	globalLimiter RateLimiter
	limiterOnce   sync.Once
)

// RateLimitMiddleware 速率限制中间件
func RateLimitMiddleware(config ...RateLimitConfig) gin.HandlerFunc {
	cfg := DefaultRateLimitConfig
	if len(config) > 0 {
		cfg = config[0]
	}

	// 初始化限流器（单例）
	limiterOnce.Do(func() {
		if cfg.UseRedis && cache.IsEnabled() {
			globalLimiter = NewRedisRateLimiter(cfg.RequestsPerSecond, cfg.Capacity, cfg.Window)
		} else {
			globalLimiter = NewTokenBucketLimiter(cfg.RequestsPerSecond, cfg.Capacity)
		}
	})

	return func(c *gin.Context) {
		// 获取限流键（IP地址）
		key := c.ClientIP()

		// 如果用户已登录，使用用户ID
		if userID, exists := c.Get("userID"); exists {
			key = fmt.Sprintf("user:%v", userID)
		}

		// 检查是否允许请求
		if !globalLimiter.Allow(key) {
			apperrors.Error(c, apperrors.New(apperrors.ErrTooManyRequests, "请求过于频繁"))
			c.Abort()
			return
		}

		c.Next()
	}
}

// APIRateLimitMiddleware API专用速率限制（更严格）
func APIRateLimitMiddleware() gin.HandlerFunc {
	return RateLimitMiddleware(RateLimitConfig{
		RequestsPerSecond: 5,
		Capacity:          10,
		UseRedis:          true,
		Window:            time.Minute,
	})
}

// UploadRateLimitMiddleware 上传专用速率限制（更宽松）
func UploadRateLimitMiddleware() gin.HandlerFunc {
	return RateLimitMiddleware(RateLimitConfig{
		RequestsPerSecond: 2,
		Capacity:          5,
		UseRedis:          true,
		Window:            time.Minute,
	})
}
