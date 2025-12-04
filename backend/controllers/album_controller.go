package controllers

import (
	"imagebed/database"
	"imagebed/models"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// GetAlbums 获取所有相册
func GetAlbums(c *gin.Context) {
	var albums []models.Album
	db := database.GetDB()

	// 获取用户信息
	userID, userExists := c.Get("userID")
	isAdminVal, _ := c.Get("isAdmin")

	// 安全地获取 isAdmin 值
	isAdmin := false
	if isAdminVal != nil {
		isAdmin = isAdminVal.(bool)
	}

	query := db.Preload("Owner")

	// 如果不是管理员，只显示：1. 自己的相册 2. 公开的相册 3. 共享给自己的相册
	if !isAdmin {
		if userExists {
			uid := userID.(uint)
			query = query.Where(
				db.Where("owner_id = ?", uid).
					Or("(is_public = ? AND is_private = ?)", true, false).
					Or("shared_users LIKE ?", "%"+strconv.Itoa(int(uid))+"%"),
			)
		} else {
			// 未登录用户只能看到公开相册
			query = query.Where("is_public = ? AND is_private = ?", true, false)
		}
	}

	if err := query.Find(&albums).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取相册失败"})
		return
	}

	// 同步更新每个相册的图片数量
	for i := range albums {
		var count int64
		db.Model(&models.Image{}).Where("album_id = ?", albums[i].ID).Count(&count)
		albums[i].ImageCount = int(count)
	}

	c.JSON(http.StatusOK, gin.H{"data": albums})
}

// GetAlbum 获取单个相册详情
func GetAlbum(c *gin.Context) {
	id := c.Param("id")
	var album models.Album
	db := database.GetDB()

	if err := db.Preload("Images").First(&album, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "相册不存在"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": album})
}

// CreateAlbum 创建相册
func CreateAlbum(c *gin.Context) {
	var album models.Album
	if err := c.ShouldBindJSON(&album); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 设置所有者为当前用户
	userID, _ := c.Get("userID")
	album.OwnerID = userID.(uint)

	// 如果没有设置权限字段，使用默认值
	if !c.Request.URL.Query().Has("isPrivate") {
		album.IsPrivate = false
	}
	if !c.Request.URL.Query().Has("isPublic") {
		album.IsPublic = true
	}
	if !c.Request.URL.Query().Has("allowShare") {
		album.AllowShare = true
	}

	db := database.GetDB()
	if err := db.Create(&album).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建相册失败"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": album})
}

// UpdateAlbum 更新相册
func UpdateAlbum(c *gin.Context) {
	id := c.Param("id")
	var album models.Album
	db := database.GetDB()

	if err := db.First(&album, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "相册不存在"})
		return
	}

	var updateData map[string]interface{}
	if err := c.ShouldBindJSON(&updateData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	if err := db.Model(&album).Updates(updateData).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新相册失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": album})
}

// DeleteAlbum 删除相册
func DeleteAlbum(c *gin.Context) {
	id := c.Param("id")
	idInt, _ := strconv.Atoi(id)

	// 不允许删除默认相册 (ID=1)
	if idInt == 1 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "不能删除默认相册"})
		return
	}

	db := database.GetDB()
	var album models.Album

	if err := db.First(&album, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "相册不存在"})
		return
	}

	// 软删除相册
	if err := db.Delete(&album).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除相册失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}
