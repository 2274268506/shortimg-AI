package controllers

import (
	"imagebed/database"
	"imagebed/models"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// GetOperationLogs 获取操作日志列表
func GetOperationLogs(c *gin.Context) {
	db := database.GetDB()

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	module := c.Query("module")
	action := c.Query("action")
	userID := c.Query("user_id")

	offset := (page - 1) * pageSize

	query := db.Model(&models.OperationLog{})

	// 筛选条件
	if module != "" {
		query = query.Where("module = ?", module)
	}
	if action != "" {
		query = query.Where("action = ?", action)
	}
	if userID != "" {
		query = query.Where("user_id = ?", userID)
	}

	// 获取总数
	var total int64
	query.Count(&total)

	// 获取日志列表
	var logs []models.OperationLog
	if err := query.Order("created_at DESC").
		Offset(offset).
		Limit(pageSize).
		Find(&logs).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取日志失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data": logs,
		"pagination": gin.H{
			"total":     total,
			"page":      page,
			"page_size": pageSize,
		},
	})
}

// GetSystemLogs 获取系统日志列表
func GetSystemLogs(c *gin.Context) {
	db := database.GetDB()

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("pageSize", "20"))
	level := c.Query("level")
	module := c.Query("module")

	offset := (page - 1) * pageSize

	query := db.Model(&models.SystemLog{})

	// 筛选条件
	if level != "" {
		query = query.Where("level = ?", level)
	}
	if module != "" {
		query = query.Where("module = ?", module)
	}

	// 获取总数
	var total int64
	query.Count(&total)

	// 获取日志列表
	var logs []models.SystemLog
	if err := query.Order("created_at DESC").
		Offset(offset).
		Limit(pageSize).
		Find(&logs).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取系统日志失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data": logs,
		"pagination": gin.H{
			"total":     total,
			"page":      page,
			"page_size": pageSize,
		},
	})
}

// ClearOldLogs 清理旧日志
func ClearOldLogs(c *gin.Context) {
	db := database.GetDB()

	days, _ := strconv.Atoi(c.DefaultQuery("days", "90"))

	// 删除90天前的操作日志
	if err := db.Where("created_at < DATE('now', '-? days')", days).
		Delete(&models.OperationLog{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "清理操作日志失败"})
		return
	}

	// 删除90天前的系统日志
	if err := db.Where("created_at < DATE('now', '-? days')", days).
		Delete(&models.SystemLog{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "清理系统日志失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "日志清理成功"})
}
