package controllers

import (
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"imagebed/cache"
	"imagebed/config"
	"imagebed/database"
	"imagebed/logger"
	"imagebed/middleware"
	"imagebed/models"
	"imagebed/utils"
	"imagebed/utils/imageprocessor"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"go.uber.org/zap"
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

	// 异步处理图片：压缩 + 生成缩略图 + WebP转换
	go func(path string) {
		processor := imageprocessor.NewImageProcessor(85)
		if err := processor.ProcessImage(path); err != nil {
			fmt.Printf("图片处理失败: %v\n", err)
		} else {
			fmt.Printf("图片处理成功: %s\n", path)
		}
	}(filePath)

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

	// 清除缓存，确保上传后立即可见
	clearImageListCache(uint64(albumID))

	// 构造返回的URL
	imageRecord.URL = generateImageURL(imageRecord.UUID)

	// 检查是否需要生成短链
	// 优先级：请求参数 > 相册配置
	generateShortLink := false
	// enableShortLink 可以来自 Query 参数或 Form 参数
	enableShortLinkStr := c.Query("enableShortLink")
	if enableShortLinkStr == "" {
		enableShortLinkStr = c.PostForm("enableShortLink")
	}

	if enableShortLinkStr != "" {
		// 如果请求中明确指定了是否生成短链，使用请求参数
		generateShortLink = enableShortLinkStr == "true" || enableShortLinkStr == "1"
		logger.Info("从请求参数读取短链配置", zap.String("enableShortLink", enableShortLinkStr), zap.Bool("result", generateShortLink))
	} else {
		// 否则使用相册的配置
		generateShortLink = album.EnableShortLink
		logger.Info("从相册配置读取短链配置", zap.Bool("album.EnableShortLink", album.EnableShortLink), zap.Bool("result", generateShortLink))
	}

	logger.Info("短链接生成决策", zap.Bool("generateShortLink", generateShortLink))

	// 生成短链
	if generateShortLink {
		logger.Info("开始生成短链接", zap.String("image_path", imageRecord.URL))
		shortLinkClient := utils.NewShortLinkClient(cfg.ShortLinkBaseURL, cfg.ShortLinkAPIKey)

		// 使用CDN路径而不是完整URL，让短链服务根据GeoIP分流
		imagePath := imageRecord.URL // 例如: /uploads/xxx.jpg

		shortLinkReq := &utils.ShortLinkRequest{
			ImagePath: imagePath, // 只传路径，短链服务会根据访问者IP自动选择CDN
			Metadata: map[string]interface{}{
				"image_id":      imageRecord.ID,
				"album_id":      imageRecord.AlbumID,
				"original_name": imageRecord.OriginalName,
				"file_size":     imageRecord.FileSize,
			},
		}

		if shortLink, err := shortLinkClient.CreateShortLink(shortLinkReq); err == nil {
			logger.Info("短链接生成成功", zap.String("code", shortLink.Code), zap.String("url", shortLink.ShortURL))
			// 保存短链信息到数据库
			imageRecord.ShortLinkCode = shortLink.Code
			db.Model(&imageRecord).Updates(map[string]interface{}{
				"short_link_code": shortLink.Code,
			})
			// 设置完整短链URL用于返回
			imageRecord.ShortLinkURL = shortLink.ShortURL
		} else {
			logger.Error("生成短链失败", zap.Error(err), zap.String("base_url", cfg.ShortLinkBaseURL))
		}
	}

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

	// 添加URL和短链URL
	cfg := config.GetConfig()
	for i := range images {
		images[i].URL = generateImageURL(images[i].UUID)
		// 如果短链URL为空,但有短链代码,则构造完整的短链URL
		// 优先使用数据库中已保存的短链URL
		if images[i].ShortLinkURL == "" && images[i].ShortLinkCode != "" {
			shortLinkHost := cfg.ShortLinkPublicURL
			if shortLinkHost == "" {
				shortLinkHost = cfg.ShortLinkBaseURL
			}
			if shortLinkHost == "" {
				shortLinkHost = "http://localhost"
			}
			images[i].ShortLinkURL = fmt.Sprintf("%s/%s", shortLinkHost, images[i].ShortLinkCode)
		}
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
	// 如果有短链代码，构造完整的短链URL
	if imageRecord.ShortLinkCode != "" {
		cfg := config.GetConfig()
		shortLinkHost := cfg.ShortLinkBaseURL
		if shortLinkHost == "" {
			shortLinkHost = "http://localhost"
		}
		imageRecord.ShortLinkURL = fmt.Sprintf("%s/%s", shortLinkHost, imageRecord.ShortLinkCode)
	}
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

	// 如果有短链,删除短链
	if imageRecord.ShortLinkCode != "" {
		cfg := config.GetConfig()
		if cfg.ShortLinkEnabled {
			shortLinkClient := utils.NewShortLinkClient(cfg.ShortLinkBaseURL, cfg.ShortLinkAPIKey)
			if err := shortLinkClient.DeleteShortLink(imageRecord.ShortLinkCode); err != nil {
				// 记录错误但继续删除图片
				fmt.Printf("删除短链失败 %s: %v\n", imageRecord.ShortLinkCode, err)
			} else {
				fmt.Printf("✅ 已删除短链: %s\n", imageRecord.ShortLinkCode)
			}
		}
	}

	// 删除数据库记录
	if err := db.Delete(&imageRecord).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除失败"})
		return
	}

	// 更新相册图片数量（使用数据库表达式避免并发问题）
	db.Model(&models.Album{}).Where("id = ? AND image_count > 0", imageRecord.AlbumID).
		Update("image_count", gorm.Expr("image_count - ?", 1))

	// 清除缓存，确保删除后立即生效
	clearImageListCache(uint64(imageRecord.AlbumID))

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

	albumID, _ := strconv.ParseUint(albumIDStr, 10, 32)

	// 获取相册信息，检查短链配置
	db := database.GetDB()
	var album models.Album
	if err := db.First(&album, albumID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "相册不存在"})
		return
	}

	// 获取当前用户信息
	userID, _ := c.Get("userID")

	// 检查是否需要生成短链
	generateShortLink := false
	enableShortLinkStr := c.PostForm("enableShortLink")
	fmt.Printf("========== 批量上传调试 ==========\n")
	fmt.Printf("请求参数 enableShortLink: %s\n", enableShortLinkStr)
	fmt.Printf("相册 EnableShortLink: %v\n", album.EnableShortLink)

	if enableShortLinkStr != "" {
		generateShortLink = enableShortLinkStr == "true" || enableShortLinkStr == "1"
		fmt.Printf("使用请求参数，generateShortLink: %v\n", generateShortLink)
	} else {
		generateShortLink = album.EnableShortLink
		fmt.Printf("使用相册配置，generateShortLink: %v\n", generateShortLink)
	}

	var uploadedImages []models.Image
	var errors []string
	var shortLinkImages []utils.ImageInfo // 用于批量生成短链

	for _, file := range files {
		// 为每个文件创建一个临时context来处理
		c.Request.Header.Set("Content-Type", "multipart/form-data")

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
			OwnerID:       userID.(uint),
			IsPrivate:     album.IsPrivate,
			IsPublic:      album.IsPublic,
			AllowDownload: true,
		}

		if err := db.Create(&imageRecord).Error; err != nil {
			os.Remove(filePath)
			errors = append(errors, fmt.Sprintf("%s: 保存记录失败", file.Filename))
			continue
		}

		imageRecord.URL = generateImageURL(imageRecord.UUID)
		uploadedImages = append(uploadedImages, imageRecord)

		// 准备短链信息（使用CDN路径）
		if generateShortLink {
			imagePath := imageRecord.URL // 只使用路径，如 /uploads/xxx.jpg
			shortLinkImages = append(shortLinkImages, utils.ImageInfo{
				ImagePath: imagePath, // 传递路径而不是完整URL
				Metadata: map[string]interface{}{
					"image_id":      imageRecord.ID,
					"album_id":      imageRecord.AlbumID,
					"original_name": imageRecord.OriginalName,
					"file_size":     imageRecord.FileSize,
				},
			})
		}
	}

	// 批量生成短链
	fmt.Printf("准备生成短链: generateShortLink=%v, shortLinkImages数量=%d\n", generateShortLink, len(shortLinkImages))
	if generateShortLink && len(shortLinkImages) > 0 {
		fmt.Printf("开始批量生成短链...\n")
		shortLinkClient := utils.NewShortLinkClient(cfg.ShortLinkBaseURL, cfg.ShortLinkAPIKey)
		batchReq := &utils.BatchShortLinkRequest{
			Images: shortLinkImages,
		}

		if batchResp, err := shortLinkClient.BatchCreateShortLinks(batchReq); err == nil {
			fmt.Printf("批量生成短链成功，返回结果数量: %d\n", len(batchResp.Results))

			// 确定公开访问 URL:如果配置了 PUBLIC_URL 则用它,否则用 BASE_URL
			publicBaseURL := cfg.ShortLinkPublicURL
			if publicBaseURL == "" {
				publicBaseURL = cfg.ShortLinkBaseURL
			}

			// 更新图片记录的短链信息
			for i, result := range batchResp.Results {
				fmt.Printf("处理结果 %d: Success=%v, Code=%s\n", i, result.Success, result.Code)
				if result.Success && i < len(uploadedImages) {
					// 使用公开访问 URL 拼接完整短链
					shortLinkURL := publicBaseURL + "/" + result.Code

					fmt.Printf("更新图片 %d 短链: code=%s, url=%s\n",
						uploadedImages[i].ID, result.Code, shortLinkURL)

					// 保存短链代码和 URL
					updateResult := db.Model(&uploadedImages[i]).Updates(map[string]interface{}{
						"short_link_code": result.Code,
						"short_link_url":  shortLinkURL,
					})
					if updateResult.Error != nil {
						fmt.Printf("❌ 更新数据库失败: %v\n", updateResult.Error)
					} else {
						fmt.Printf("✅ 数据库更新成功，影响行数: %d\n", updateResult.RowsAffected)
						// 更新成功后,同步更新内存对象
						uploadedImages[i].ShortLinkCode = result.Code
						uploadedImages[i].ShortLinkURL = shortLinkURL
					}
				} else {
					fmt.Printf("跳过更新: Success=%v, 索引=%d, uploadedImages数量=%d\n",
						result.Success, i, len(uploadedImages))
				}
			}
		} else {
			fmt.Printf("批量生成短链失败: %v\n", err)
		}
	} else {
		fmt.Printf("跳过短链生成: generateShortLink=%v, shortLinkImages数量=%d\n", generateShortLink, len(shortLinkImages))
	}

	// 批量更新相册图片数量
	if len(uploadedImages) > 0 {
		db.Model(&models.Album{}).Where("id = ?", albumID).
			Update("image_count", gorm.Expr("image_count + ?", len(uploadedImages)))

		// 清除图片列表相关的缓存，确保上传后立即可见
		clearImageListCache(albumID)

		// 重新查询图片数据,确保返回最新的短链信息
		var imageIDs []uint
		for _, img := range uploadedImages {
			imageIDs = append(imageIDs, img.ID)
		}
		if len(imageIDs) > 0 {
			// 清空原数组，避免数据混乱
			uploadedImages = []models.Image{}
			queryResult := db.Where("id IN ?", imageIDs).Find(&uploadedImages)
			fmt.Printf("重新查询了 %d 张图片的最新数据，查询影响行数: %d\n", len(uploadedImages), queryResult.RowsAffected)
			// 打印所有图片的短链信息用于调试
			for idx, img := range uploadedImages {
				fmt.Printf("🔍 [%d] 返回给前端的图片: ID=%d, ShortLinkCode=%s, ShortLinkURL=%s\n",
					idx, img.ID, img.ShortLinkCode, img.ShortLinkURL)
			}
		}
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

// clearImageListCache 清除图片列表相关的缓存
func clearImageListCache(albumID uint64) {
	// 由于缓存键使用MD5哈希，无法通过模式精确匹配
	// 这里清除所有API缓存以确保数据一致性
	// 注意：这会影响所有用户的缓存，但确保了实时性

	pattern := "cache:*"
	if err := cache.DeletePattern(pattern); err != nil {
		fmt.Printf("清除缓存失败: %v\n", err)
	} else {
		fmt.Printf("已清除所有API缓存（相册 %d 有更新）\n", albumID)
	}
}
