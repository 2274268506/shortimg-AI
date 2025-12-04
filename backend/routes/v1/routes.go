package v1

import (
	"imagebed/controllers"
	"imagebed/middleware"
	"time"

	"github.com/gin-gonic/gin"
)

// SetupRoutes 设置 v1 版本的路由
func SetupRoutes(r *gin.Engine) {
	// API v1 路由组
	v1 := r.Group("/api/v1")
	{
		// 认证路由（无需token）
		auth := v1.Group("/auth")
		{
			auth.POST("/register", controllers.Register)
			auth.POST("/login", controllers.Login)
			auth.POST("/logout", controllers.Logout)
			auth.GET("/me", middleware.AuthMiddleware(), controllers.GetCurrentUser)
		}

		// 用户管理路由（需要管理员权限）
		users := v1.Group("/users")
		users.Use(middleware.AuthMiddleware(), middleware.AdminMiddleware())
		{
			users.GET("", controllers.GetUsers)
			users.DELETE("/:id", controllers.DeleteUser)
			users.PUT("/:id/role", controllers.UpdateUserRole)
		}

		// 相册路由（带缓存）
		albums := v1.Group("/albums")
		{
			// 读取操作 - 可选认证 - 添加缓存
			albums.GET("", middleware.OptionalAuthMiddleware(), middleware.CacheMiddleware(5*time.Minute), controllers.GetAlbums)
			albums.GET("/:id", middleware.OptionalAuthMiddleware(), middleware.CacheMiddleware(10*time.Minute), controllers.GetAlbum)

			// 写入操作 - 必须登录
			albums.POST("", middleware.AuthMiddleware(), controllers.CreateAlbum)
			albums.PUT("/:id", middleware.AuthMiddleware(), middleware.CheckAlbumOwnership(), controllers.UpdateAlbum)
			albums.DELETE("/:id", middleware.AuthMiddleware(), middleware.CheckAlbumOwnership(), controllers.DeleteAlbum)
		}

		// 图片路由（带缓存和速率限制）
		images := v1.Group("/images")
		{
			// 读取操作 - 可选认证 - 添加缓存
			images.GET("", middleware.OptionalAuthMiddleware(), middleware.CacheMiddleware(5*time.Minute), controllers.GetImages)
			images.GET("/:id", middleware.OptionalAuthMiddleware(), middleware.CacheMiddleware(10*time.Minute), controllers.GetImage)
			images.GET("/:id/file", middleware.OptionalAuthMiddleware(), controllers.GetImageFile)
			images.GET("/:id/thumbnail", middleware.OptionalAuthMiddleware(), controllers.GetImageThumbnail)
			images.GET("/:id/signed-url", middleware.OptionalAuthMiddleware(), controllers.GetSignedURL)
			images.GET("/formats", middleware.CacheMiddleware(1*time.Hour), controllers.GetSupportedFormats)

			// 上传接口使用上传速率限制
			images.POST("/upload", middleware.AuthMiddleware(), middleware.UploadRateLimitMiddleware(), controllers.UploadImage)
			images.POST("/batch-upload", middleware.AuthMiddleware(), middleware.UploadRateLimitMiddleware(), controllers.BatchUpload)

			// 修改操作 - 必须登录并拥有权限 - 使用普通速率限制
			images.POST("/batch-convert", middleware.AuthMiddleware(), middleware.APIRateLimitMiddleware(), controllers.BatchConvertFormat)
			images.PUT("/:id/move", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), middleware.RateLimitMiddleware(), controllers.MoveImage)
			images.PUT("/:id/rename", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), middleware.RateLimitMiddleware(), controllers.RenameImage)
			images.PUT("/:id/file", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), middleware.RateLimitMiddleware(), controllers.UpdateImageFile)
			images.PUT("/:id/tags", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), middleware.RateLimitMiddleware(), controllers.UpdateImageTags)
			images.PUT("/:id/convert", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), middleware.APIRateLimitMiddleware(), controllers.ConvertImageFormat)
			images.DELETE("/:id", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), middleware.RateLimitMiddleware(), controllers.DeleteImage)
		}

		// 标签路由
		tags := v1.Group("/tags")
		{
			tags.GET("", controllers.GetAllTags)
			tags.GET("/search", controllers.SearchImagesByTag)
		}

		// 统计路由（缓存5分钟）
		stats := v1.Group("/statistics")
		{
			stats.GET("", middleware.CacheMiddleware(5*time.Minute), controllers.GetStatistics)
			stats.POST("/view/:id", controllers.RecordView)
			stats.POST("/download/:id", controllers.RecordDownload)
			stats.GET("/image/:id", middleware.CacheMiddleware(5*time.Minute), controllers.GetImageStats)
		}

		// 日志路由（需要管理员权限）
		logs := v1.Group("/logs")
		logs.Use(middleware.AuthMiddleware(), middleware.AdminMiddleware())
		{
			logs.GET("/operations", controllers.GetOperationLogs)
			logs.GET("/system", controllers.GetSystemLogs)
			logs.POST("/clear", controllers.ClearOldLogs)
		}
	}
}
