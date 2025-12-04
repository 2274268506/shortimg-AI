package middleware

import (
	"imagebed/database"
	"imagebed/models"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// CheckAlbumOwnership 检查相册所有权中间件
func CheckAlbumOwnership() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, _ := c.Get("userID")
		isAdmin, _ := c.Get("isAdmin")

		albumIDStr := c.Param("id")
		albumID, err := strconv.ParseUint(albumIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的相册ID"})
			c.Abort()
			return
		}

		db := database.GetDB()
		var album models.Album
		if err := db.First(&album, albumID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "相册不存在"})
			c.Abort()
			return
		}

		// 检查权限
		if !album.CanModify(userID.(uint), isAdmin.(bool)) {
			c.JSON(http.StatusForbidden, gin.H{"error": "无权限操作此相册"})
			c.Abort()
			return
		}

		// 将相册信息存储到上下文
		c.Set("album", &album)
		c.Next()
	}
}

// CheckImageOwnership 检查图片所有权中间件
func CheckImageOwnership() gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, _ := c.Get("userID")
		isAdmin, _ := c.Get("isAdmin")

		imageIDStr := c.Param("id")
		imageID, err := strconv.ParseUint(imageIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的图片ID"})
			c.Abort()
			return
		}

		db := database.GetDB()
		var image models.Image
		if err := db.First(&image, imageID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
			c.Abort()
			return
		}

		// 检查权限
		if !image.CanModify(userID.(uint), isAdmin.(bool)) {
			c.JSON(http.StatusForbidden, gin.H{"error": "无权限操作此图片"})
			c.Abort()
			return
		}

		// 将图片信息存储到上下文
		c.Set("image", &image)
		c.Next()
	}
}

// CheckAlbumAccess 检查相册访问权限中间件（只读）
func CheckAlbumAccess() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 获取用户信息（可能未登录）
		userID, exists := c.Get("userID")
		var uid uint = 0
		if exists {
			uid = userID.(uint)
		}

		isAdmin := false
		if adminVal, exists := c.Get("isAdmin"); exists {
			isAdmin = adminVal.(bool)
		}

		albumIDStr := c.Param("id")
		albumID, err := strconv.ParseUint(albumIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的相册ID"})
			c.Abort()
			return
		}

		db := database.GetDB()
		var album models.Album
		if err := db.Preload("Owner").First(&album, albumID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "相册不存在"})
			c.Abort()
			return
		}

		// 检查访问权限
		if !album.CanAccess(uid, isAdmin) {
			c.JSON(http.StatusForbidden, gin.H{"error": "无权限访问此相册"})
			c.Abort()
			return
		}

		c.Set("album", &album)
		c.Next()
	}
}

// CheckImageAccess 检查图片访问权限中间件（只读）
func CheckImageAccess() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 获取用户信息（可能未登录）
		userID, exists := c.Get("userID")
		var uid uint = 0
		if exists {
			uid = userID.(uint)
		}

		isAdmin := false
		if adminVal, exists := c.Get("isAdmin"); exists {
			isAdmin = adminVal.(bool)
		}

		imageIDStr := c.Param("id")
		imageID, err := strconv.ParseUint(imageIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "无效的图片ID"})
			c.Abort()
			return
		}

		db := database.GetDB()
		var image models.Image
		if err := db.Preload("Owner").First(&image, imageID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
			c.Abort()
			return
		}

		// 检查访问权限
		if !image.CanAccess(uid, isAdmin) {
			c.JSON(http.StatusForbidden, gin.H{"error": "无权限访问此图片"})
			c.Abort()
			return
		}

		c.Set("image", &image)
		c.Next()
	}
}
