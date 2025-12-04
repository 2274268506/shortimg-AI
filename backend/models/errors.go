package models

import (
	"fmt"
	"net/http"
)

// AppError 应用程序错误基础接口
type AppError interface {
	error
	StatusCode() int
	ErrorCode() string
	Details() interface{}
}

// BaseError 基础错误结构
type BaseError struct {
	Code       string      `json:"code"`
	Message    string      `json:"message"`
	Detail     interface{} `json:"details,omitempty"`
	HTTPStatus int         `json:"-"`
	Err        error       `json:"-"` // 原始错误，用于错误链
}

func (e *BaseError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s: %v", e.Message, e.Err)
	}
	return e.Message
}

func (e *BaseError) StatusCode() int {
	return e.HTTPStatus
}

func (e *BaseError) ErrorCode() string {
	return e.Code
}

func (e *BaseError) Details() interface{} {
	return e.Detail
}

func (e *BaseError) Unwrap() error {
	return e.Err
}

// 错误码常量
const (
	// 通用错误 1xxx
	ErrCodeInternalError    = "ERR1000"
	ErrCodeBadRequest       = "ERR1001"
	ErrCodeValidationFailed = "ERR1002"
	ErrCodeMethodNotAllowed = "ERR1003"
	ErrCodeTooManyRequests  = "ERR1004"

	// 认证错误 2xxx
	ErrCodeUnauthorized       = "ERR2000"
	ErrCodeInvalidToken       = "ERR2001"
	ErrCodeTokenExpired       = "ERR2002"
	ErrCodeInvalidCredentials = "ERR2003"
	ErrCodeForbidden          = "ERR2004"

	// 资源错误 3xxx
	ErrCodeNotFound        = "ERR3000"
	ErrCodeResourceExists  = "ERR3001"
	ErrCodeResourceDeleted = "ERR3002"

	// 存储错误 4xxx
	ErrCodeStorageError    = "ERR4000"
	ErrCodeUploadFailed    = "ERR4001"
	ErrCodeFileNotFound    = "ERR4002"
	ErrCodeFileTooLarge    = "ERR4003"
	ErrCodeInvalidFileType = "ERR4004"

	// 数据库错误 5xxx
	ErrCodeDatabaseError = "ERR5000"
	ErrCodeQueryFailed   = "ERR5001"
	ErrCodeCreateFailed  = "ERR5002"
	ErrCodeUpdateFailed  = "ERR5003"
	ErrCodeDeleteFailed  = "ERR5004"
)

// ValidationError 验证错误
type ValidationError struct {
	*BaseError
	Fields map[string]string `json:"fields,omitempty"`
}

func NewValidationError(message string, fields map[string]string) *ValidationError {
	return &ValidationError{
		BaseError: &BaseError{
			Code:       ErrCodeValidationFailed,
			Message:    message,
			HTTPStatus: http.StatusBadRequest,
			Detail:     fields,
		},
		Fields: fields,
	}
}

// NotFoundError 资源未找到错误
type NotFoundError struct {
	*BaseError
	Resource string `json:"resource,omitempty"`
}

func NewNotFoundError(resource string, identifier interface{}) *NotFoundError {
	return &NotFoundError{
		BaseError: &BaseError{
			Code:       ErrCodeNotFound,
			Message:    fmt.Sprintf("%s 未找到", resource),
			HTTPStatus: http.StatusNotFound,
			Detail:     identifier,
		},
		Resource: resource,
	}
}

// AuthError 认证/授权错误
type AuthError struct {
	*BaseError
	Reason string `json:"reason,omitempty"`
}

func NewAuthError(message, reason string) *AuthError {
	return &AuthError{
		BaseError: &BaseError{
			Code:       ErrCodeUnauthorized,
			Message:    message,
			HTTPStatus: http.StatusUnauthorized,
			Detail:     reason,
		},
		Reason: reason,
	}
}

func NewForbiddenError(message string) *AuthError {
	return &AuthError{
		BaseError: &BaseError{
			Code:       ErrCodeForbidden,
			Message:    message,
			HTTPStatus: http.StatusForbidden,
		},
	}
}

// StorageError 存储错误
type StorageError struct {
	*BaseError
	Operation string `json:"operation,omitempty"`
}

func NewStorageError(operation, message string, err error) *StorageError {
	return &StorageError{
		BaseError: &BaseError{
			Code:       ErrCodeStorageError,
			Message:    message,
			HTTPStatus: http.StatusInternalServerError,
			Err:        err,
		},
		Operation: operation,
	}
}

func NewUploadError(message string, err error) *StorageError {
	return &StorageError{
		BaseError: &BaseError{
			Code:       ErrCodeUploadFailed,
			Message:    message,
			HTTPStatus: http.StatusBadRequest,
			Err:        err,
		},
		Operation: "upload",
	}
}

func NewInvalidFileTypeError(fileType string, allowedTypes []string) *StorageError {
	return &StorageError{
		BaseError: &BaseError{
			Code:       ErrCodeInvalidFileType,
			Message:    fmt.Sprintf("不支持的文件类型: %s", fileType),
			HTTPStatus: http.StatusBadRequest,
			Detail: map[string]interface{}{
				"provided": fileType,
				"allowed":  allowedTypes,
			},
		},
		Operation: "validation",
	}
}

func NewFileTooLargeError(size, maxSize int64) *StorageError {
	return &StorageError{
		BaseError: &BaseError{
			Code:       ErrCodeFileTooLarge,
			Message:    "文件大小超出限制",
			HTTPStatus: http.StatusBadRequest,
			Detail: map[string]interface{}{
				"size":     size,
				"max_size": maxSize,
			},
		},
		Operation: "validation",
	}
}

// DatabaseError 数据库错误
type DatabaseError struct {
	*BaseError
	Operation string `json:"operation,omitempty"`
	Table     string `json:"table,omitempty"`
}

func NewDatabaseError(operation, table, message string, err error) *DatabaseError {
	code := ErrCodeDatabaseError
	switch operation {
	case "create":
		code = ErrCodeCreateFailed
	case "update":
		code = ErrCodeUpdateFailed
	case "delete":
		code = ErrCodeDeleteFailed
	case "query":
		code = ErrCodeQueryFailed
	}

	return &DatabaseError{
		BaseError: &BaseError{
			Code:       code,
			Message:    message,
			HTTPStatus: http.StatusInternalServerError,
			Err:        err,
		},
		Operation: operation,
		Table:     table,
	}
}

// InternalError 内部服务器错误
type InternalError struct {
	*BaseError
}

func NewInternalError(message string, err error) *InternalError {
	return &InternalError{
		BaseError: &BaseError{
			Code:       ErrCodeInternalError,
			Message:    message,
			HTTPStatus: http.StatusInternalServerError,
			Err:        err,
		},
	}
}

// BadRequestError 请求错误
type BadRequestError struct {
	*BaseError
}

func NewBadRequestError(message string) *BadRequestError {
	return &BadRequestError{
		BaseError: &BaseError{
			Code:       ErrCodeBadRequest,
			Message:    message,
			HTTPStatus: http.StatusBadRequest,
		},
	}
}

// ResourceExistsError 资源已存在错误
type ResourceExistsError struct {
	*BaseError
	Resource string `json:"resource,omitempty"`
}

func NewResourceExistsError(resource string, identifier interface{}) *ResourceExistsError {
	return &ResourceExistsError{
		BaseError: &BaseError{
			Code:       ErrCodeResourceExists,
			Message:    fmt.Sprintf("%s 已存在", resource),
			HTTPStatus: http.StatusConflict,
			Detail:     identifier,
		},
		Resource: resource,
	}
}
