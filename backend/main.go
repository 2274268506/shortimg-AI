package main

import (
	"context"
	"fmt"
	"imagebed/cache"
	"imagebed/config"
	"imagebed/controllers"
	"imagebed/database"
	"imagebed/logger"
	"imagebed/routes"
	"imagebed/storage"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

func main() {
	// 加载配置
	cfg := config.LoadConfig()

	// 设置Gin运行模式
	if cfg.ServerMode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	// 初始化日志系统
	if err := logger.InitLogger(cfg.LogPath); err != nil {
		log.Fatal("日志系统初始化失败:", err)
	}
	defer logger.Sync()
	logger.Info("日志系统初始化成功", zap.String("path", cfg.LogPath))

	// 初始化数据库
	if err := database.InitDatabase(); err != nil {
		logger.Fatal("数据库初始化失败", zap.Error(err))
	}
	logger.Info("数据库初始化成功",
		zap.String("type", cfg.DatabaseType),
		zap.String("dsn", maskSensitiveInfo(cfg.DatabaseDSN)),
	)

	// 初始化存储系统
	if err := storage.InitStorageFromMap(cfg.GetStorageConfig().(map[string]interface{})); err != nil {
		logger.Fatal("存储系统初始化失败", zap.Error(err))
	}
	logger.Info("存储系统初始化成功",
		zap.String("type", cfg.StorageType),
	)

	// 初始化Redis缓存 (可选)
	if err := cache.InitRedis(); err != nil {
		logger.Warn("Redis初始化失败，将不使用缓存", zap.Error(err))
	} else if cfg.RedisEnabled {
		defer cache.Close()
		logger.Info("Redis缓存已启用", zap.String("addr", cfg.RedisAddr))
	}

	// 初始化控制器
	controllers.InitImageController(cfg)

	// 设置路由
	r := routes.SetupRoutes()

	// 创建 HTTP 服务器
	addr := fmt.Sprintf(":%s", cfg.ServerPort)
	srv := &http.Server{
		Addr:    addr,
		Handler: r,
	}

	// 在 goroutine 中启动服务器
	go func() {
		logger.Info("服务器启动",
			zap.String("addr", fmt.Sprintf("http://localhost%s", addr)),
			zap.String("upload_path", cfg.UploadPath),
			zap.String("mode", cfg.ServerMode),
		)

		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("启动服务器失败", zap.Error(err))
		}
	}()

	// 优雅关闭
	gracefulShutdown(srv, cfg)
}

// maskSensitiveInfo 隐藏敏感信息(密码等)
func maskSensitiveInfo(dsn string) string {
	if len(dsn) > 50 {
		return dsn[:20] + "..." + dsn[len(dsn)-10:]
	}
	return dsn
}

// gracefulShutdown 优雅关闭服务器
func gracefulShutdown(srv *http.Server, cfg *config.Config) {
	// 创建信号通道
	quit := make(chan os.Signal, 1)
	// 监听中断信号 (Ctrl+C) 和终止信号
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// 阻塞等待信号
	sig := <-quit
	logger.Info("收到关闭信号，开始优雅关闭...",
		zap.String("signal", sig.String()),
	)

	// 设置超时上下文
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// 关闭 HTTP 服务器
	logger.Info("正在关闭 HTTP 服务器...")
	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("HTTP 服务器关闭失败", zap.Error(err))
	} else {
		logger.Info("HTTP 服务器已关闭")
	}

	// 关闭数据库连接
	logger.Info("正在关闭数据库连接...")
	if sqlDB, err := database.DB.DB(); err == nil {
		if err := sqlDB.Close(); err != nil {
			logger.Error("数据库关闭失败", zap.Error(err))
		} else {
			logger.Info("数据库连接已关闭")
		}
	}

	// 关闭 Redis 连接
	if cfg.RedisEnabled {
		logger.Info("正在关闭 Redis 连接...")
		if err := cache.Close(); err != nil {
			logger.Error("Redis 关闭失败", zap.Error(err))
		} else {
			logger.Info("Redis 连接已关闭")
		}
	}

	// 同步日志
	logger.Info("优雅关闭完成")
	logger.Sync()

	logger.Info("服务器已安全退出")
}
