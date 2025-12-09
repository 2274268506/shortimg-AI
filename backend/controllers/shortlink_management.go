package controllers

import (
	"imagebed/config"
	"imagebed/database"
	"imagebed/logger"
	"imagebed/models"
	"imagebed/utils"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// GenerateShortLink 为图片生成短链
// POST /api/images/:id/shortlink
func GenerateShortLink(c *gin.Context) {
	imageID := c.Param("id")
	db := database.GetDB()
	cfg := config.GetConfig()

	// 查询图片
	var imageRecord models.Image
	if err := db.First(&imageRecord, imageID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 检查是否已有短链
	if imageRecord.ShortLinkCode != "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "该图片已有短链"})
		return
	}

	// 检查短链服务是否启用
	if !cfg.ShortLinkEnabled {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "短链服务未启用"})
		return
	}

	// 生成图片路径（相对路径）
	imageRecord.URL = generateImageURL(imageRecord.UUID)
	imagePath := imageRecord.URL // 例如: /i/xxx

	logger.Info("开始生成短链",
		zap.Uint("image_id", imageRecord.ID),
		zap.String("image_path", imagePath))

	// 创建短链客户端
	shortLinkClient := utils.NewShortLinkClient(cfg.ShortLinkBaseURL, cfg.ShortLinkAPIKey)

	// 准备请求
	shortLinkReq := &utils.ShortLinkRequest{
		ImagePath: imagePath,
		Metadata: map[string]interface{}{
			"image_id":      imageRecord.ID,
			"uuid":          imageRecord.UUID,
			"album_id":      imageRecord.AlbumID,
			"original_name": imageRecord.OriginalName,
			"file_size":     imageRecord.FileSize,
		},
	}

	// 调用短链服务
	shortLink, err := shortLinkClient.CreateShortLink(shortLinkReq)
	if err != nil {
		logger.Error("生成短链失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "生成短链失败: " + err.Error()})
		return
	}

	logger.Info("短链生成成功",
		zap.String("code", shortLink.Code),
		zap.String("url", shortLink.ShortURL))

	// 构建公开访问的短链URL
	publicShortURL := shortLink.ShortURL
	if cfg.ShortLinkPublicURL != "" {
		// 使用配置的公开URL替换短链服务返回的URL
		publicShortURL = cfg.ShortLinkPublicURL + "/" + shortLink.Code
	}

	logger.Info("准备保存短链到数据库",
		zap.String("code", shortLink.Code),
		zap.String("service_url", shortLink.ShortURL),
		zap.String("public_url", publicShortURL))

	// 更新数据库
	if err := db.Model(&imageRecord).Updates(map[string]interface{}{
		"short_link_code": shortLink.Code,
		"short_link_url":  publicShortURL,
	}).Error; err != nil {
		logger.Error("更新数据库失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存短链信息失败"})
		return
	}

	// 清除缓存
	clearImageListCache(uint64(imageRecord.AlbumID))

	c.JSON(http.StatusOK, gin.H{
		"data": gin.H{
			"message":         "短链生成成功",
			"short_link_code": shortLink.Code,
			"short_link_url":  publicShortURL,
		},
	})
}

// UnbindShortLink 删除图片的短链绑定
// DELETE /api/images/:id/shortlink?permanent=true
func UnbindShortLink(c *gin.Context) {
	imageID := c.Param("id")
	permanent := c.Query("permanent") == "true" // 是否永久删除短链
	db := database.GetDB()

	// 查询图片
	var imageRecord models.Image
	if err := db.First(&imageRecord, imageID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "图片不存在"})
		return
	}

	// 检查是否有短链
	if imageRecord.ShortLinkCode == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "该图片没有短链"})
		return
	}

	logger.Info("删除短链绑定",
		zap.Uint("image_id", imageRecord.ID),
		zap.String("short_link_code", imageRecord.ShortLinkCode),
		zap.Bool("permanent", permanent))

	// 如果需要永久删除，调用短链服务删除
	if permanent {
		cfg := config.GetConfig()
		if cfg.ShortLinkEnabled {
			shortLinkClient := utils.NewShortLinkClient(cfg.ShortLinkBaseURL, cfg.ShortLinkAPIKey)
			if err := shortLinkClient.DeleteShortLink(imageRecord.ShortLinkCode); err != nil {
				logger.Warn("删除短链失败（将继续解绑）", zap.Error(err))
			} else {
				logger.Info("短链已从服务器删除", zap.String("code", imageRecord.ShortLinkCode))
			}
		}
	}

	// 清除图片的短链信息
	if err := db.Model(&imageRecord).Updates(map[string]interface{}{
		"short_link_code": "",
		"short_link_url":  "",
	}).Error; err != nil {
		logger.Error("更新数据库失败", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除短链绑定失败"})
		return
	}

	// 清除缓存
	clearImageListCache(uint64(imageRecord.AlbumID))

	c.JSON(http.StatusOK, gin.H{
		"data": gin.H{
			"message": "短链已解绑",
		},
	})
}

// UpdateShortLinkTarget 转移短链到另一张图片
// PUT /api/images/:id/shortlink
// Body: {"new_image_id": 123} 或 {"target_uuid": "xxx-xxx-xxx"}
func UpdateShortLinkTarget(c *gin.Context) {
	oldImageID := c.Param("id")
	db := database.GetDB()

	// 解析请求体
	var req struct {
		NewImageID *uint  `json:"new_image_id"` // 新图片ID（二选一）
		TargetUUID string `json:"target_uuid"`  // 新图片UUID（二选一）
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求参数错误"})
		return
	}

	// 查询原图片
	var oldImageRecord models.Image
	if err := db.First(&oldImageRecord, oldImageID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "原图片不存在"})
		return
	}

	// 检查原图片是否有短链
	if oldImageRecord.ShortLinkCode == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "原图片没有短链"})
		return
	}

	// 查询新图片
	var newImageRecord models.Image
	var err error

	if req.TargetUUID != "" {
		// 通过 UUID 查询
		err = db.Where("uuid = ?", req.TargetUUID).First(&newImageRecord).Error
	} else if req.NewImageID != nil {
		// 通过 ID 查询
		err = db.First(&newImageRecord, *req.NewImageID).Error
	} else {
		c.JSON(http.StatusBadRequest, gin.H{"error": "必须提供 new_image_id 或 target_uuid"})
		return
	}

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "目标图片不存在"})
		return
	}

	// 检查新图片是否已有短链
	if newImageRecord.ShortLinkCode != "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "目标图片已有短链，请先删除"})
		return
	}

	// 检查是否是同一张图片
	if oldImageRecord.ID == newImageRecord.ID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "不能转移到同一张图片"})
		return
	}

	logger.Info("转移短链",
		zap.Uint("old_image_id", oldImageRecord.ID),
		zap.Uint("new_image_id", newImageRecord.ID),
		zap.String("short_link_code", oldImageRecord.ShortLinkCode))

	// 调用短链服务更新目标
	cfg := config.GetConfig()
	if cfg.ShortLinkEnabled {
		shortLinkClient := utils.NewShortLinkClient(cfg.ShortLinkBaseURL, cfg.ShortLinkAPIKey)

		// 生成新图片路径（相对路径）
		newImagePath := generateImageURL(newImageRecord.UUID) // /i/new-uuid

		logger.Info("更新短链目标",
			zap.String("code", oldImageRecord.ShortLinkCode),
			zap.String("new_path", newImagePath))

		// 调用短链服务更新
		if err := shortLinkClient.UpdateShortLink(oldImageRecord.ShortLinkCode, newImagePath); err != nil {
			logger.Error("更新短链服务失败", zap.Error(err))
			c.JSON(http.StatusInternalServerError, gin.H{"error": "更新短链失败: " + err.Error()})
			return
		}
	}

	// 开启事务
	tx := db.Begin()

	// 保存短链信息（在清空之前）
	shortLinkCode := oldImageRecord.ShortLinkCode

	// 构建公开访问的短链URL
	publicShortURL := oldImageRecord.ShortLinkURL
	if cfg.ShortLinkPublicURL != "" {
		publicShortURL = cfg.ShortLinkPublicURL + "/" + shortLinkCode
	}

	// 清除原图片的短链
	if err := tx.Model(&oldImageRecord).Updates(map[string]interface{}{
		"short_link_code": "",
		"short_link_url":  "",
	}).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新原图片失败"})
		return
	}

	// 设置新图片的短链
	if err := tx.Model(&newImageRecord).Updates(map[string]interface{}{
		"short_link_code": shortLinkCode,
		"short_link_url":  publicShortURL,
	}).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新新图片失败"})
		return
	}

	// 提交事务
	tx.Commit()

	// 清除两个相册的缓存
	clearImageListCache(uint64(oldImageRecord.AlbumID))
	if oldImageRecord.AlbumID != newImageRecord.AlbumID {
		clearImageListCache(uint64(newImageRecord.AlbumID))
	}

	c.JSON(http.StatusOK, gin.H{
		"data": gin.H{
			"message":         "短链已转移",
			"short_link_code": shortLinkCode,
			"short_link_url":  publicShortURL,
			"old_image_id":    oldImageRecord.ID,
			"new_image_id":    newImageRecord.ID,
		},
	})
}
