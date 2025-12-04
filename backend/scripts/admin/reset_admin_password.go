package main

import (
	"fmt"
	"imagebed/config"
	"imagebed/database"
	"imagebed/models"
	"log"

	"golang.org/x/crypto/bcrypt"
)

func main() {
	// 加载配置
	config.LoadConfig()

	// 初始化数据库
	if err := database.InitDatabase(); err != nil {
		log.Fatalf("数据库初始化失败: %v", err)
	}

	// 查找管理员用户
	var admin models.User
	if err := database.DB.Where("username = ?", "admin").First(&admin).Error; err != nil {
		log.Fatalf("未找到管理员用户: %v", err)
	}

	// 设置新密码
	newPassword := "admin123"
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("密码哈希失败: %v", err)
	}

	admin.Password = string(hashedPassword)

	// 更新用户
	if err := database.DB.Save(&admin).Error; err != nil {
		log.Fatalf("更新密码失败: %v", err)
	}

	fmt.Println("✅ 管理员密码重置成功！")
	fmt.Printf("   用户名: %s\n", admin.Username)
	fmt.Printf("   密码: %s\n", newPassword)
	fmt.Printf("   邮箱: %s\n", admin.Email)

	// 验证密码
	err = bcrypt.CompareHashAndPassword([]byte(admin.Password), []byte(newPassword))
	if err != nil {
		fmt.Println("❌ 密码验证失败")
	} else {
		fmt.Println("✅ 密码验证成功")
	}
}
