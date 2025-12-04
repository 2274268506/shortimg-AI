package controllers

import (
	"bytes"
	"encoding/json"
	"imagebed/config"
	"imagebed/database"
	"imagebed/models"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

// setupTestDB 设置测试数据库
func setupTestDB(t *testing.T) {
	// 使用内存数据库进行测试
	config.LoadConfig()
	if err := database.InitDatabase(); err != nil {
		t.Fatalf("初始化测试数据库失败: %v", err)
	}
}

// cleanupTestDB 清理测试数据库
func cleanupTestDB() {
	db := database.GetDB()
	db.Exec("DELETE FROM images")
	db.Exec("DELETE FROM albums")
	db.Exec("DELETE FROM users")
}

// createTestUser 创建测试用户
func createTestUser(username, password string) *models.User {
	user := &models.User{
		Username: username,
		Email:    username + "@test.com",
		Role:     "user",
	}
	user.SetPassword(password)

	db := database.GetDB()
	db.Create(user)

	return user
}

// getAuthToken 获取认证 Token
func getAuthToken(username, password string) string {
	user := createTestUser(username, password)

	// 生成 JWT Token (这里需要实现 JWT 生成逻辑)
	// token, _ := utils.GenerateToken(user.ID, user.Username, user.Role)
	// return "Bearer " + token

	return "Bearer test-token-" + username
}

func TestMain(m *testing.M) {
	// 设置测试模式
	gin.SetMode(gin.TestMode)
	m.Run()
}

// TestHealthCheck 测试健康检查
func TestHealthCheck(t *testing.T) {
	// 创建测试路由
	r := gin.Default()
	r.GET("/health", HealthCheck)

	// 创建测试请求
	req, _ := http.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	// 断言响应
	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "ok", response["status"])
}

// TestRegister 测试用户注册
func TestRegister(t *testing.T) {
	setupTestDB(t)
	defer cleanupTestDB()

	r := gin.Default()
	r.POST("/register", Register)

	// 测试数据
	registerData := map[string]string{
		"username": "testuser",
		"email":    "test@example.com",
		"password": "password123",
	}
	jsonData, _ := json.Marshal(registerData)

	// 创建请求
	req, _ := http.NewRequest("POST", "/register", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	// 断言
	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "注册成功", response["message"])
}

// TestLogin 测试用户登录
func TestLogin(t *testing.T) {
	setupTestDB(t)
	defer cleanupTestDB()

	// 先创建用户
	user := createTestUser("logintest", "password123")
	assert.NotNil(t, user)

	r := gin.Default()
	r.POST("/login", Login)

	// 测试正确的登录
	loginData := map[string]string{
		"username": "logintest",
		"password": "password123",
	}
	jsonData, _ := json.Marshal(loginData)

	req, _ := http.NewRequest("POST", "/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response map[string]interface{}
	err := json.Unmarshal(w.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.NotEmpty(t, response["token"])
}

// TestLoginFailed 测试登录失败
func TestLoginFailed(t *testing.T) {
	setupTestDB(t)
	defer cleanupTestDB()

	r := gin.Default()
	r.POST("/login", Login)

	// 测试错误的密码
	loginData := map[string]string{
		"username": "nonexistent",
		"password": "wrongpassword",
	}
	jsonData, _ := json.Marshal(loginData)

	req, _ := http.NewRequest("POST", "/login", bytes.NewBuffer(jsonData))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusUnauthorized, w.Code)
}
