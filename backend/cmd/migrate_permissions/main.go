package main

import (
	"fmt"
	"imagebed/models"
	"log"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func main() {
	// 直接连接数据库，不使用自动迁移
	db, err := gorm.Open(sqlite.Open("./data/imagebed.db"), &gorm.Config{})
	if err != nil {
		log.Fatal("连接数据库失败:", err)
	}

	fmt.Println("开始迁移数据库...")

	// 1. 为相册添加权限字段
	fmt.Println("1. 为相册添加权限字段...")

	// 检查列是否存在，不存在才添加
	var count int64
	db.Raw("SELECT COUNT(*) FROM pragma_table_info('albums') WHERE name='owner_id'").Scan(&count)
	if count == 0 {
		db.Exec("ALTER TABLE albums ADD COLUMN owner_id INTEGER DEFAULT 1 NOT NULL")
		fmt.Println("   ✓ 添加 owner_id 列")
	} else {
		fmt.Println("   - owner_id 列已存在")
	}

	db.Raw("SELECT COUNT(*) FROM pragma_table_info('albums') WHERE name='is_private'").Scan(&count)
	if count == 0 {
		db.Exec("ALTER TABLE albums ADD COLUMN is_private BOOLEAN DEFAULT 0")
		fmt.Println("   ✓ 添加 is_private 列")
	} else {
		fmt.Println("   - is_private 列已存在")
	}

	db.Raw("SELECT COUNT(*) FROM pragma_table_info('albums') WHERE name='is_public'").Scan(&count)
	if count == 0 {
		db.Exec("ALTER TABLE albums ADD COLUMN is_public BOOLEAN DEFAULT 1")
		fmt.Println("   ✓ 添加 is_public 列")
	} else {
		fmt.Println("   - is_public 列已存在")
	}

	db.Raw("SELECT COUNT(*) FROM pragma_table_info('albums') WHERE name='allow_share'").Scan(&count)
	if count == 0 {
		db.Exec("ALTER TABLE albums ADD COLUMN allow_share BOOLEAN DEFAULT 1")
		fmt.Println("   ✓ 添加 allow_share 列")
	} else {
		fmt.Println("   - allow_share 列已存在")
	}

	db.Raw("SELECT COUNT(*) FROM pragma_table_info('albums') WHERE name='shared_users'").Scan(&count)
	if count == 0 {
		db.Exec("ALTER TABLE albums ADD COLUMN shared_users TEXT")
		fmt.Println("   ✓ 添加 shared_users 列")
	} else {
		fmt.Println("   - shared_users 列已存在")
	}

	// 2. 为图片添加权限字段
	fmt.Println("\n2. 为图片添加权限字段...")

	db.Raw("SELECT COUNT(*) FROM pragma_table_info('images') WHERE name='owner_id'").Scan(&count)
	if count == 0 {
		db.Exec("ALTER TABLE images ADD COLUMN owner_id INTEGER DEFAULT 1 NOT NULL")
		fmt.Println("   ✓ 添加 owner_id 列")
	} else {
		fmt.Println("   - owner_id 列已存在")
	}

	db.Raw("SELECT COUNT(*) FROM pragma_table_info('images') WHERE name='is_private'").Scan(&count)
	if count == 0 {
		db.Exec("ALTER TABLE images ADD COLUMN is_private BOOLEAN DEFAULT 0")
		fmt.Println("   ✓ 添加 is_private 列")
	} else {
		fmt.Println("   - is_private 列已存在")
	}

	db.Raw("SELECT COUNT(*) FROM pragma_table_info('images') WHERE name='is_public'").Scan(&count)
	if count == 0 {
		db.Exec("ALTER TABLE images ADD COLUMN is_public BOOLEAN DEFAULT 1")
		fmt.Println("   ✓ 添加 is_public 列")
	} else {
		fmt.Println("   - is_public 列已存在")
	}

	db.Raw("SELECT COUNT(*) FROM pragma_table_info('images') WHERE name='allow_download'").Scan(&count)
	if count == 0 {
		db.Exec("ALTER TABLE images ADD COLUMN allow_download BOOLEAN DEFAULT 1")
		fmt.Println("   ✓ 添加 allow_download 列")
	} else {
		fmt.Println("   - allow_download 列已存在")
	}

	// 3. 创建索引
	fmt.Println("\n3. 创建索引...")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_albums_owner_id ON albums(owner_id)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_albums_is_private ON albums(is_private)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_images_owner_id ON images(owner_id)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_images_is_private ON images(is_private)")
	fmt.Println("   ✓ 索引创建完成")

	// 4. 更新现有数据 - 将所有现有相册和图片的所有者设置为第一个管理员
	fmt.Println("\n4. 更新现有数据所有者...")

	var adminUser models.User
	if err := db.Where("role = ?", "admin").First(&adminUser).Error; err == nil {
		result := db.Exec("UPDATE albums SET owner_id = ? WHERE owner_id IS NULL OR owner_id = 0 OR owner_id = 1", adminUser.ID)
		result2 := db.Exec("UPDATE images SET owner_id = ? WHERE owner_id IS NULL OR owner_id = 0 OR owner_id = 1", adminUser.ID)
		fmt.Printf("   ✓ 已将所有资源的所有者设置为: %s (ID: %d)\n", adminUser.Username, adminUser.ID)
		fmt.Printf("   - 更新了 %d 个相册\n", result.RowsAffected)
		fmt.Printf("   - 更新了 %d 个图片\n", result2.RowsAffected)
	} else {
		fmt.Println("   警告: 未找到管理员用户")
	}

	// 5. 删除相册的唯一索引约束（如果存在）
	fmt.Println("\n5. 移除相册名称唯一性约束...")
	db.Exec("DROP INDEX IF EXISTS idx_albums_name")
	db.Exec("DROP INDEX IF EXISTS uni_albums_name")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_albums_name ON albums(name)")
	fmt.Println("   ✓ 已移除唯一性约束，现在允许同名相册")

	fmt.Println("\n✅ 数据库迁移完成！")
	fmt.Println("\n权限系统已启用:")
	fmt.Println("  ✓ 相册和图片现在都有所有者")
	fmt.Println("  ✓ 支持私有/公开设置")
	fmt.Println("  ✓ 支持相册共享给指定用户")
	fmt.Println("  ✓ 图片可以控制下载权限")
	fmt.Println("  ✓ 允许创建同名相册（不同用户可以有相同名称的相册）")
	fmt.Println("\n注意: 重启服务器以应用新的权限系统")
}
