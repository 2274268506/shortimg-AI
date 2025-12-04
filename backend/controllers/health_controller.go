package controllers

import (
	"imagebed/cache"
	"imagebed/database"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// HealthCheck 健康检查端点
func HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "healthy",
		"time":   time.Now().Format(time.RFC3339),
	})
}

// DetailedHealthCheck 详细健康检查（数据库、缓存等）
func DetailedHealthCheck(c *gin.Context) {
	health := gin.H{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
		"services":  gin.H{},
	}

	services := health["services"].(gin.H)
	allHealthy := true

	// 检查数据库连接
	dbHealth := checkDatabase()
	services["database"] = dbHealth
	if dbHealth["status"] != "healthy" {
		allHealthy = false
	}

	// 检查 Redis 缓存
	redisHealth := checkRedis()
	services["redis"] = redisHealth
	if redisHealth["status"] != "healthy" && redisHealth["status"] != "disabled" {
		allHealthy = false
	}

	// 设置总体状态
	if !allHealthy {
		health["status"] = "unhealthy"
		c.JSON(http.StatusServiceUnavailable, health)
		return
	}

	c.JSON(http.StatusOK, health)
}

// checkDatabase 检查数据库健康状态
func checkDatabase() gin.H {
	start := time.Now()

	// 获取数据库实例
	sqlDB, err := database.DB.DB()
	if err != nil {
		return gin.H{
			"status":  "unhealthy",
			"error":   err.Error(),
			"latency": time.Since(start).Milliseconds(),
		}
	}

	// Ping 数据库
	if err := sqlDB.Ping(); err != nil {
		return gin.H{
			"status":  "unhealthy",
			"error":   err.Error(),
			"latency": time.Since(start).Milliseconds(),
		}
	}

	// 获取数据库统计信息
	stats := sqlDB.Stats()

	return gin.H{
		"status":           "healthy",
		"latency":          time.Since(start).Milliseconds(),
		"open_connections": stats.OpenConnections,
		"in_use":           stats.InUse,
		"idle":             stats.Idle,
		"max_open":         stats.MaxOpenConnections,
	}
}

// checkRedis 检查 Redis 健康状态
func checkRedis() gin.H {
	start := time.Now()

	// 如果 Redis 未启用
	if !cache.IsEnabled() {
		return gin.H{
			"status": "disabled",
		}
	}

	// Ping Redis
	if err := cache.Ping(); err != nil {
		return gin.H{
			"status":  "unhealthy",
			"error":   err.Error(),
			"latency": time.Since(start).Milliseconds(),
		}
	}

	return gin.H{
		"status":  "healthy",
		"latency": time.Since(start).Milliseconds(),
	}
}

// ReadinessCheck 就绪检查（用于 K8s 等容器编排）
func ReadinessCheck(c *gin.Context) {
	// 检查关键服务是否就绪
	dbHealth := checkDatabase()

	if dbHealth["status"] != "healthy" {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status": "not_ready",
			"reason": "database not ready",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": "ready",
	})
}

// LivenessCheck 存活检查（用于 K8s 等容器编排）
func LivenessCheck(c *gin.Context) {
	// 简单的存活检查，只要进程在运行就返回成功
	c.JSON(http.StatusOK, gin.H{
		"status": "alive",
	})
}
