package utils

import (
	"math"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// PaginationParams 分页参数
type PaginationParams struct {
	Page     int    `form:"page" json:"page"`         // 当前页码（从1开始）
	PageSize int    `form:"pageSize" json:"pageSize"` // 每页数量
	OrderBy  string `form:"orderBy" json:"orderBy"`   // 排序字段
	Order    string `form:"order" json:"order"`       // 排序方向 (asc/desc)
}

// PaginationResult 分页结果
type PaginationResult struct {
	Total       int64       `json:"total"`       // 总记录数
	Page        int         `json:"page"`        // 当前页码
	PageSize    int         `json:"pageSize"`    // 每页数量
	TotalPages  int         `json:"totalPages"`  // 总页数
	HasPrevious bool        `json:"hasPrevious"` // 是否有上一页
	HasNext     bool        `json:"hasNext"`     // 是否有下一页
	Data        interface{} `json:"data"`        // 数据列表
}

// DefaultPaginationParams 默认分页参数
var DefaultPaginationParams = PaginationParams{
	Page:     1,
	PageSize: 20,
	OrderBy:  "id",
	Order:    "desc",
}

// GetPaginationParams 从请求中获取分页参数
func GetPaginationParams(c *gin.Context) PaginationParams {
	params := DefaultPaginationParams

	if err := c.ShouldBindQuery(&params); err != nil {
		return DefaultPaginationParams
	}

	// 参数验证
	if params.Page < 1 {
		params.Page = 1
	}
	if params.PageSize < 1 {
		params.PageSize = 20
	}
	if params.PageSize > 100 {
		params.PageSize = 100 // 最大每页100条
	}
	if params.Order != "asc" && params.Order != "desc" {
		params.Order = "desc"
	}

	return params
}

// Paginate 应用分页到查询
func Paginate(params PaginationParams) func(db *gorm.DB) *gorm.DB {
	return func(db *gorm.DB) *gorm.DB {
		offset := (params.Page - 1) * params.PageSize

		// 应用排序
		orderClause := params.OrderBy + " " + params.Order
		return db.Offset(offset).Limit(params.PageSize).Order(orderClause)
	}
}

// BuildPaginationResult 构建分页结果
func BuildPaginationResult(params PaginationParams, total int64, data interface{}) PaginationResult {
	totalPages := int(math.Ceil(float64(total) / float64(params.PageSize)))

	return PaginationResult{
		Total:       total,
		Page:        params.Page,
		PageSize:    params.PageSize,
		TotalPages:  totalPages,
		HasPrevious: params.Page > 1,
		HasNext:     params.Page < totalPages,
		Data:        data,
	}
}

// PaginateQuery 执行带分页的查询
func PaginateQuery(db *gorm.DB, params PaginationParams, result interface{}) (PaginationResult, error) {
	var total int64

	// 获取总记录数
	if err := db.Count(&total).Error; err != nil {
		return PaginationResult{}, err
	}

	// 执行分页查询
	if err := db.Scopes(Paginate(params)).Find(result).Error; err != nil {
		return PaginationResult{}, err
	}

	return BuildPaginationResult(params, total, result), nil
}
