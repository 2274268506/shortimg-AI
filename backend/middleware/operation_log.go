package middleware

import (
	"imagebed/database"
	"imagebed/models"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// OperationLogMiddleware 操作日志记录中间件
func OperationLogMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 记录开始时间
		startTime := time.Now()

		// 处理请求
		c.Next()

		// 只记录需要记录的操作
		if shouldLogOperation(c) {
			// 计算响应时间（毫秒）
			latency := time.Since(startTime).Milliseconds()

			// 获取用户信息
			userID, _ := c.Get("userID")
			username, _ := c.Get("username")

			// 解析操作信息
			action, module := parseOperation(c)

			// 创建日志记录
			log := models.OperationLog{
				UserID:      getUintValue(userID),
				Username:    getStringValue(username),
				Action:      action,
				Module:      module,
				Description: generateDescription(c, action, module),
				Method:      c.Request.Method,
				Path:        c.Request.URL.Path,
				IP:          c.ClientIP(),
				UserAgent:   c.Request.UserAgent(),
				Status:      c.Writer.Status(),
				Latency:     latency,
			}

			// 如果有错误，记录错误信息
			if len(c.Errors) > 0 {
				log.Error = c.Errors.String()
			}

			// 异步保存日志到数据库
			go func() {
				db := database.GetDB()
				db.Create(&log)
			}()
		}
	}
}

// shouldLogOperation 判断是否需要记录操作日志
func shouldLogOperation(c *gin.Context) bool {
	path := c.Request.URL.Path
	method := c.Request.Method

	// 不记录的路径
	excludePaths := []string{
		"/health",
		"/api/auth/login",
		"/api/auth/logout",
		"/api/logs/",
		"/api/statistics/",
	}

	for _, excludePath := range excludePaths {
		if strings.HasPrefix(path, excludePath) {
			return false
		}
	}

	// 只记录修改性操作（POST、PUT、DELETE）
	if method == "POST" || method == "PUT" || method == "DELETE" {
		return true
	}

	return false
}

// parseOperation 解析操作类型和模块
func parseOperation(c *gin.Context) (action, module string) {
	path := c.Request.URL.Path
	method := c.Request.Method

	// 根据 HTTP 方法确定操作类型
	switch method {
	case "POST":
		if strings.Contains(path, "/upload") || strings.Contains(path, "/batch-upload") {
			action = "upload"
		} else {
			action = "create"
		}
	case "PUT":
		action = "update"
	case "DELETE":
		action = "delete"
	}

	// 根据路径确定模块
	switch {
	case strings.Contains(path, "/images"):
		module = "image"
	case strings.Contains(path, "/albums"):
		module = "album"
	case strings.Contains(path, "/users"):
		module = "user"
	case strings.Contains(path, "/tags"):
		module = "tag"
	default:
		module = "system"
	}

	return action, module
}

// generateDescription 生成操作描述
func generateDescription(c *gin.Context, action, module string) string {
	path := c.Request.URL.Path

	// 生成描述
	descriptions := map[string]map[string]string{
		"image": {
			"create": "创建图片",
			"upload": "上传图片",
			"update": "更新图片信息",
			"delete": "删除图片",
		},
		"album": {
			"create": "创建相册",
			"update": "更新相册信息",
			"delete": "删除相册",
		},
		"user": {
			"create": "创建用户",
			"update": "更新用户信息",
			"delete": "删除用户",
		},
		"tag": {
			"create": "创建标签",
			"update": "更新标签",
			"delete": "删除标签",
		},
	}

	if moduleDesc, ok := descriptions[module]; ok {
		if desc, ok := moduleDesc[action]; ok {
			return desc + " " + path
		}
	}

	return action + " " + module + " " + path
}

// getUintValue 安全获取 uint 值
func getUintValue(v interface{}) uint {
	if val, ok := v.(uint); ok {
		return val
	}
	return 0
}

// getStringValue 安全获取 string 值
func getStringValue(v interface{}) string {
	if val, ok := v.(string); ok {
		return val
	}
	return ""
}
