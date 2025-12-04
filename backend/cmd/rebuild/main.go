package main

import (
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// 旧的 Image 结构（用于读取现有数据）
type OldImage struct {
	ID            uint `gorm:"primarykey"`
	AlbumID       uint
	FileName      string
	FilePath      string
	FileSize      int64
	MimeType      string
	Width         int
	Height        int
	Thumbnail     string
	ViewCount     int64
	DownloadCount int64
	LastViewAt    *time.Time
	Tags          string
	CreatedAt     time.Time
	UpdatedAt     time.Time
	DeletedAt     gorm.DeletedAt `gorm:"index"`
}

// 新的 Image 结构（包含 UUID）
type NewImage struct {
	ID            uint   `gorm:"primarykey"`
	UUID          string `gorm:"uniqueIndex;not null"`
	AlbumID       uint
	FileName      string
	OriginalName  string
	FilePath      string
	FileSize      int64
	MimeType      string
	Width         int
	Height        int
	Thumbnail     string
	ViewCount     int64
	DownloadCount int64
	LastViewAt    *time.Time
	Tags          string
	CreatedAt     time.Time
	UpdatedAt     time.Time
	DeletedAt     gorm.DeletedAt `gorm:"index"`
}

func (OldImage) TableName() string {
	return "images"
}

func (NewImage) TableName() string {
	return "images_new"
}

func main() {
	// 连接数据库
	db, err := gorm.Open(sqlite.Open("./data/imagebed.db"), &gorm.Config{})
	if err != nil {
		log.Fatal("数据库连接失败:", err)
	}

	fmt.Println("开始数据库重建...")

	// 1. 读取所有现有图片
	var oldImages []OldImage
	if err := db.Find(&oldImages).Error; err != nil {
		log.Fatal("读取现有数据失败:", err)
	}
	fmt.Printf("读取到 %d 条现有图片记录\n", len(oldImages))

	// 2. 创建新表
	fmt.Println("创建新表结构...")
	if err := db.AutoMigrate(&NewImage{}); err != nil {
		log.Fatal("创建新表失败:", err)
	}

	// 3. 迁移数据
	fmt.Println("迁移数据到新表...")
	for _, old := range oldImages {
		newImage := NewImage{
			ID:            old.ID,
			UUID:          uuid.New().String(),
			AlbumID:       old.AlbumID,
			FileName:      old.FileName,
			OriginalName:  old.FileName, // 使用旧文件名作为原始名称
			FilePath:      old.FilePath,
			FileSize:      old.FileSize,
			MimeType:      old.MimeType,
			Width:         old.Width,
			Height:        old.Height,
			Thumbnail:     old.Thumbnail,
			ViewCount:     old.ViewCount,
			DownloadCount: old.DownloadCount,
			LastViewAt:    old.LastViewAt,
			Tags:          old.Tags,
			CreatedAt:     old.CreatedAt,
			UpdatedAt:     old.UpdatedAt,
			DeletedAt:     old.DeletedAt,
		}

		if err := db.Create(&newImage).Error; err != nil {
			log.Printf("迁移图片 ID %d 失败: %v", old.ID, err)
		} else {
			fmt.Printf("  迁移图片 ID %d -> UUID: %s\n", newImage.ID, newImage.UUID)
		}
	}

	// 4. 删除旧表，重命名新表
	fmt.Println("替换旧表...")
	db.Exec("DROP TABLE images")
	db.Exec("ALTER TABLE images_new RENAME TO images")

	// 5. 重建索引
	fmt.Println("重建索引...")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_images_album_id ON images(album_id)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_images_view_count ON images(view_count)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_images_download_count ON images(download_count)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_images_deleted_at ON images(deleted_at)")
	db.Exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_images_uuid ON images(uuid)")

	fmt.Println("\n✅ 数据库重建完成！")
	fmt.Printf("共迁移 %d 条记录\n", len(oldImages))
}
