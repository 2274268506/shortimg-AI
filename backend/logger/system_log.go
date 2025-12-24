package logger

import (
	"encoding/json"
	"imagebed/database"
	"imagebed/models"

	"go.uber.org/zap"
)

// LogLevel 日志级别
type LogLevel string

const (
	LevelDebug LogLevel = "debug"
	LevelInfo  LogLevel = "info"
	LevelWarn  LogLevel = "warn"
	LevelError LogLevel = "error"
	LevelFatal LogLevel = "fatal"
)

// SaveSystemLog 保存系统日志到数据库（异步）
// level: debug/info/warn/error/fatal
// module: 模块名称，如 "database", "http", "storage", "auth" 等
// message: 日志消息
// errorMsg: 错误信息（可选）
// extra: 额外信息（可选）
func SaveSystemLog(level LogLevel, module, message, errorMsg string, extra map[string]interface{}) {
	// 使用goroutine异步保存，避免阻塞主流程
	go func() {
		defer func() {
			if r := recover(); r != nil {
				Error("Failed to save system log", zap.Any("panic", r))
			}
		}()

		db := database.GetDB()
		if db == nil {
			Warn("Database not initialized, cannot save system log")
			return
		}

		// 将extra转为JSON
		extraJSON := ""
		if extra != nil {
			if jsonBytes, err := json.Marshal(extra); err == nil {
				extraJSON = string(jsonBytes)
			}
		}

		systemLog := models.SystemLog{
			Level:   string(level),
			Module:  module,
			Message: message,
			Error:   errorMsg,
			Extra:   extraJSON,
		}

		if err := db.Create(&systemLog).Error; err != nil {
			Error("Failed to create system log in database", zap.Error(err))
		}
	}()
}

// 便捷方法
func LogDebug(module, message string, extra map[string]interface{}) {
	SaveSystemLog(LevelDebug, module, message, "", extra)
}

func LogInfo(module, message string, extra map[string]interface{}) {
	SaveSystemLog(LevelInfo, module, message, "", extra)
}

func LogWarn(module, message, errorMsg string, extra map[string]interface{}) {
	SaveSystemLog(LevelWarn, module, message, errorMsg, extra)
}

func LogError(module, message, errorMsg string, extra map[string]interface{}) {
	SaveSystemLog(LevelError, module, message, errorMsg, extra)
}

func LogFatal(module, message, errorMsg string, extra map[string]interface{}) {
	SaveSystemLog(LevelFatal, module, message, errorMsg, extra)
}
