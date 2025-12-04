package database

import (
	"fmt"
	"imagebed/models"
	"log"
	"time"

	"gorm.io/gorm"
)

// OptimizeDatabase 优化数据库性能
func OptimizeDatabase(db *gorm.DB) error {
	log.Println("🔧 开始优化数据库...")

	// 1. 创建额外的索引
	if err := createAdditionalIndexes(db); err != nil {
		return err
	}

	// 2. 分析表（仅适用于 PostgreSQL 和 MySQL）
	if err := analyzeTables(db); err != nil {
		log.Printf("⚠️  表分析失败: %v", err)
		// 不返回错误，因为某些数据库不支持 ANALYZE
	}

	log.Println("✅ 数据库优化完成")
	return nil
}

// createAdditionalIndexes 创建额外的索引
func createAdditionalIndexes(db *gorm.DB) error {
	type Index struct {
		Table   string
		Name    string
		Columns []string
	}

	// 定义需要创建的索引
	indexes := []Index{
		// Users 表索引
		{
			Table:   "users",
			Name:    "idx_users_email",
			Columns: []string{"email"},
		},
		{
			Table:   "users",
			Name:    "idx_users_username",
			Columns: []string{"username"},
		},
		{
			Table:   "users",
			Name:    "idx_users_role",
			Columns: []string{"role"},
		},

		// Images 表索引
		{
			Table:   "images",
			Name:    "idx_images_uuid",
			Columns: []string{"uuid"},
		},
		{
			Table:   "images",
			Name:    "idx_images_album_id",
			Columns: []string{"album_id"},
		},
		{
			Table:   "images",
			Name:    "idx_images_owner_id",
			Columns: []string{"owner_id"},
		},
		{
			Table:   "images",
			Name:    "idx_images_created_at",
			Columns: []string{"created_at"},
		},
		{
			Table:   "images",
			Name:    "idx_images_view_count",
			Columns: []string{"view_count"},
		},
		{
			Table:   "images",
			Name:    "idx_images_is_private",
			Columns: []string{"is_private"},
		},
		// 复合索引：查询某个相册的公开图片
		{
			Table:   "images",
			Name:    "idx_images_album_public",
			Columns: []string{"album_id", "is_private"},
		},
		// 复合索引：查询某个用户的图片
		{
			Table:   "images",
			Name:    "idx_images_owner_created",
			Columns: []string{"owner_id", "created_at"},
		},

		// Albums 表索引
		{
			Table:   "albums",
			Name:    "idx_albums_owner_id",
			Columns: []string{"owner_id"},
		},
		{
			Table:   "albums",
			Name:    "idx_albums_is_public",
			Columns: []string{"is_public"},
		},
		{
			Table:   "albums",
			Name:    "idx_albums_created_at",
			Columns: []string{"created_at"},
		},

		// Statistics 表索引
		{
			Table:   "statistics",
			Name:    "idx_statistics_date",
			Columns: []string{"date"},
		},

		// OperationLogs 表索引
		{
			Table:   "operation_logs",
			Name:    "idx_operation_logs_user_id",
			Columns: []string{"user_id"},
		},
		{
			Table:   "operation_logs",
			Name:    "idx_operation_logs_action",
			Columns: []string{"action"},
		},
		{
			Table:   "operation_logs",
			Name:    "idx_operation_logs_module",
			Columns: []string{"module"},
		},
		{
			Table:   "operation_logs",
			Name:    "idx_operation_logs_created_at",
			Columns: []string{"created_at"},
		},
	}

	// 创建索引
	for _, idx := range indexes {
		if err := createIndexIfNotExists(db, idx.Table, idx.Name, idx.Columns); err != nil {
			log.Printf("⚠️  创建索引失败 %s.%s: %v", idx.Table, idx.Name, err)
			// 继续创建其他索引
		}
	}

	return nil
}

// createIndexIfNotExists 如果索引不存在则创建
func createIndexIfNotExists(db *gorm.DB, table, name string, columns []string) error {
	// 检查索引是否存在
	var exists bool

	// 获取数据库类型
	dbType := db.Config.Dialector.Name()

	switch dbType {
	case "sqlite":
		// SQLite 使用 sqlite_master 表检查索引
		query := "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name=?"
		db.Raw(query, name).Scan(&exists)
	case "postgres":
		// PostgreSQL 使用 pg_indexes
		query := "SELECT EXISTS(SELECT 1 FROM pg_indexes WHERE indexname = ?)"
		db.Raw(query, name).Scan(&exists)
	case "mysql":
		// MySQL 使用 INFORMATION_SCHEMA
		query := "SELECT COUNT(*) > 0 FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?"
		db.Raw(query, table, name).Scan(&exists)
	default:
		// 默认尝试创建（如果存在会失败但不影响）
		exists = false
	}

	if exists {
		log.Printf("✓ 索引已存在: %s.%s", table, name)
		return nil
	}

	// 构建 CREATE INDEX 语句
	columnList := ""
	for i, col := range columns {
		if i > 0 {
			columnList += ", "
		}
		columnList += col
	}

	sql := fmt.Sprintf("CREATE INDEX IF NOT EXISTS %s ON %s (%s)", name, table, columnList)

	if err := db.Exec(sql).Error; err != nil {
		return err
	}

	log.Printf("✓ 创建索引: %s.%s (%s)", table, name, columnList)
	return nil
}

// analyzeTables 分析表以优化查询计划
func analyzeTables(db *gorm.DB) error {
	tables := []string{
		"users",
		"albums",
		"images",
		"statistics",
		"operation_logs",
		"system_logs",
	}

	dbType := db.Config.Dialector.Name()

	for _, table := range tables {
		var sql string
		switch dbType {
		case "postgres":
			sql = fmt.Sprintf("ANALYZE %s", table)
		case "mysql":
			sql = fmt.Sprintf("ANALYZE TABLE %s", table)
		default:
			// SQLite 使用 ANALYZE
			sql = "ANALYZE"
		}

		if err := db.Exec(sql).Error; err != nil {
			return err
		}
		log.Printf("✓ 分析表: %s", table)
	}

	return nil
}

// PreloadOptions 预加载选项
type PreloadOptions struct {
	LoadAlbum bool // 加载相册信息
	LoadOwner bool // 加载所有者信息
	LoadStats bool // 加载统计信息
}

// ApplyPreload 应用预加载选项
func ApplyPreload(db *gorm.DB, opts PreloadOptions) *gorm.DB {
	if opts.LoadAlbum {
		db = db.Preload("Album")
	}
	if opts.LoadOwner {
		db = db.Preload("Owner", func(db *gorm.DB) *gorm.DB {
			// 只加载必要的字段，不加载密码
			return db.Select("id", "username", "email", "role")
		})
	}
	return db
}

// CleanupOldLogs 清理旧日志
func CleanupOldLogs(db *gorm.DB, daysToKeep int) error {
	cutoffDate := time.Now().AddDate(0, 0, -daysToKeep)

	// 清理操作日志
	if err := db.Where("created_at < ?", cutoffDate).Delete(&models.OperationLog{}).Error; err != nil {
		return fmt.Errorf("清理操作日志失败: %v", err)
	}

	// 清理系统日志
	if err := db.Where("created_at < ?", cutoffDate).Delete(&models.SystemLog{}).Error; err != nil {
		return fmt.Errorf("清理系统日志失败: %v", err)
	}

	log.Printf("✓ 已清理 %d 天前的日志", daysToKeep)
	return nil
}

// VacuumDatabase 压缩数据库（仅 SQLite）
func VacuumDatabase(db *gorm.DB) error {
	dbType := db.Config.Dialector.Name()
	if dbType != "sqlite" {
		return fmt.Errorf("VACUUM 仅支持 SQLite 数据库")
	}

	if err := db.Exec("VACUUM").Error; err != nil {
		return err
	}

	log.Println("✓ 数据库压缩完成")
	return nil
}
