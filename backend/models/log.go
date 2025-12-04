package models

import (
	"time"

	"gorm.io/gorm"
)

// OperationLog 操作日志模型
type OperationLog struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	// 用户信息
	UserID   uint   `json:"user_id" gorm:"index"`
	Username string `json:"username"`

	// 操作信息
	Action      string `json:"action" gorm:"index"` // 操作类型：create, update, delete, upload, download
	Module      string `json:"module" gorm:"index"` // 模块：image, album, user
	ResourceID  uint   `json:"resource_id"`         // 资源ID
	Description string `json:"description"`         // 操作描述

	// 请求信息
	Method    string `json:"method"`     // HTTP方法
	Path      string `json:"path"`       // 请求路径
	IP        string `json:"ip"`         // 客户端IP
	UserAgent string `json:"user_agent"` // 用户代理

	// 结果信息
	Status  int    `json:"status"`  // HTTP状态码
	Error   string `json:"error"`   // 错误信息
	Latency int64  `json:"latency"` // 响应时间（毫秒）

	// 额外数据（JSON格式）
	Extra string `json:"extra"` // 额外信息
}

// TableName 指定表名
func (OperationLog) TableName() string {
	return "operation_logs"
}

// SystemLog 系统日志模型
type SystemLog struct {
	ID        uint           `gorm:"primarykey" json:"id"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`

	Level   string `json:"level" gorm:"index"`  // 日志级别：debug, info, warn, error, fatal
	Module  string `json:"module" gorm:"index"` // 模块名称
	Message string `json:"message"`             // 日志消息
	Error   string `json:"error"`               // 错误堆栈
	Extra   string `json:"extra"`               // 额外信息（JSON格式）
}

// TableName 指定表名
func (SystemLog) TableName() string {
	return "system_logs"
}
