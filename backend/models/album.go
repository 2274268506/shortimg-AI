package models

import (
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"
)

// Album 相册模型
type Album struct {
	ID          uint   `json:"id" gorm:"primarykey"`
	Name        string `json:"name" gorm:"not null;index"` // 改为普通索引，允许同名相册
	Description string `json:"description"`
	CoverImage  string `json:"coverImage"`
	ImageCount  int    `json:"imageCount" gorm:"default:0"`
	// 权限控制字段
	OwnerID     uint   `json:"ownerId" gorm:"index;not null"`             // 所有者ID
	Owner       *User  `json:"owner,omitempty" gorm:"foreignKey:OwnerID"` // 所有者信息
	IsPrivate   bool   `json:"isPrivate" gorm:"default:false;index"`      // 是否私有
	IsPublic    bool   `json:"isPublic" gorm:"default:true"`              // 是否公开（可被其他人查看）
	AllowShare  bool   `json:"allowShare" gorm:"default:true"`            // 是否允许分享链接
	SharedUsers string `json:"sharedUsers,omitempty" gorm:"type:text"`    // 共享给的用户ID列表，逗号分隔
	// 短链配置字段
	EnableShortLink bool           `json:"enableShortLink" gorm:"default:false"` // 是否自动为上传的图片生成短链
	CreatedAt       time.Time      `json:"createdAt"`
	UpdatedAt       time.Time      `json:"updatedAt"`
	DeletedAt       gorm.DeletedAt `json:"-" gorm:"index"`
	Images          []Image        `json:"images,omitempty" gorm:"foreignKey:AlbumID"`
}

// Image 图片模型
type Image struct {
	ID            uint       `json:"id" gorm:"primarykey"`
	UUID          string     `json:"uuid" gorm:"uniqueIndex;not null"` // UUID 唯一标识
	AlbumID       uint       `json:"albumId" gorm:"index"`
	FileName      string     `json:"fileName" gorm:"not null"`
	OriginalName  string     `json:"originalName"` // 原始文件名
	FilePath      string     `json:"filePath" gorm:"not null"`
	FileSize      int64      `json:"fileSize"`
	MimeType      string     `json:"mimeType"`
	Width         int        `json:"width"`
	Height        int        `json:"height"`
	Thumbnail     string     `json:"thumbnail"`
	URL           string     `json:"url" gorm:"-"`
	ViewCount     int64      `json:"viewCount" gorm:"default:0;index"`     // 访问次数
	DownloadCount int64      `json:"downloadCount" gorm:"default:0;index"` // 下载次数
	LastViewAt    *time.Time `json:"lastViewAt"`                           // 最后访问时间
	Tags          string     `json:"tags"`                                 // 标签，逗号分隔
	// 权限控制字段
	OwnerID       uint  `json:"ownerId" gorm:"index;not null"`             // 所有者ID
	Owner         *User `json:"owner,omitempty" gorm:"foreignKey:OwnerID"` // 所有者信息
	IsPrivate     bool  `json:"isPrivate" gorm:"default:false;index"`      // 是否私有
	IsPublic      bool  `json:"isPublic" gorm:"default:true"`              // 是否公开
	AllowDownload bool  `json:"allowDownload" gorm:"default:true"`         // 是否允许下载
	// 短链字段
	ShortLinkCode string         `json:"shortLinkCode" gorm:"index"` // 短链代码
	ShortLinkURL  string         `json:"shortLinkUrl" gorm:"-"`      // 短链完整URL（不存储）
	CreatedAt     time.Time      `json:"createdAt"`
	UpdatedAt     time.Time      `json:"updatedAt"`
	DeletedAt     gorm.DeletedAt `json:"-" gorm:"index"`
}

// TableName 指定表名
func (Album) TableName() string {
	return "albums"
}

func (Image) TableName() string {
	return "images"
}

// Statistics 统计模型
type Statistics struct {
	ID             uint      `json:"id" gorm:"primarykey"`
	Date           string    `json:"date" gorm:"uniqueIndex;not null"` // 日期 YYYY-MM-DD
	TotalViews     int64     `json:"totalViews" gorm:"default:0"`
	TotalDownloads int64     `json:"totalDownloads" gorm:"default:0"`
	TotalUploads   int64     `json:"totalUploads" gorm:"default:0"`
	TotalTraffic   int64     `json:"totalTraffic" gorm:"default:0"` // 流量(字节)
	UniqueIPs      int64     `json:"uniqueIps" gorm:"default:0"`    // 独立IP数
	CreatedAt      time.Time `json:"createdAt"`
	UpdatedAt      time.Time `json:"updatedAt"`
}

func (Statistics) TableName() string {
	return "statistics"
}

// CanAccess 检查用户是否可以访问相册
func (a *Album) CanAccess(userID uint, isAdmin bool) bool {
	// 管理员可以访问所有相册
	if isAdmin {
		return true
	}
	// 所有者可以访问
	if a.OwnerID == userID {
		return true
	}
	// 公开相册可以访问
	if a.IsPublic && !a.IsPrivate {
		return true
	}
	// 检查是否在共享列表中
	if a.SharedUsers != "" && userID > 0 {
		return contains(a.SharedUsers, userID)
	}
	return false
}

// CanModify 检查用户是否可以修改相册
func (a *Album) CanModify(userID uint, isAdmin bool) bool {
	// 管理员可以修改所有相册
	if isAdmin {
		return true
	}
	// 只有所有者可以修改
	return a.OwnerID == userID
}

// CanAccess 检查用户是否可以访问图片
func (i *Image) CanAccess(userID uint, isAdmin bool) bool {
	// 管理员可以访问所有图片
	if isAdmin {
		return true
	}
	// 所有者可以访问
	if i.OwnerID == userID {
		return true
	}
	// 公开图片可以访问
	if i.IsPublic && !i.IsPrivate {
		return true
	}
	return false
}

// CanModify 检查用户是否可以修改图片
func (i *Image) CanModify(userID uint, isAdmin bool) bool {
	// 管理员可以修改所有图片
	if isAdmin {
		return true
	}
	// 只有所有者可以修改
	return i.OwnerID == userID
}

// CanDownload 检查用户是否可以下载图片
func (i *Image) CanDownload(userID uint, isAdmin bool) bool {
	// 管理员可以下载所有图片
	if isAdmin {
		return true
	}
	// 所有者可以下载
	if i.OwnerID == userID {
		return true
	}
	// 检查是否允许下载
	if !i.AllowDownload {
		return false
	}
	// 公开图片可以下载
	return i.IsPublic && !i.IsPrivate
}

// contains 检查用户ID是否在逗号分隔的字符串中
func contains(list string, userID uint) bool {
	if list == "" {
		return false
	}
	ids := splitToUints(list)
	for _, id := range ids {
		if id == userID {
			return true
		}
	}
	return false
}

// splitToUints 将逗号分隔的字符串转换为uint数组
func splitToUints(s string) []uint {
	if s == "" {
		return []uint{}
	}
	parts := strings.Split(s, ",")
	result := make([]uint, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			if id, err := strconv.ParseUint(p, 10, 32); err == nil {
				result = append(result, uint(id))
			}
		}
	}
	return result
}
