package middleware

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"imagebed/config"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// HotlinkProtection 防盗链中间件
func HotlinkProtection() gin.HandlerFunc {
	return func(c *gin.Context) {
		cfg := config.GetConfig()

		// 如果没有配置允许的域名，则跳过检查
		if len(cfg.AllowedReferers) == 0 {
			c.Next()
			return
		}

		referer := c.GetHeader("Referer")

		// 允许直接访问（无 Referer）
		if referer == "" {
			// 可以选择是否允许直接访问
			// c.Next()
			// return
			// 或者要求必须有 Referer
			c.JSON(http.StatusForbidden, gin.H{"error": "Direct access not allowed"})
			c.Abort()
			return
		}

		// 检查 Referer 是否在白名单中
		allowed := false
		for _, allowedDomain := range cfg.AllowedReferers {
			if strings.Contains(referer, allowedDomain) {
				allowed = true
				break
			}
		}

		if !allowed {
			c.JSON(http.StatusForbidden, gin.H{"error": "Access denied: invalid referer"})
			c.Abort()
			return
		}

		c.Next()
	}
}

// TokenProtection Token 验证中间件
func TokenProtection() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 获取 token 和过期时间
		token := c.Query("token")
		expiresStr := c.Query("expires")

		if token == "" || expiresStr == "" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Missing token or expires parameter"})
			c.Abort()
			return
		}

		// 验证过期时间
		expires, err := strconv.ParseInt(expiresStr, 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid expires parameter"})
			c.Abort()
			return
		}

		if time.Now().Unix() > expires {
			c.JSON(http.StatusForbidden, gin.H{"error": "Token expired"})
			c.Abort()
			return
		}

		// 验证签名
		uuid := c.Param("uuid")
		expectedToken := GenerateToken(uuid, expires)

		if token != expectedToken {
			c.JSON(http.StatusForbidden, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		c.Next()
	}
}

// GenerateToken 生成访问令牌
func GenerateToken(uuid string, expires int64) string {
	cfg := config.GetConfig()
	message := fmt.Sprintf("%s:%d", uuid, expires)
	h := hmac.New(sha256.New, []byte(cfg.SecretKey))
	h.Write([]byte(message))
	return hex.EncodeToString(h.Sum(nil))
}

// GenerateSignedURL 生成带签名的 URL
func GenerateSignedURL(uuid string, ttl time.Duration) string {
	expires := time.Now().Add(ttl).Unix()
	token := GenerateToken(uuid, expires)
	return fmt.Sprintf("/i/%s?token=%s&expires=%d", uuid, token, expires)
}
