package routes

import (
	"imagebed/config"
	"imagebed/controllers"
	"imagebed/middleware"
	v1 "imagebed/routes/v1"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

func SetupRoutes() *gin.Engine {
	// 创建不带默认中间件的 Engine
	r := gin.New()

	// 使用自定义中间件
	r.Use(middleware.RecoveryMiddleware())
	r.Use(middleware.LoggerMiddleware())
	r.Use(middleware.PrometheusMiddleware())
	r.Use(middleware.ErrorHandlerMiddleware())

	// 获取配置
	cfg := config.GetConfig()

	// 配置CORS（从配置文件读取）
	if cfg.CORSEnabled {
		r.Use(cors.New(cors.Config{
			AllowOrigins:     cfg.CORSAllowOrigins,
			AllowMethods:     cfg.CORSAllowMethods,
			AllowHeaders:     cfg.CORSAllowHeaders,
			ExposeHeaders:    []string{"Content-Length"},
			AllowCredentials: true,
			MaxAge:           time.Duration(cfg.CORSMaxAge) * time.Hour,
		}))
	}

	// 健康检查端点（无需认证）
	r.GET("/health", controllers.HealthCheck)
	r.GET("/health/detailed", controllers.DetailedHealthCheck)
	r.GET("/health/ready", controllers.ReadinessCheck)
	r.GET("/health/live", controllers.LivenessCheck)

	// Swagger API 文档
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

	// Prometheus 监控指标
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// 优雅的图片访问路径 - 使用 UUID
	r.GET("/i/:uuid", controllers.ServeImage)

	// 设置 API v1 路由（新版本）
	v1.SetupRoutes(r)

	// 保持向后兼容的旧版API路由（无版本前缀）
	// 逐步迁移到 /api/v1，这里保留以避免破坏现有客户端
	api := r.Group("/api")
	api.Use(middleware.OperationLogMiddleware()) // 添加操作日志记录中间件
	{
		// 认证相关路由（无需token）
		auth := api.Group("/auth")
		{
			auth.POST("/register", controllers.Register)
			auth.POST("/login", controllers.Login)
			auth.POST("/logout", controllers.Logout)
			auth.GET("/me", middleware.AuthMiddleware(), controllers.GetCurrentUser)
		}

		// 用户管理路由（需要管理员权限）
		users := api.Group("/users")
		users.Use(middleware.AuthMiddleware(), middleware.AdminMiddleware())
		{
			users.GET("", controllers.GetUsers)                              // 获取用户列表（支持分页、搜索）
			users.POST("", controllers.CreateUser)                           // 创建用户
			users.GET("/:id", controllers.GetUser)                           // 获取用户详情
			users.PUT("/:id", controllers.UpdateUser)                        // 更新用户信息
			users.GET("/:id/stats", controllers.GetUserStats)                // 获取用户统计
			users.GET("/:id/images", controllers.GetUserRecentImages)        // 获取用户最近图片
			users.DELETE("/:id", controllers.DeleteUser)                     // 删除用户
			users.PUT("/:id/role", controllers.UpdateUserRole)               // 更新用户角色
			users.PUT("/:id/status", controllers.UpdateUserStatus)           // 更新用户状态
			users.POST("/:id/reset-password", controllers.ResetUserPassword) // 重置用户密码
		}

		// 用户个人资料路由（需要登录）
		profile := api.Group("/profile")
		profile.Use(middleware.AuthMiddleware())
		{
			profile.PUT("", controllers.UpdateProfile)                   // 更新个人资料
			profile.POST("/change-password", controllers.ChangePassword) // 修改密码
		}

		// 相册相关路由
		albums := api.Group("/albums")
		{
			// 读取操作 - 可选认证（未登录用户可以看到公开相册）- 添加缓存
			albums.GET("", middleware.OptionalAuthMiddleware(), middleware.CacheMiddleware(5*time.Minute), controllers.GetAlbums)     // 获取相册列表(缓存5分钟)
			albums.GET("/:id", middleware.OptionalAuthMiddleware(), middleware.CacheMiddleware(10*time.Minute), controllers.GetAlbum) // 获取相册详情(缓存10分钟)

			// 写入操作 - 必须登录
			albums.POST("", middleware.AuthMiddleware(), controllers.CreateAlbum)                                         // 创建相册
			albums.PUT("/:id", middleware.AuthMiddleware(), middleware.CheckAlbumOwnership(), controllers.UpdateAlbum)    // 更新相册
			albums.DELETE("/:id", middleware.AuthMiddleware(), middleware.CheckAlbumOwnership(), controllers.DeleteAlbum) // 删除相册
		}

		// 图片相关路由
		images := api.Group("/images")
		{
			// 读取操作 - 可选认证（未登录用户可以看到公开图片）- 添加缓存
			images.GET("", middleware.OptionalAuthMiddleware(), middleware.CacheMiddleware(5*time.Minute), controllers.GetImages)     // 获取图片列表(缓存5分钟)
			images.GET("/:id", middleware.OptionalAuthMiddleware(), middleware.CacheMiddleware(10*time.Minute), controllers.GetImage) // 获取图片信息(缓存10分钟)
			images.GET("/:id/file", middleware.OptionalAuthMiddleware(), controllers.GetImageFile)                                    // 获取图片文件
			images.GET("/:id/thumbnail", middleware.OptionalAuthMiddleware(), controllers.GetImageThumbnail)                          // 获取缩略图
			images.GET("/:id/signed-url", middleware.OptionalAuthMiddleware(), controllers.GetSignedURL)                              // 获取签名URL
			images.GET("/formats", middleware.CacheMiddleware(1*time.Hour), controllers.GetSupportedFormats)                          // 获取支持的格式(缓存1小时)

			// 写入操作 - 必须登录
			images.POST("/upload", middleware.AuthMiddleware(), controllers.UploadImage)                                              // 上传图片
			images.POST("/batch-upload", middleware.AuthMiddleware(), controllers.BatchUpload)                                        // 批量上传
			images.POST("/batch-convert", middleware.AuthMiddleware(), controllers.BatchConvertFormat)                                // 批量格式转换
			images.PUT("/:id/move", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), controllers.MoveImage)             // 移动图片
			images.PUT("/:id/rename", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), controllers.RenameImage)         // 重命名
			images.PUT("/:id/file", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), controllers.UpdateImageFile)       // 更新文件
			images.PUT("/:id/tags", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), controllers.UpdateImageTags)       // 更新标签
			images.PUT("/:id/convert", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), controllers.ConvertImageFormat) // 转换格式
			images.DELETE("/:id", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), controllers.DeleteImage)             // 删除图片

			// 短链管理路由
			images.POST("/:id/shortlink", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), controllers.GenerateShortLink)    // 生成短链
			images.DELETE("/:id/shortlink", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), controllers.UnbindShortLink)    // 删除短链
			images.PUT("/:id/shortlink", middleware.AuthMiddleware(), middleware.CheckImageOwnership(), controllers.UpdateShortLinkTarget) // 转移短链
		}

		// 标签相关路由
		tags := api.Group("/tags")
		{
			tags.GET("", controllers.GetAllTags)
			tags.GET("/search", controllers.SearchImagesByTag)
		}

		// 统计相关路由
		stats := api.Group("/statistics")
		{
			stats.GET("", controllers.GetStatistics)
			stats.POST("/view/:id", controllers.RecordView)
			stats.POST("/download/:id", controllers.RecordDownload)
			stats.GET("/image/:id", controllers.GetImageStats)
		}

		// 日志相关路由（需要管理员权限）
		logs := api.Group("/logs")
		logs.Use(middleware.AuthMiddleware(), middleware.AdminMiddleware())
		{
			logs.GET("/operations", controllers.GetOperationLogs)
			logs.GET("/system", controllers.GetSystemLogs)
			logs.POST("/clear", controllers.ClearOldLogs)
		}

		// 健康检查
		api.GET("/health", func(c *gin.Context) {
			c.JSON(200, gin.H{"status": "ok"})
		})
	}

	return r
}
