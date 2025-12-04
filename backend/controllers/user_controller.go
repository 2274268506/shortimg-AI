package controllers

import (
	"imagebed/database"
	"imagebed/models"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// GetUsers 获取所有用户（管理员）
func GetUsers(c *gin.Context) {
	db := database.GetDB()

	var users []models.User
	if err := db.Find(&users).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取用户列表失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": users})
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
