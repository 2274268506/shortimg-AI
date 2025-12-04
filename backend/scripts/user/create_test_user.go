package main

import (
	"fmt"
	"imagebed/config"
	"imagebed/database"
	"imagebed/models"
	"log"
	"time"

	"golang.org/x/crypto/bcrypt"
)

func main() {
	// 加载配置
	config.LoadConfig()

	// 初始化数据库
	if err := database.InitDatabase(); err != nil {
		log.Fatalf("数据库初始化失败: %v", err)
	}

	// 检查是否已有用户
	var count int64
	database.DB.Model(&models.User{}).Count(&count)

	if count > 0 {
		fmt.Printf("数据库中已有 %d 个用户\n", count)

		// 列出所有用户
		var users []models.User
		database.DB.Find(&users)
		fmt.Println("\n现有用户：")
		for _, user := range users {
			fmt.Printf("  - ID: %d, 用户名: %s, 邮箱: %s, 角色: %s, 状态: %s\n",
				user.ID, user.Username, user.Email, user.Role, user.Status)
		}
		return
	}

	// 创建测试管理员用户
	fmt.Println("创建测试管理员用户...")

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("密码哈希失败: %v", err)
	}

	admin := models.User{
		Username: "admin",
		Email:    "admin@example.com",
		Password: string(hashedPassword),
		Role:     "admin",
		Status:   "active",
	}

	if err := database.DB.Create(&admin).Error; err != nil {
		log.Fatalf("创建管理员用户失败: %v", err)
	}

	fmt.Printf("✅ 管理员用户创建成功！\n")
	fmt.Printf("   用户名: %s\n", admin.Username)
	fmt.Printf("   密码: admin123\n")
	fmt.Printf("   邮箱: %s\n", admin.Email)

	// 创建测试普通用户
	fmt.Println("\n创建测试普通用户...")

	hashedPassword, err = bcrypt.GenerateFromPassword([]byte("user123"), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("密码哈希失败: %v", err)
	}

	now := time.Now()
	user := models.User{
		Username:  "testuser",
		Email:     "user@example.com",
		Password:  string(hashedPassword),
		Role:      "user",
		Status:    "active",
		Avatar:    "https://api.dicebear.com/7.x/avataaars/svg?seed=testuser",
		Bio:       "这是一个测试用户账号",
		LastLogin: &now,
		LoginIP:   "127.0.0.1",
	}

	if err := database.DB.Create(&user).Error; err != nil {
		log.Fatalf("创建普通用户失败: %v", err)
	}

	fmt.Printf("✅ 普通用户创建成功！\n")
	fmt.Printf("   用户名: %s\n", user.Username)
	fmt.Printf("   密码: user123\n")
	fmt.Printf("   邮箱: %s\n", user.Email)

	fmt.Println("\n🎉 测试用户创建完成！")
	fmt.Println("\n登录信息：")
	fmt.Println("  管理员 - 用户名: admin, 密码: admin123")
	fmt.Println("  普通用户 - 用户名: testuser, 密码: user123")
}
