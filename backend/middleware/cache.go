package middleware

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"imagebed/cache"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// CacheMiddleware 缓存中间件
func CacheMiddleware(duration time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 只缓存 GET 请求
		if c.Request.Method != http.MethodGet {
			c.Next()
			return
		}

		// 如果缓存未启用，直接跳过
		if !cache.IsEnabled() {
			c.Next()
			return
		}

		// 生成缓存键
		cacheKey := generateCacheKey(c)

		// 尝试从缓存获取
		var cachedResponse CachedResponse
		if err := cache.Get(cacheKey, &cachedResponse); err == nil {
			// 缓存命中，直接返回
			c.Header("X-Cache", "HIT")
			c.Header("Content-Type", cachedResponse.ContentType)

			for key, values := range cachedResponse.Headers {
				for _, value := range values {
					c.Header(key, value)
				}
			}

			c.Data(cachedResponse.Status, cachedResponse.ContentType, cachedResponse.Body)
			c.Abort()
			return
		}

		// 缓存未命中，设置标记
		c.Header("X-Cache", "MISS")

		// 创建响应写入器来捕获响应
		blw := &bodyLogWriter{body: []byte{}, ResponseWriter: c.Writer}
		c.Writer = blw

		// 继续处理请求
		c.Next()

		// 如果响应成功，缓存响应
		if c.Writer.Status() == http.StatusOK {
			cachedResp := CachedResponse{
				Status:      c.Writer.Status(),
				ContentType: c.Writer.Header().Get("Content-Type"),
				Headers:     c.Writer.Header(),
				Body:        blw.body,
			}

			// 保存到缓存
			cache.Set(cacheKey, cachedResp, duration)
		}
	}
}

// CachedResponse 缓存的响应结构
type CachedResponse struct {
	Status      int
	ContentType string
	Headers     http.Header
	Body        []byte
}

// bodyLogWriter 响应写入器，用于捕获响应体
type bodyLogWriter struct {
	gin.ResponseWriter
	body []byte
}

func (w *bodyLogWriter) Write(b []byte) (int, error) {
	w.body = append(w.body, b...)
	return w.ResponseWriter.Write(b)
}

// generateCacheKey 生成缓存键
func generateCacheKey(c *gin.Context) string {
	// 使用 URL、查询参数和用户ID生成唯一键
	userID := ""
	if user, exists := c.Get("user"); exists {
		if u, ok := user.(map[string]interface{}); ok {
			if id, ok := u["id"]; ok {
				userID = fmt.Sprintf("%v", id)
			}
		}
	}

	key := fmt.Sprintf("%s:%s:%s:%s",
		c.Request.Method,
		c.Request.URL.Path,
		c.Request.URL.RawQuery,
		userID,
	)

	// MD5 哈希以缩短键长度
	hash := md5.Sum([]byte(key))
	return "cache:" + hex.EncodeToString(hash[:])
}

// ClearCacheByPattern 清除匹配模式的缓存
func ClearCacheByPattern(pattern string) error {
	if !cache.IsEnabled() {
		return nil
	}
	return cache.DeletePattern(pattern)
}

// ClearUserCache 清除特定用户的缓存
func ClearUserCache(userID string) error {
	pattern := fmt.Sprintf("cache:*:%s", userID)
	return ClearCacheByPattern(pattern)
}
