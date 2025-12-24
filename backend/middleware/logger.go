package middleware

import (
	"fmt"
	"imagebed/logger"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// LoggerMiddleware 日志中间件
func LoggerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		// 处理请求
		c.Next()

		// 计算延迟
		latency := time.Since(start)

		// 获取状态码
		status := c.Writer.Status()

		// 获取客户端IP
		clientIP := c.ClientIP()

		// 获取用户信息（如果已登录）
		var userID uint
		var username string
		if val, exists := c.Get("user_id"); exists {
			userID = val.(uint)
		}
		if val, exists := c.Get("username"); exists {
			username = val.(string)
		}

		// 记录日志
		fields := []zap.Field{
			zap.Int("status", status),
			zap.String("method", c.Request.Method),
			zap.String("path", path),
			zap.String("query", query),
			zap.String("ip", clientIP),
			zap.Duration("latency", latency),
			zap.String("user_agent", c.Request.UserAgent()),
		}

		// 添加用户信息
		if userID > 0 {
			fields = append(fields, zap.Uint("user_id", userID))
		}
		if username != "" {
			fields = append(fields, zap.String("username", username))
		}

		// 如果有错误，记录错误
		var errorMsg string
		if len(c.Errors) > 0 {
			errorMsg = c.Errors.String()
			fields = append(fields, zap.String("errors", errorMsg))
		}

		// 根据状态码选择日志级别并记录到数据库
		if status >= 500 {
			logger.Error("Server error", fields...)
			// 记录到数据库
			logger.SaveSystemLog(logger.LevelError, "http",
				fmt.Sprintf("Server error: %s %s", c.Request.Method, path),
				errorMsg,
				map[string]interface{}{
					"status":     status,
					"method":     c.Request.Method,
					"path":       path,
					"ip":         clientIP,
					"latency_ms": latency.Milliseconds(),
				})
		} else if status >= 400 {
			logger.Warn("Client error", fields...)
			// 4xx错误也记录到数据库（仅记录重要的错误）
			if status == 401 || status == 403 || status == 404 {
				logger.SaveSystemLog(logger.LevelWarn, "http",
					fmt.Sprintf("Client error: %s %s", c.Request.Method, path),
					errorMsg,
					map[string]interface{}{
						"status": status,
						"method": c.Request.Method,
						"path":   path,
						"ip":     clientIP,
					})
			}
		} else {
			logger.Info("Request", fields...)
		}
	}
}

// RecoveryMiddleware 恢复中间件
func RecoveryMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				errorMsg := fmt.Sprintf("%v", err)
				logger.Error("Panic recovered",
					zap.Any("error", err),
					zap.String("path", c.Request.URL.Path),
					zap.String("method", c.Request.Method),
					zap.String("ip", c.ClientIP()),
				)

				// 记录panic到数据库
				logger.SaveSystemLog(logger.LevelError, "panic",
					fmt.Sprintf("Panic: %s %s", c.Request.Method, c.Request.URL.Path),
					errorMsg,
					map[string]interface{}{
						"method": c.Request.Method,
						"path":   c.Request.URL.Path,
						"ip":     c.ClientIP(),
					})

				c.AbortWithStatus(500)
			}
		}()
		c.Next()
	}
}
