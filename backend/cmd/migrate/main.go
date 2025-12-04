package main

import (
	"fmt"
	"log"

	"github.com/google/uuid"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

type Image struct {
	ID           uint   `gorm:"primarykey"`
	UUID         string `gorm:"uniqueIndex"`
	FileName     string
	OriginalName string
}

func main() {
	// 连接数据库 - 使用相对于项目根目录的路径
	db, err := gorm.Open(sqlite.Open("../../data/imagebed.db"), &gorm.Config{})
	if err != nil {
		log.Fatal("数据库连接失败:", err)
	}

	fmt.Println("开始数据库迁移...")

	// 1. 添加新字段（如果不存在）
	if !db.Migrator().HasColumn(&Image{}, "uuid") {
		fmt.Println("添加 uuid 字段...")
		db.Exec("ALTER TABLE images ADD COLUMN uuid VARCHAR(36)")
	}

	if !db.Migrator().HasColumn(&Image{}, "original_name") {
		fmt.Println("添加 original_name 字段...")
		db.Exec("ALTER TABLE images ADD COLUMN original_name VARCHAR(255)")
	}

	// 2. 为现有记录生成 UUID
	fmt.Println("为现有图片生成 UUID...")
	var images []Image
	db.Find(&images)

	count := 0
	for _, img := range images {
		if img.UUID == "" {
			newUUID := uuid.New().String()
			originalName := img.FileName
			if img.OriginalName != "" {
				originalName = img.OriginalName
			}

			db.Model(&Image{}).Where("id = ?", img.ID).Updates(map[string]interface{}{
				"uuid":          newUUID,
				"original_name": originalName,
			})
			count++
			fmt.Printf("  图片 ID %d -> UUID: %s\n", img.ID, newUUID)
		}
	}

	fmt.Printf("\n迁移完成！共更新 %d 条记录\n", count)

	// 3. 创建索引
	fmt.Println("创建 UUID 唯一索引...")
	db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_images_uuid ON images(uuid)")

	fmt.Println("\n✅ 所有迁移步骤完成!")
}
