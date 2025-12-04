package controllers

import (
	"imagebed/database"
	"imagebed/models"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// UpdateImageTags 更新图片标签
func UpdateImageTags(c *gin.Context) {
	imageID := c.Param("id")
	db := database.GetDB()

	var req struct {
		Tags string `json:"tags"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	var image models.Image
	if err := db.First(&image, imageID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 更新标签
	if err := db.Model(&image).Update("tags", req.Tags).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新标签失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "标签更新成功",
		"data":    gin.H{"tags": req.Tags},
	})
}

// GetAllTags 获取所有标签（去重）
func GetAllTags(c *gin.Context) {
	db := database.GetDB()

	var images []models.Image
	db.Where("tags != ''").Select("tags").Find(&images)

	tagMap := make(map[string]int)
	for _, img := range images {
		if img.Tags != "" {
			tags := strings.Split(img.Tags, ",")
			for _, tag := range tags {
				tag = strings.TrimSpace(tag)
				if tag != "" {
					tagMap[tag]++
				}
			}
		}
	}

	// 转换为数组
	type TagInfo struct {
		Name  string `json:"name"`
		Count int    `json:"count"`
	}

	tags := make([]TagInfo, 0, len(tagMap))
	for name, count := range tagMap {
		tags = append(tags, TagInfo{
			Name:  name,
			Count: count,
		})
	}

	c.JSON(http.StatusOK, gin.H{"data": tags})
}

// SearchImagesByTag 按标签搜索图片
func SearchImagesByTag(c *gin.Context) {
	tag := c.Query("tag")
	albumID := c.Query("albumId")
	db := database.GetDB()

	query := db.Model(&models.Image{})

	if albumID != "" {
		query = query.Where("album_id = ?", albumID)
	}

	if tag != "" {
		// 使用 LIKE 查询包含该标签的图片
		query = query.Where("tags LIKE ?", "%"+tag+"%")
	}

	var images []models.Image
	if err := query.Find(&images).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "查询失败"})
		return
	}

	// 为每个图片生成 URL
	for i := range images {
		images[i].URL = generateImageURL(images[i].UUID)
	}

	c.JSON(http.StatusOK, gin.H{
		"data":  images,
		"total": len(images),
	})
}
