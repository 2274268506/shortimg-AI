package main

import (
	"fmt"
	"log"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

type Image struct {
	ID       uint
	UUID     string
	FileName string
}

func main() {
	db, err := gorm.Open(sqlite.Open("./data/imagebed.db"), &gorm.Config{})
	if err != nil {
		log.Fatal(err)
	}

	var images []Image
	db.Find(&images)

	fmt.Println("数据库中的图片和 UUID:")
	for _, img := range images {
		fmt.Printf("ID: %d, UUID: %s, FileName: %s\n", img.ID, img.UUID, img.FileName)
	}
}
