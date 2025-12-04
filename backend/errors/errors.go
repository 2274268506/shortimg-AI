package errors

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// ErrorCode 错误代码
type ErrorCode int

const (
	// 通用错误 1000-1999
	ErrSuccess         ErrorCode = 0
	ErrBadRequest      ErrorCode = 1000
	ErrUnauthorized    ErrorCode = 1001
	ErrForbidden       ErrorCode = 1002
	ErrNotFound        ErrorCode = 1003
	ErrInternalServer  ErrorCode = 1004
	ErrValidation      ErrorCode = 1005
	ErrTooManyRequests ErrorCode = 1006

	// 用户相关错误 2000-2999
	ErrUserNotFound       ErrorCode = 2000
	ErrUserAlreadyExists  ErrorCode = 2001
	ErrInvalidCredentials ErrorCode = 2002
	ErrTokenInvalid       ErrorCode = 2003
	ErrTokenExpired       ErrorCode = 2004
	ErrPermissionDenied   ErrorCode = 2005
	ErrUserDisabled       ErrorCode = 2006

	// 图片相关错误 3000-3999
	ErrImageNotFound    ErrorCode = 3000
	ErrImageTooLarge    ErrorCode = 3001
	ErrInvalidFormat    ErrorCode = 3002
	ErrUploadFailed     ErrorCode = 3003
	ErrImageProcessing  ErrorCode = 3004
	ErrConversionFailed ErrorCode = 3005

	// 相册相关错误 4000-4999
	ErrAlbumNotFound      ErrorCode = 4000
	ErrAlbumAlreadyExists ErrorCode = 4001
	ErrAlbumNotEmpty      ErrorCode = 4002

	// 存储相关错误 5000-5999
	ErrStorageNotAvailable  ErrorCode = 5000
	ErrStorageQuotaExceeded ErrorCode = 5001
	ErrFileSaveFailed       ErrorCode = 5002

	// 缓存相关错误 6000-6999
	ErrCacheNotAvailable ErrorCode = 6000
	ErrCacheSetFailed    ErrorCode = 6001
	ErrCacheGetFailed    ErrorCode = 6002
)

// AppError 应用错误
type AppError struct {
	Code       ErrorCode `json:"code"`
	Message    string    `json:"message"`
	Details    string    `json:"details,omitempty"`
	HTTPStatus int       `json:"-"`
}

// Error 实现 error 接口
func (e *AppError) Error() string {
	if e.Details != "" {
		return e.Message + ": " + e.Details
	}
	return e.Message
}

// 错误消息映射
var errorMessages = map[ErrorCode]string{
	ErrSuccess:         "成功",
	ErrBadRequest:      "请求参数错误",
	ErrUnauthorized:    "未授权，请先登录",
	ErrForbidden:       "权限不足",
	ErrNotFound:        "资源不存在",
	ErrInternalServer:  "服务器内部错误",
	ErrValidation:      "数据验证失败",
	ErrTooManyRequests: "请求过于频繁，请稍后再试",

	ErrUserNotFound:       "用户不存在",
	ErrUserAlreadyExists:  "用户名已存在",
	ErrInvalidCredentials: "用户名或密码错误",
	ErrTokenInvalid:       "令牌无效",
	ErrTokenExpired:       "令牌已过期",
	ErrPermissionDenied:   "没有操作权限",
	ErrUserDisabled:       "用户已被禁用",

	ErrImageNotFound:    "图片不存在",
	ErrImageTooLarge:    "图片文件过大",
	ErrInvalidFormat:    "不支持的图片格式",
	ErrUploadFailed:     "上传失败",
	ErrImageProcessing:  "图片处理失败",
	ErrConversionFailed: "格式转换失败",

	ErrAlbumNotFound:      "相册不存在",
	ErrAlbumAlreadyExists: "相册名已存在",
	ErrAlbumNotEmpty:      "相册不为空，无法删除",

	ErrStorageNotAvailable:  "存储服务不可用",
	ErrStorageQuotaExceeded: "存储空间不足",
	ErrFileSaveFailed:       "文件保存失败",

	ErrCacheNotAvailable: "缓存服务不可用",
	ErrCacheSetFailed:    "缓存设置失败",
	ErrCacheGetFailed:    "缓存获取失败",
}

// 错误码到HTTP状态码映射
var errorHTTPStatus = map[ErrorCode]int{
	ErrSuccess:         http.StatusOK,
	ErrBadRequest:      http.StatusBadRequest,
	ErrUnauthorized:    http.StatusUnauthorized,
	ErrForbidden:       http.StatusForbidden,
	ErrNotFound:        http.StatusNotFound,
	ErrInternalServer:  http.StatusInternalServerError,
	ErrValidation:      http.StatusBadRequest,
	ErrTooManyRequests: http.StatusTooManyRequests,

	ErrUserNotFound:       http.StatusNotFound,
	ErrUserAlreadyExists:  http.StatusConflict,
	ErrInvalidCredentials: http.StatusUnauthorized,
	ErrTokenInvalid:       http.StatusUnauthorized,
	ErrTokenExpired:       http.StatusUnauthorized,
	ErrPermissionDenied:   http.StatusForbidden,
	ErrUserDisabled:       http.StatusForbidden,

	ErrImageNotFound:    http.StatusNotFound,
	ErrImageTooLarge:    http.StatusRequestEntityTooLarge,
	ErrInvalidFormat:    http.StatusBadRequest,
	ErrUploadFailed:     http.StatusInternalServerError,
	ErrImageProcessing:  http.StatusInternalServerError,
	ErrConversionFailed: http.StatusInternalServerError,

	ErrAlbumNotFound:      http.StatusNotFound,
	ErrAlbumAlreadyExists: http.StatusConflict,
	ErrAlbumNotEmpty:      http.StatusBadRequest,

	ErrStorageNotAvailable:  http.StatusServiceUnavailable,
	ErrStorageQuotaExceeded: http.StatusInsufficientStorage,
	ErrFileSaveFailed:       http.StatusInternalServerError,

	ErrCacheNotAvailable: http.StatusServiceUnavailable,
	ErrCacheSetFailed:    http.StatusInternalServerError,
	ErrCacheGetFailed:    http.StatusInternalServerError,
}

// New 创建新的应用错误
func New(code ErrorCode, details string) *AppError {
	message, ok := errorMessages[code]
	if !ok {
		message = "未知错误"
	}

	httpStatus, ok := errorHTTPStatus[code]
	if !ok {
		httpStatus = http.StatusInternalServerError
	}

	return &AppError{
		Code:       code,
		Message:    message,
		Details:    details,
		HTTPStatus: httpStatus,
	}
}

// NewWithMessage 创建带自定义消息的错误
func NewWithMessage(code ErrorCode, message string, details string) *AppError {
	httpStatus, ok := errorHTTPStatus[code]
	if !ok {
		httpStatus = http.StatusInternalServerError
	}

	return &AppError{
		Code:       code,
		Message:    message,
		Details:    details,
		HTTPStatus: httpStatus,
	}
}

// Response 统一响应格式
type Response struct {
	Code    ErrorCode   `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

// Success 成功响应
func Success(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, Response{
		Code:    ErrSuccess,
		Message: "success",
		Data:    data,
	})
}

// SuccessWithMessage 带自定义消息的成功响应
func SuccessWithMessage(c *gin.Context, message string, data interface{}) {
	c.JSON(http.StatusOK, Response{
		Code:    ErrSuccess,
		Message: message,
		Data:    data,
	})
}

// Error 错误响应
func Error(c *gin.Context, err *AppError) {
	c.JSON(err.HTTPStatus, Response{
		Code:    err.Code,
		Message: err.Error(),
		Data:    nil,
	})
}

// HandleError 处理错误（中间件使用）
func HandleError(c *gin.Context, err error) {
	if appErr, ok := err.(*AppError); ok {
		Error(c, appErr)
	} else {
		// 未知错误，返回内部服务器错误
		Error(c, New(ErrInternalServer, err.Error()))
	}
}
