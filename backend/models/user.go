package models

import (
	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type User struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	Username  string         `gorm:"uniqueIndex;not null" json:"username"`
	Email     string         `gorm:"uniqueIndex;not null" json:"email"`
	Password  string         `gorm:"not null" json:"-"`                  // 不返回密码到前端
	Role      string         `gorm:"default:user;index" json:"role"`     // user, admin
	Status    string         `gorm:"default:active;index" json:"status"` // active, disabled
	Avatar    string         `json:"avatar,omitempty"`                   // 头像URL
	Bio       string         `gorm:"type:text" json:"bio,omitempty"`     // 个人简介
	LastLogin *time.Time     `json:"lastLogin,omitempty"`                // 最后登录时间
	LoginIP   string         `json:"loginIP,omitempty"`                  // 最后登录IP
	CreatedAt time.Time      `json:"createdAt"`
	UpdatedAt time.Time      `json:"updatedAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

// UserStats 用户统计信息
type UserStats struct {
	UserID         uint  `json:"userId"`
	TotalImages    int64 `json:"totalImages"`
	TotalAlbums    int64 `json:"totalAlbums"`
	TotalStorage   int64 `json:"totalStorage"` // 字节
	TotalViews     int64 `json:"totalViews"`
	TotalDownloads int64 `json:"totalDownloads"`
}

// HashPassword 加密密码
func (u *User) HashPassword(password string) error {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	if err != nil {
		return err
	}
	u.Password = string(bytes)
	return nil
}

// CheckPassword 验证密码
func (u *User) CheckPassword(password string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(password))
	return err == nil
}
