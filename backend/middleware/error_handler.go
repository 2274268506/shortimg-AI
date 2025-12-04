package middleware

import (
	"errors"
	"imagebed/models"
	"log"
	"net/http"
	"runtime/debug"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// ErrorResponse 错误响应结构
type ErrorResponse struct {
	Success bool        `json:"success"`
	Error   ErrorDetail `json:"error"`
}

// ErrorDetail 错误详情
type ErrorDetail struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

// ErrorHandlerMiddleware 统一错误处理中间件
func ErrorHandlerMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				// 记录 panic 堆栈
				log.Printf("❌ Panic recovered: %v\n%s", err, debug.Stack())

				// 记录 panic 到监控
				RecordImageUpload("panic", "error")

				// 返回 500 错误
				c.JSON(http.StatusInternalServerError, ErrorResponse{
					Success: false,
					Error: ErrorDetail{
						Code:    models.ErrCodeInternalError,
						Message: "服务器内部错误",
					},
				})
				c.Abort()
			}
		}()

		c.Next()

		// 检查是否有错误
		if len(c.Errors) > 0 {
			// 获取最后一个错误
			err := c.Errors.Last().Err
			handleError(c, err)
		}
	}
}

// handleError 处理错误并返回适当的响应
func handleError(c *gin.Context, err error) {
	// 如果已经写入响应，则不再处理
	if c.Writer.Written() {
		return
	}

	// 尝试转换为 AppError
	var appErr models.AppError
	if errors.As(err, &appErr) {
		// 记录业务错误
		log.Printf("⚠️  业务错误 [%s]: %s", appErr.ErrorCode(), appErr.Error())

		c.JSON(appErr.StatusCode(), ErrorResponse{
			Success: false,
			Error: ErrorDetail{
				Code:    appErr.ErrorCode(),
				Message: err.Error(),
				Details: appErr.Details(),
			},
		})
		return
	}

	// 处理 GORM 错误
	if errors.Is(err, gorm.ErrRecordNotFound) {
		c.JSON(http.StatusNotFound, ErrorResponse{
			Success: false,
			Error: ErrorDetail{
				Code:    models.ErrCodeNotFound,
				Message: "资源未找到",
			},
		})
		return
	}

	if errors.Is(err, gorm.ErrDuplicatedKey) {
		c.JSON(http.StatusConflict, ErrorResponse{
			Success: false,
			Error: ErrorDetail{
				Code:    models.ErrCodeResourceExists,
				Message: "资源已存在",
			},
		})
		return
	}

	// 未知错误，记录完整日志
	log.Printf("❌ 未处理的错误: %v", err)

	c.JSON(http.StatusInternalServerError, ErrorResponse{
		Success: false,
		Error: ErrorDetail{
			Code:    models.ErrCodeInternalError,
			Message: "服务器内部错误",
		},
	})
}

// RespondWithError 响应错误的辅助函数
func RespondWithError(c *gin.Context, err error) {
	c.Error(err)
	handleError(c, err)
}

// RespondSuccess 响应成功的辅助函数
func RespondSuccess(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    data,
	})
}

// RespondSuccessWithMessage 响应成功并带消息
func RespondSuccessWithMessage(c *gin.Context, message string, data interface{}) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": message,
		"data":    data,
	})
}

// RespondCreated 响应创建成功
func RespondCreated(c *gin.Context, data interface{}) {
	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"data":    data,
	})
}

// RespondNoContent 响应无内容（删除成功等）
func RespondNoContent(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "操作成功",
	})
}
