package controllers

import (
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"imagebed/config"
	"imagebed/database"
	"imagebed/middleware"
	"imagebed/models"
	"imagebed/utils"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

var cfg *config.Config

func InitImageController(c *config.Config) {
	cfg = c
}

// generateImageURL 生成优雅的图片 URL
func generateImageURL(imageUUID string) string {
	// 使用 UUID 作为路径，更安全且避免中文文件名问题
	return fmt.Sprintf("/i/%s", imageUUID)
}

// UploadImage 上传图片
func UploadImage(c *gin.Context) {
	albumIDStr := c.PostForm("albumId")
	if albumIDStr == "" {
		albumIDStr = "1" // 默认相册
	}

	albumID, err := strconv.ParseUint(albumIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "相册ID无效"})
		return
	}

	// 获取当前用户
	userID, _ := c.Get("userID")
	isAdminVal, _ := c.Get("isAdmin")

	// 安全地获取 isAdmin 值
	isAdmin := false
	if isAdminVal != nil {
		isAdmin = isAdminVal.(bool)
	}

	// 检查相册是否存在并验证权限
	db := database.GetDB()
	var album models.Album
	if err := db.First(&album, albumID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "相册不存在"})
		return
	}

	// 检查是否有权限上传到此相册
	if !album.CanModify(userID.(uint), isAdmin) {
		c.JSON(http.StatusForbidden, gin.H{"error": "无权限上传到此相册"})
		return
	}

	// 获取上传的文件
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请选择文件"})
		return
	}

	// 检查文件大小
	if file.Size > cfg.MaxFileSize*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": fmt.Sprintf("文件大小不能超过 %dMB", cfg.MaxFileSize),
		})
		return
	}

	// 检查文件类型
	ext := strings.ToLower(filepath.Ext(file.Filename))
	if !utils.IsSupportedFormat(ext) {
		supported, _ := utils.GetFormatList()
		c.JSON(http.StatusBadRequest, gin.H{
			"error": fmt.Sprintf("不支持的格式，支持的格式: %v", supported),
		})
		return
	}

	// 生成唯一文件名和UUID
	imageUUID := uuid.New().String()
	newFileName := imageUUID + ext

	// 创建相册目录
	albumPath := filepath.Join(cfg.UploadPath, fmt.Sprintf("album_%d", albumID))
	os.MkdirAll(albumPath, 0755)

	// 保存文件
	filePath := filepath.Join(albumPath, newFileName)
	if err := c.SaveUploadedFile(file, filePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存文件失败"})
		return
	}

	// 获取图片尺寸
	width, height := getImageDimensions(filePath)

	// 生成缩略图
	thumbnailPath := ""
	if !utils.IsAnimatedFormat(ext) { // 动态图片不生成缩略图
		thumbDir := filepath.Join(cfg.UploadPath, "thumbnails", fmt.Sprintf("album_%d", albumID))
		os.MkdirAll(thumbDir, 0755)
		thumbnailPath = filepath.Join(thumbDir, "thumb_"+newFileName)

		// 生成缩略图（宽度300px）
		if err := utils.GenerateThumbnail(filePath, thumbnailPath, 300); err != nil {
			// 缩略图生成失败不影响主流程
			fmt.Printf("缩略图生成失败: %v\n", err)
			thumbnailPath = ""
		}
	}

	// 保存到数据库
	imageRecord := models.Image{
		UUID:          imageUUID,
		AlbumID:       uint(albumID),
		FileName:      newFileName,
		OriginalName:  file.Filename,
		FilePath:      filePath,
		FileSize:      file.Size,
		MimeType:      file.Header.Get("Content-Type"),
		Width:         width,
		Height:        height,
		Thumbnail:     thumbnailPath,
		OwnerID:       userID.(uint),   // 设置所有者
		IsPrivate:     album.IsPrivate, // 继承相册的私有性
		IsPublic:      album.IsPublic,  // 继承相册的公开性
		AllowDownload: true,            // 默认允许下载
	}

	if err := db.Create(&imageRecord).Error; err != nil {
		os.Remove(filePath) // 删除已上传的文件
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存记录失败"})
		return
	}

	// 更新相册图片数量和封面
	db.Model(&album).Update("image_count", gorm.Expr("image_count + ?", 1))
	if album.CoverImage == "" {
		db.Model(&album).Update("cover_image", generateImageURL(imageRecord.UUID))
	}

	// 构造返回的URL
	imageRecord.URL = generateImageURL(imageRecord.UUID)

	c.JSON(http.StatusCreated, gin.H{"data": imageRecord})
}

// GetImages 获取图片列表
func GetImages(c *gin.Context) {
	albumID := c.Query("albumId")
	keyword := c.Query("keyword")
	sortBy := c.Query("sortBy")
	order := c.Query("order")
	// pagination
	pageStr := c.Query("page")
	pageSizeStr := c.Query("pageSize")
	db := database.GetDB()

	// 获取用户信息
	userID, userExists := c.Get("userID")
	isAdminVal, _ := c.Get("isAdmin")

	// 安全地获取 isAdmin 值
	isAdmin := false
	if isAdminVal != nil {
		isAdmin = isAdminVal.(bool)
	}

	var images []models.Image
	query := db.Model(&models.Image{}).Preload("Owner")

	if albumID != "" {
		query = query.Where("album_id = ?", albumID)
	}

	// 权限过滤：只显示有权限访问的图片
	if !isAdmin {
		if userExists {
			uid := userID.(uint)
			query = query.Where(
				db.Where("owner_id = ?", uid).
					Or("(is_public = ? AND is_private = ?)", true, false),
			)
		} else {
			// 未登录用户只能看到公开图片
			query = query.Where("is_public = ? AND is_private = ?", true, false)
		}
	}

	// 添加搜索功能
	if keyword != "" {
		query = query.Where("file_name LIKE ? OR original_name LIKE ?", "%"+keyword+"%", "%"+keyword+"%")
	}

	// 统计总数
	var total int64
	if err := query.Count(&total).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取图片总数失败"})
		return
	}

	// parse pagination params
	page := 1
	pageSize := 24
	if pageStr != "" {
		if p, err := strconv.Atoi(pageStr); err == nil && p > 0 {
			page = p
		}
	}
	if pageSizeStr != "" {
		if ps, err := strconv.Atoi(pageSizeStr); err == nil && ps > 0 {
			pageSize = ps
		}
	}
	offset := (page - 1) * pageSize

	// 处理排序
	orderClause := "created_at DESC" // 默认按创建时间降序
	if sortBy != "" && order != "" {
		switch sortBy {
		case "time":
			if order == "asc" {
				orderClause = "created_at ASC"
			} else {
				orderClause = "created_at DESC"
			}
		case "name":
			if order == "asc" {
				orderClause = "file_name ASC"
			} else {
				orderClause = "file_name DESC"
			}
		case "size":
			if order == "asc" {
				orderClause = "file_size ASC"
			} else {
				orderClause = "file_size DESC"
			}
		case "views":
			if order == "asc" {
				orderClause = "view_count ASC"
			} else {
				orderClause = "view_count DESC"
			}
		}
	}

	if err := query.Order(orderClause).Limit(pageSize).Offset(offset).Find(&images).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取图片失败"})
		return
	}

	// 添加URL
	for i := range images {
		images[i].URL = generateImageURL(images[i].UUID)
	}

	c.JSON(http.StatusOK, gin.H{"data": images, "total": total, "page": page, "pageSize": pageSize})
}

// GetImage 获取单张图片信息
func GetImage(c *gin.Context) {
	id := c.Param("id")
	var imageRecord models.Image
	db := database.GetDB()

	if err := db.First(&imageRecord, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	imageRecord.URL = generateImageURL(imageRecord.UUID)
	c.JSON(http.StatusOK, gin.H{"data": imageRecord})
}

// GetImageFile 获取图片文件
func GetImageFile(c *gin.Context) {
	id := c.Param("id")
	var imageRecord models.Image
	db := database.GetDB()

	if err := db.First(&imageRecord, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	if _, err := os.Stat(imageRecord.FilePath); os.IsNotExist(err) {
		c.JSON(http.StatusNotFound, gin.H{"error": "文件不存在"})
		return
	}

	c.File(imageRecord.FilePath)
}

// ServeImage 优雅的图片访问路径 /i/:uuid
func ServeImage(c *gin.Context) {
	imageUUID := c.Param("uuid")

	var imageRecord models.Image
	db := database.GetDB()

	if err := db.Where("uuid = ?", imageUUID).First(&imageRecord).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	if _, err := os.Stat(imageRecord.FilePath); os.IsNotExist(err) {
		c.JSON(http.StatusNotFound, gin.H{"error": "文件不存在"})
		return
	}

	// 设置缓存头
	c.Header("Cache-Control", "public, max-age=31536000")
	c.File(imageRecord.FilePath)
}

// GetImageThumbnail 获取图片缩略图
func GetImageThumbnail(c *gin.Context) {
	id := c.Param("id")
	var imageRecord models.Image
	db := database.GetDB()

	if err := db.First(&imageRecord, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 如果有缩略图则返回缩略图，否则返回原图
	thumbnailPath := imageRecord.Thumbnail
	if thumbnailPath == "" || !fileExists(thumbnailPath) {
		thumbnailPath = imageRecord.FilePath
	}

	if _, err := os.Stat(thumbnailPath); os.IsNotExist(err) {
		c.JSON(http.StatusNotFound, gin.H{"error": "文件不存在"})
		return
	}

	c.File(thumbnailPath)
}

// DeleteImage 删除图片
func DeleteImage(c *gin.Context) {
	id := c.Param("id")
	var imageRecord models.Image
	db := database.GetDB()

	if err := db.First(&imageRecord, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 删除文件
	if err := os.Remove(imageRecord.FilePath); err != nil {
		// 记录错误但继续删除数据库记录
		fmt.Printf("删除文件失败: %v\n", err)
	}

	// 删除数据库记录
	if err := db.Delete(&imageRecord).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除失败"})
		return
	}

	// 更新相册图片数量（使用数据库表达式避免并发问题）
	db.Model(&models.Album{}).Where("id = ? AND image_count > 0", imageRecord.AlbumID).
		Update("image_count", gorm.Expr("image_count - ?", 1))

	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}

// BatchUpload 批量上传
func BatchUpload(c *gin.Context) {
	form, err := c.MultipartForm()
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "获取表单失败"})
		return
	}

	files := form.File["files"]
	albumIDStr := c.PostForm("albumId")
	if albumIDStr == "" {
		albumIDStr = "1"
	}

	var uploadedImages []models.Image
	var errors []string

	for _, file := range files {
		// 为每个文件创建一个临时context来处理
		c.Request.Header.Set("Content-Type", "multipart/form-data")

		// 这里简化处理，实际应该复用UploadImage的逻辑
		albumID, _ := strconv.ParseUint(albumIDStr, 10, 32)

		ext := strings.ToLower(filepath.Ext(file.Filename))

		if !utils.IsSupportedFormat(ext) {
			errors = append(errors, fmt.Sprintf("%s: 不支持的文件格式", file.Filename))
			continue
		}

		imageUUID := uuid.New().String()
		newFileName := imageUUID + ext
		albumPath := filepath.Join(cfg.UploadPath, fmt.Sprintf("album_%d", albumID))
		os.MkdirAll(albumPath, 0755)

		filePath := filepath.Join(albumPath, newFileName)
		if err := c.SaveUploadedFile(file, filePath); err != nil {
			errors = append(errors, fmt.Sprintf("%s: 保存失败", file.Filename))
			continue
		}

		width, height := getImageDimensions(filePath)

		// 生成缩略图
		thumbnailPath := ""
		if !utils.IsAnimatedFormat(ext) { // 动态图片不生成缩略图
			thumbDir := filepath.Join(cfg.UploadPath, "thumbnails", fmt.Sprintf("album_%d", albumID))
			os.MkdirAll(thumbDir, 0755)
			thumbnailPath = filepath.Join(thumbDir, "thumb_"+newFileName)

			// 生成缩略图（宽度300px）
			if err := utils.GenerateThumbnail(filePath, thumbnailPath, 300); err != nil {
				// 缩略图生成失败不影响主流程
				fmt.Printf("缩略图生成失败: %v\n", err)
				thumbnailPath = ""
			}
		}

		imageRecord := models.Image{
			UUID:         imageUUID,
			AlbumID:      uint(albumID),
			FileName:     newFileName,
			OriginalName: file.Filename,
			FilePath:     filePath,
			FileSize:     file.Size,
			MimeType:     file.Header.Get("Content-Type"),
			Width:        width,
			Height:       height,
			Thumbnail:    thumbnailPath,
		}

		db := database.GetDB()
		if err := db.Create(&imageRecord).Error; err != nil {
			os.Remove(filePath)
			errors = append(errors, fmt.Sprintf("%s: 保存记录失败", file.Filename))
			continue
		}

		imageRecord.URL = generateImageURL(imageRecord.UUID)
		uploadedImages = append(uploadedImages, imageRecord)
	}

	// 批量更新相册图片数量
	if len(uploadedImages) > 0 {
		albumID, _ := strconv.ParseUint(albumIDStr, 10, 32)
		db := database.GetDB()
		db.Model(&models.Album{}).Where("id = ?", albumID).
			Update("image_count", gorm.Expr("image_count + ?", len(uploadedImages)))
	}

	c.JSON(http.StatusOK, gin.H{
		"data":    uploadedImages,
		"errors":  errors,
		"total":   len(files),
		"success": len(uploadedImages),
	})
}

// getImageDimensions 获取图片尺寸
func getImageDimensions(filePath string) (int, int) {
	file, err := os.Open(filePath)
	if err != nil {
		return 0, 0
	}
	defer file.Close()

	img, _, err := image.DecodeConfig(file)
	if err != nil {
		return 0, 0
	}

	return img.Width, img.Height
}

// fileExists 检查文件是否存在
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// MoveImage 移动图片到其他相册
func MoveImage(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		AlbumID uint `json:"albumId" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	db := database.GetDB()
	var imageRecord models.Image

	if err := db.First(&imageRecord, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 检查目标相册是否存在
	var targetAlbum models.Album
	if err := db.First(&targetAlbum, req.AlbumID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "目标相册不存在"})
		return
	}

	oldAlbumID := imageRecord.AlbumID
	imageRecord.AlbumID = req.AlbumID

	if err := db.Save(&imageRecord).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "移动失败"})
		return
	}

	// 更新原相册和目标相册的图片数量
	db.Model(&models.Album{}).Where("id = ?", oldAlbumID).
		Update("image_count", gorm.Expr("image_count - 1"))
	db.Model(&models.Album{}).Where("id = ?", req.AlbumID).
		Update("image_count", gorm.Expr("image_count + 1"))

	c.JSON(http.StatusOK, gin.H{"data": imageRecord})
}

// RenameImage 重命名图片
func RenameImage(c *gin.Context) {
	id := c.Param("id")

	var req struct {
		FileName string `json:"fileName" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的请求"})
		return
	}

	db := database.GetDB()
	var imageRecord models.Image

	if err := db.First(&imageRecord, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 验证新文件名的扩展名是否与原文件相同
	oldExt := strings.ToLower(filepath.Ext(imageRecord.FileName))
	newExt := strings.ToLower(filepath.Ext(req.FileName))

	if oldExt != newExt {
		c.JSON(http.StatusBadRequest, gin.H{"error": "不能更改文件扩展名"})
		return
	}

	// 只更新 original_name，不改变实际文件名（UUID）
	imageRecord.OriginalName = req.FileName

	if err := db.Save(&imageRecord).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "重命名失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": imageRecord})
}

// UpdateImageFile 更新图片文件（用于裁剪、滤镜等编辑）
func UpdateImageFile(c *gin.Context) {
	id := c.Param("id")

	db := database.GetDB()
	var imageRecord models.Image

	if err := db.First(&imageRecord, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 获取上传的新文件
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请选择文件"})
		return
	}

	// 检查文件类型
	ext := strings.ToLower(filepath.Ext(file.Filename))
	allowedExts := map[string]bool{
		".jpg": true, ".jpeg": true, ".png": true, ".gif": true, ".webp": true,
	}
	if !allowedExts[ext] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "只支持 jpg, jpeg, png, gif, webp 格式"})
		return
	}

	// 使用原来的UUID和文件扩展名
	oldFilePath := filepath.Join(cfg.UploadPath, fmt.Sprintf("album_%d", imageRecord.AlbumID), imageRecord.FileName)

	// 如果扩展名改变，更新文件名
	newFileName := imageRecord.UUID + ext
	newFilePath := filepath.Join(cfg.UploadPath, fmt.Sprintf("album_%d", imageRecord.AlbumID), newFileName)

	// 保存新文件
	if err := c.SaveUploadedFile(file, newFilePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存文件失败"})
		return
	}

	// 如果文件名改变，删除旧文件
	if oldFilePath != newFilePath {
		os.Remove(oldFilePath)
		os.Remove(oldFilePath + ".thumb") // 删除旧缩略图
	}

	// 获取新图片的尺寸
	width, height := getImageDimensions(newFilePath)

	// 生成新缩略图
	utils.GenerateThumbnail(newFilePath, newFilePath+".thumb", 300)

	// 获取新文件大小
	fileInfo, _ := os.Stat(newFilePath)

	// 更新数据库记录
	imageRecord.FileName = newFileName
	imageRecord.FilePath = newFilePath
	imageRecord.Width = width
	imageRecord.Height = height
	imageRecord.FileSize = fileInfo.Size()

	if err := db.Save(&imageRecord).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新记录失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": imageRecord})
}

// GetSignedURL 生成带签名的图片访问URL
func GetSignedURL(c *gin.Context) {
	id := c.Param("id")
	ttlStr := c.DefaultQuery("ttl", "3600") // 默认1小时

	ttl, err := strconv.ParseInt(ttlStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的ttl参数"})
		return
	}

	db := database.GetDB()
	var imageRecord models.Image

	if err := db.First(&imageRecord, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 生成签名URL
	signedURL := middleware.GenerateSignedURL(imageRecord.UUID, time.Duration(ttl)*time.Second)
	expiresAt := time.Now().Add(time.Duration(ttl) * time.Second)

	c.JSON(http.StatusOK, gin.H{
		"url":       signedURL,
		"expires":   expiresAt.Unix(),
		"expiresAt": expiresAt.Format("2006-01-02 15:04:05"),
	})
}

// ConvertImageFormat 转换图片格式
func ConvertImageFormat(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		TargetFormat string `json:"targetFormat" binding:"required"`
		Quality      int    `json:"quality"` // 质量 1-100,仅用于JPEG
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}

	// 验证目标格式
	targetExt := "." + strings.ToLower(strings.TrimPrefix(req.TargetFormat, "."))
	if !utils.IsSupportedFormat(targetExt) {
		supported, _ := utils.GetFormatList()
		c.JSON(http.StatusBadRequest, gin.H{
			"error": fmt.Sprintf("不支持的目标格式，支持: %v", supported),
		})
		return
	}

	// 设置默认质量
	if req.Quality <= 0 || req.Quality > 100 {
		req.Quality = 90
	}

	// 查询图片
	var imageRecord models.Image
	if err := database.DB.First(&imageRecord, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 检查当前格式是否与目标格式相同
	currentExt := strings.ToLower(filepath.Ext(imageRecord.FileName))
	if currentExt == targetExt {
		c.JSON(http.StatusBadRequest, gin.H{"error": "当前格式已经是目标格式"})
		return
	}

	cfg := config.GetConfig()

	// 生成新文件名
	newFileName := strings.TrimSuffix(imageRecord.FileName, currentExt) + targetExt
	newFilePath := filepath.Join(filepath.Dir(imageRecord.FilePath), newFileName)

	// 转换格式
	if err := utils.ConvertImageFormat(imageRecord.FilePath, newFilePath, req.TargetFormat, req.Quality); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "格式转换失败: " + err.Error()})
		return
	}

	// 获取新文件大小
	fileInfo, _ := os.Stat(newFilePath)
	newFileSize := int64(0)
	if fileInfo != nil {
		newFileSize = fileInfo.Size()
	}

	// 删除旧文件
	os.Remove(imageRecord.FilePath)

	// 如果有缩略图,也需要重新生成
	if imageRecord.Thumbnail != "" {
		os.Remove(imageRecord.Thumbnail)

		// 为新格式生成缩略图(如果不是动态格式)
		if !utils.IsAnimatedFormat(targetExt) {
			thumbDir := filepath.Join(cfg.UploadPath, "thumbnails", fmt.Sprintf("album_%d", imageRecord.AlbumID))
			os.MkdirAll(thumbDir, 0755)
			newThumbnailPath := filepath.Join(thumbDir, "thumb_"+newFileName)

			if err := utils.GenerateThumbnail(newFilePath, newThumbnailPath, 300); err == nil {
				imageRecord.Thumbnail = newThumbnailPath
			}
		} else {
			imageRecord.Thumbnail = ""
		}
	}

	// 更新数据库
	imageRecord.FileName = newFileName
	imageRecord.FilePath = newFilePath
	imageRecord.FileSize = newFileSize
	imageRecord.MimeType = "image/" + strings.TrimPrefix(req.TargetFormat, ".")

	if err := database.DB.Save(&imageRecord).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新数据库失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "success",
		"data":    imageRecord,
	})
}

// BatchConvertFormat 批量转换图片格式
func BatchConvertFormat(c *gin.Context) {
	var req struct {
		ImageIDs     []uint `json:"imageIds" binding:"required"`
		TargetFormat string `json:"targetFormat" binding:"required"`
		Quality      int    `json:"quality"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误: " + err.Error()})
		return
	}

	// 验证目标格式
	targetExt := "." + strings.ToLower(strings.TrimPrefix(req.TargetFormat, "."))
	if !utils.IsSupportedFormat(targetExt) {
		supported, _ := utils.GetFormatList()
		c.JSON(http.StatusBadRequest, gin.H{
			"error": fmt.Sprintf("不支持的目标格式，支持: %v", supported),
		})
		return
	}

	// 设置默认质量
	if req.Quality <= 0 || req.Quality > 100 {
		req.Quality = 90
	}

	var convertedImages []models.Image
	var errors []string

	for _, imageID := range req.ImageIDs {
		// 查询图片
		var imageRecord models.Image
		if err := database.DB.First(&imageRecord, imageID).Error; err != nil {
			errors = append(errors, fmt.Sprintf("图片ID %d 不存在", imageID))
			continue
		}

		// 检查当前格式
		currentExt := strings.ToLower(filepath.Ext(imageRecord.FileName))
		if currentExt == targetExt {
			// 跳过已经是目标格式的图片
			continue
		}

		// 生成新文件名
		newFileName := strings.TrimSuffix(imageRecord.FileName, currentExt) + targetExt
		newFilePath := filepath.Join(filepath.Dir(imageRecord.FilePath), newFileName)

		// 转换格式
		if err := utils.ConvertImageFormat(imageRecord.FilePath, newFilePath, req.TargetFormat, req.Quality); err != nil {
			errors = append(errors, fmt.Sprintf("图片ID %d 转换失败: %v", imageID, err))
			continue
		} // 获取新文件大小
		fileInfo, _ := os.Stat(newFilePath)
		newFileSize := int64(0)
		if fileInfo != nil {
			newFileSize = fileInfo.Size()
		}

		// 删除旧文件
		os.Remove(imageRecord.FilePath)

		// 处理缩略图
		if imageRecord.Thumbnail != "" {
			os.Remove(imageRecord.Thumbnail)

			if !utils.IsAnimatedFormat(targetExt) {
				thumbDir := filepath.Join(cfg.UploadPath, "thumbnails", fmt.Sprintf("album_%d", imageRecord.AlbumID))
				os.MkdirAll(thumbDir, 0755)
				newThumbnailPath := filepath.Join(thumbDir, "thumb_"+newFileName)

				if err := utils.GenerateThumbnail(newFilePath, newThumbnailPath, 300); err == nil {
					imageRecord.Thumbnail = newThumbnailPath
				}
			} else {
				imageRecord.Thumbnail = ""
			}
		}

		// 更新数据库
		imageRecord.FileName = newFileName
		imageRecord.FilePath = newFilePath
		imageRecord.FileSize = newFileSize
		imageRecord.MimeType = "image/" + strings.TrimPrefix(req.TargetFormat, ".")

		if err := database.DB.Save(&imageRecord).Error; err != nil {
			errors = append(errors, fmt.Sprintf("图片ID %d 数据库更新失败: %v", imageID, err))
			continue
		}

		// 添加到成功列表
		convertedImages = append(convertedImages, imageRecord)
	}

	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "success",
		"data": gin.H{
			"converted": convertedImages,
			"errors":    errors,
		},
	})
}

// GetSupportedFormats 获取支持的图片格式
func GetSupportedFormats(c *gin.Context) {
	supported, animated := utils.GetFormatList()
	c.JSON(http.StatusOK, gin.H{
		"code":    200,
		"message": "success",
		"data": gin.H{
			"supported": supported,
			"animated":  animated,
		},
	})
}
