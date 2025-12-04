package main

import (
	"fmt"
	"log"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

type ColumnInfo struct {
	CID       int64
	Name      string
	Type      string
	NotNull   int64
	DfltValue *string
	PK        int64
}

func main() {
	db, err := gorm.Open(sqlite.Open("./data/imagebed.db"), &gorm.Config{})
	if err != nil {
		log.Fatal(err)
	}

	var columns []ColumnInfo
	db.Raw("PRAGMA table_info(images)").Scan(&columns)

	fmt.Println("Images 表结构:")
	for _, col := range columns {
		fmt.Printf("  %-20s %-15s notnull=%d pk=%d\n", col.Name, col.Type, col.NotNull, col.PK)
	}
}
