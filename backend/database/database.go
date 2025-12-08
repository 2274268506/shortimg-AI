package database

import (
	"fmt"
	"imagebed/config"
	"imagebed/models"
	"log"
	"time"

	"gorm.io/driver/mysql"
	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

var DB *gorm.DB

// InitDatabase 初始化数据库
func InitDatabase() error {
	cfg := config.GetConfig()

	var dialector gorm.Dialector
	var err error

	// 根据配置选择数据库驱动
	switch cfg.DatabaseType {
	case "postgres":
		dialector = postgres.Open(cfg.DatabaseDSN)
		log.Printf("使用 PostgreSQL 数据库")
	case "mysql":
		dialector = mysql.Open(cfg.DatabaseDSN)
		log.Printf("使用 MySQL 数据库")
	case "sqlite":
		dialector = sqlite.Open(cfg.DatabaseDSN)
		log.Printf("使用 SQLite 数据库: %s", cfg.DatabaseDSN)
	default:
		// 默认使用 SQLite
		dialector = sqlite.Open(cfg.DatabaseDSN)
		log.Printf("使用 SQLite 数据库 (默认): %s", cfg.DatabaseDSN)
	}

	DB, err = gorm.Open(dialector, &gorm.Config{
		DisableForeignKeyConstraintWhenMigrating: true,
	})
	if err != nil {
		return fmt.Errorf("数据库连接失败: %v", err)
	}

	// 配置数据库连接池
	sqlDB, err := DB.DB()
	if err != nil {
		return fmt.Errorf("获取数据库实例失败: %v", err)
	}

	// 设置连接池参数
	sqlDB.SetMaxIdleConns(10)                  // 最大空闲连接数
	sqlDB.SetMaxOpenConns(100)                 // 最大打开连接数
	sqlDB.SetConnMaxLifetime(time.Hour)        // 连接最大生命周期
	sqlDB.SetConnMaxIdleTime(10 * time.Minute) // 空闲连接最大生命周期

	log.Printf("数据库连接池配置: MaxIdle=%d, MaxOpen=%d, MaxLifetime=%v", 10, 100, time.Hour)

	// 自动迁移数据库表
	// 注意：对于已经手动迁移过权限字段的表，AutoMigrate会检测到并跳过
	err = DB.AutoMigrate(
		&models.User{}, // 先迁移User，因为Album和Image依赖它
		&models.Album{},
		&models.Image{},
		&models.Statistics{},
		&models.OperationLog{},
		&models.SystemLog{},
	)
	if err != nil {
		return fmt.Errorf("数据库迁移失败: %v", err)
	}

	// 创建默认管理员账号
	var userCount int64
	DB.Model(&models.User{}).Count(&userCount)
	var adminUserID uint = 1
	if userCount == 0 {
		cfg := config.GetConfig()
		adminUser := models.User{
			Username: cfg.DefaultAdminUsername,
			Email:    cfg.DefaultAdminEmail,
			Role:     "admin",
		}
		adminUser.HashPassword(cfg.DefaultAdminPassword)
		DB.Create(&adminUser)
		adminUserID = adminUser.ID
		log.Printf("✅ 已创建默认管理员账号 - 用户名: %s, 邮箱: %s", cfg.DefaultAdminUsername, cfg.DefaultAdminEmail)
		log.Printf("⚠️  请立即修改默认密码！")
	} else {
		// 获取第一个管理员用户的ID
		var adminUser models.User
		DB.Where("role = ?", "admin").First(&adminUser)
		adminUserID = adminUser.ID
	}

	// 创建默认相册
	var count int64
	DB.Model(&models.Album{}).Count(&count)
	if count == 0 {
		defaultAlbum := models.Album{
			Name:        "默认相册",
			Description: "系统默认相册",
			OwnerID:     adminUserID,
			IsPrivate:   false,
			IsPublic:    true,
			AllowShare:  true,
		}
		DB.Create(&defaultAlbum)
		log.Println("已创建默认相册")
	}

	return nil
}

// GetDB 获取数据库实例
func GetDB() *gorm.DB {
	return DB
}
