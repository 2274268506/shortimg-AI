package controllers

import (
	"imagebed/database"
	"imagebed/models"
	"imagebed/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// GetUsers 获取所有用户（管理员）- 支持分页和搜索
func GetUsers(c *gin.Context) {
	db := database.GetDB()

	// 获取分页参数
	params := utils.GetPaginationParams(c)

	// 获取搜索关键词
	keyword := c.Query("keyword")
	status := c.Query("status")
	role := c.Query("role")

	query := db.Model(&models.User{})

	// 应用搜索条件
	if keyword != "" {
		query = query.Where("username LIKE ? OR email LIKE ?", "%"+keyword+"%", "%"+keyword+"%")
	}
	if status != "" {
		query = query.Where("status = ?", status)
	}
	if role != "" {
		query = query.Where("role = ?", role)
	}

	var users []models.User
	result, err := utils.PaginateQuery(query, params, &users)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户列表失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": result})
}

// GetUser 获取单个用户详情（管理员）
func GetUser(c *gin.Context) {
	id := c.Param("id")

	db := database.GetDB()
	var user models.User

	if err := db.First(&user, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": user})
}

// GetUserStats 获取用户统计信息（管理员）
func GetUserStats(c *gin.Context) {
	id := c.Param("id")
	userID, err := strconv.ParseUint(id, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的用户ID"})
		return
	}

	db := database.GetDB()

	var stats models.UserStats
	stats.UserID = uint(userID)

	// 统计图片数量
	db.Model(&models.Image{}).Where("owner_id = ?", userID).Count(&stats.TotalImages)

	// 统计相册数量
	db.Model(&models.Album{}).Where("owner_id = ?", userID).Count(&stats.TotalAlbums)

	// 统计存储空间
	db.Model(&models.Image{}).Where("owner_id = ?", userID).Select("COALESCE(SUM(file_size), 0)").Scan(&stats.TotalStorage)

	// 统计浏览量
	db.Model(&models.Image{}).Where("owner_id = ?", userID).Select("COALESCE(SUM(view_count), 0)").Scan(&stats.TotalViews)

	// 统计下载量
	db.Model(&models.Image{}).Where("owner_id = ?", userID).Select("COALESCE(SUM(download_count), 0)").Scan(&stats.TotalDownloads)

	c.JSON(http.StatusOK, gin.H{"data": stats})
}

// DeleteUser 删除用户（管理员）
func DeleteUser(c *gin.Context) {
	idStr := c.Param("id")
	userID, _ := c.Get("user_id")

	// 将字符串ID转换为uint
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无效的用户ID"})
		return
	}

	// 不能删除自己
	if uint(id) == userID.(uint) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "不能删除自己"})
		return
	}

	db := database.GetDB()
	if err := db.Delete(&models.User{}, id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除用户失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "删除成功"})
}

// UpdateUserRoleRequest 更新用户角色请求
type UpdateUserRoleRequest struct {
	Role string `json:"role" binding:"required,oneof=user admin"`
}

// UpdateUserRole 更新用户角色（管理员）
func UpdateUserRole(c *gin.Context) {
	id := c.Param("id")
	var req UpdateUserRoleRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求参数错误"})
		return
	}

	db := database.GetDB()
	var user models.User

	if err := db.First(&user, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}

	user.Role = req.Role
	if err := db.Save(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新角色失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": user})
}

// UpdateUserStatusRequest 更新用户状态请求
type UpdateUserStatusRequest struct {
	Status string `json:"status" binding:"required,oneof=active disabled"`
}

// UpdateUserStatus 更新用户状态（管理员）
func UpdateUserStatus(c *gin.Context) {
	id := c.Param("id")
	var req UpdateUserStatusRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求参数错误"})
		return
	}

	userID, _ := c.Get("userID")
	// 不能禁用自己
	idUint, _ := strconv.ParseUint(id, 10, 32)
	if uint(idUint) == userID.(uint) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "不能修改自己的状态"})
		return
	}

	db := database.GetDB()
	var user models.User

	if err := db.First(&user, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}

	user.Status = req.Status
	if err := db.Save(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新状态失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": user})
}

// ResetPasswordRequest 重置密码请求
type ResetPasswordRequest struct {
	NewPassword string `json:"newPassword" binding:"required,min=6"`
}

// ResetUserPassword 重置用户密码（管理员）
func ResetUserPassword(c *gin.Context) {
	id := c.Param("id")
	var req ResetPasswordRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求参数错误"})
		return
	}

	db := database.GetDB()
	var user models.User

	if err := db.First(&user, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}

	// 加密新密码
	if err := user.HashPassword(req.NewPassword); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "密码加密失败"})
		return
	}

	if err := db.Save(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "重置密码失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "密码重置成功"})
}

// UpdateProfileRequest 更新个人资料请求
type UpdateProfileRequest struct {
	Avatar string `json:"avatar"`
	Bio    string `json:"bio"`
}

// UpdateProfile 更新个人资料
func UpdateProfile(c *gin.Context) {
	userID, _ := c.Get("userID")
	var req UpdateProfileRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求参数错误"})
		return
	}

	db := database.GetDB()
	var user models.User

	if err := db.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}

	user.Avatar = req.Avatar
	user.Bio = req.Bio

	if err := db.Save(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "更新资料失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": user})
}

// ChangePasswordRequest 修改密码请求
type ChangePasswordRequest struct {
	OldPassword string `json:"oldPassword" binding:"required"`
	NewPassword string `json:"newPassword" binding:"required,min=6"`
}

// ChangePassword 修改密码
func ChangePassword(c *gin.Context) {
	userID, _ := c.Get("userID")
	var req ChangePasswordRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请求参数错误"})
		return
	}

	db := database.GetDB()
	var user models.User

	if err := db.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}

	// 验证旧密码
	if !user.CheckPassword(req.OldPassword) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "原密码错误"})
		return
	}

	// 加密新密码
	if err := user.HashPassword(req.NewPassword); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "密码加密失败"})
		return
	}

	if err := db.Save(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "修改密码失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "密码修改成功"})
}
