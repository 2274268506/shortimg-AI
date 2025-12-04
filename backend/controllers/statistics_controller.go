package controllers

import (
	"imagebed/database"
	"imagebed/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// GetStatistics 获取统计数据
func GetStatistics(c *gin.Context) {
	db := database.GetDB()

	// 获取总体统计
	var totalImages int64
	var totalSize int64
	var totalViews int64
	var totalDownloads int64

	db.Model(&models.Image{}).Count(&totalImages)
	db.Model(&models.Image{}).Select("COALESCE(SUM(file_size), 0)").Scan(&totalSize)
	db.Model(&models.Image{}).Select("COALESCE(SUM(view_count), 0)").Scan(&totalViews)
	db.Model(&models.Image{}).Select("COALESCE(SUM(download_count), 0)").Scan(&totalDownloads)

	// 获取今日统计
	today := time.Now().Format("2006-01-02")
	var todayStats models.Statistics
	db.Where("date = ?", today).FirstOrCreate(&todayStats, models.Statistics{Date: today})

	// 获取最近7天统计
	sevenDaysAgo := time.Now().AddDate(0, 0, -7).Format("2006-01-02")
	var recentStats []models.Statistics
	db.Where("date >= ?", sevenDaysAgo).Order("date DESC").Find(&recentStats)

	// 获取最近30天统计
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30).Format("2006-01-02")
	var monthStats []models.Statistics
	db.Where("date >= ?", thirtyDaysAgo).Order("date DESC").Find(&monthStats)

	// 获取热门图片（访问最多的前10张）
	var topImages []models.Image
	db.Order("view_count DESC").Limit(10).Find(&topImages)

	// 为图片生成 URL
	for i := range topImages {
		topImages[i].URL = "/i/" + topImages[i].UUID
	}

	// 获取相册统计
	var albums []models.Album
	db.Find(&albums)
	albumStats := make([]map[string]interface{}, 0)
	for _, album := range albums {
		var albumSize int64
		var albumViews int64
		db.Model(&models.Image{}).Where("album_id = ?", album.ID).Select("COALESCE(SUM(file_size), 0)").Scan(&albumSize)
		db.Model(&models.Image{}).Where("album_id = ?", album.ID).Select("COALESCE(SUM(view_count), 0)").Scan(&albumViews)

		albumStats = append(albumStats, map[string]interface{}{
			"id":         album.ID,
			"name":       album.Name,
			"imageCount": album.ImageCount,
			"totalSize":  albumSize,
			"totalViews": albumViews,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"data": gin.H{
			"overview": gin.H{
				"totalImages":    totalImages,
				"totalSize":      totalSize,
				"totalViews":     totalViews,
				"totalDownloads": totalDownloads,
			},
			"today": gin.H{
				"views":     todayStats.TotalViews,
				"downloads": todayStats.TotalDownloads,
				"uploads":   todayStats.TotalUploads,
				"traffic":   todayStats.TotalTraffic,
			},
			"recent7Days":  recentStats,
			"recent30Days": monthStats,
			"topImages":    topImages,
			"albumStats":   albumStats,
		},
	})
}

// RecordView 记录图片访问
func RecordView(c *gin.Context) {
	imageID := c.Param("id")
	db := database.GetDB()

	var image models.Image
	if err := db.First(&image, imageID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 更新访问次数
	now := time.Now()
	db.Model(&image).Updates(map[string]interface{}{
		"view_count":   gorm.Expr("view_count + ?", 1),
		"last_view_at": now,
	})

	// 更新今日统计
	today := now.Format("2006-01-02")
	var stats models.Statistics
	db.Where("date = ?", today).FirstOrCreate(&stats, models.Statistics{Date: today})
	db.Model(&stats).Update("total_views", gorm.Expr("total_views + ?", 1))

	c.JSON(http.StatusOK, gin.H{"message": "记录成功"})
}

// RecordDownload 记录图片下载
func RecordDownload(c *gin.Context) {
	imageID := c.Param("id")
	db := database.GetDB()

	var image models.Image
	if err := db.First(&image, imageID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 更新下载次数
	db.Model(&image).Update("download_count", gorm.Expr("download_count + ?", 1))

	// 更新今日统计
	today := time.Now().Format("2006-01-02")
	var stats models.Statistics
	db.Where("date = ?", today).FirstOrCreate(&stats, models.Statistics{Date: today})
	db.Model(&stats).Updates(map[string]interface{}{
		"total_downloads": gorm.Expr("total_downloads + ?", 1),
		"total_traffic":   gorm.Expr("total_traffic + ?", image.FileSize),
	})

	c.JSON(http.StatusOK, gin.H{"message": "记录成功"})
}

// GetImageStats 获取单张图片的统计信息
func GetImageStats(c *gin.Context) {
	imageID := c.Param("id")
	db := database.GetDB()

	var image models.Image
	if err := db.First(&image, imageID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data": gin.H{
			"viewCount":     image.ViewCount,
			"downloadCount": image.DownloadCount,
			"lastViewAt":    image.LastViewAt,
		},
	})
}
