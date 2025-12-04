# TC-GO 图床系统 Makefile

.PHONY: help dev test build clean docker install swagger lint format

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
COLOR_RESET   = \033[0m
COLOR_INFO    = \033[36m
COLOR_SUCCESS = \033[32m
COLOR_ERROR   = \033[31m
COLOR_WARN    = \033[33m

help: ## 显示帮助信息
	@echo "$(COLOR_INFO)TC-GO 图床管理系统$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_SUCCESS)可用命令:$(COLOR_RESET)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(COLOR_INFO)%-15s$(COLOR_RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(COLOR_WARN)%s$(COLOR_RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ 开发

install: ## 安装依赖
	@echo "$(COLOR_INFO)安装后端依赖...$(COLOR_RESET)"
	cd backend && go mod download
	@echo "$(COLOR_INFO)安装前端依赖...$(COLOR_RESET)"
	cd frontend && npm install
	@echo "$(COLOR_SUCCESS)✓ 依赖安装完成$(COLOR_RESET)"

dev: ## 启动开发服务器
	@echo "$(COLOR_INFO)启动后端服务...$(COLOR_RESET)"
	cd backend && go run main.go &
	@echo "$(COLOR_INFO)启动前端服务...$(COLOR_RESET)"
	cd frontend && npm run dev

dev-backend: ## 只启动后端
	@echo "$(COLOR_INFO)启动后端服务器 (http://localhost:8080)...$(COLOR_RESET)"
	cd backend && go run main.go

dev-frontend: ## 只启动前端
	@echo "$(COLOR_INFO)启动前端开发服务器 (http://localhost:5173)...$(COLOR_RESET)"
	cd frontend && npm run dev

##@ 测试

test: ## 运行所有测试
	@echo "$(COLOR_INFO)运行后端测试...$(COLOR_RESET)"
	cd backend && go test ./... -v
	@echo "$(COLOR_INFO)运行前端测试...$(COLOR_RESET)"
	cd frontend && npm test

test-backend: ## 运行后端测试
	@echo "$(COLOR_INFO)运行后端单元测试...$(COLOR_RESET)"
	cd backend && go test ./... -v -cover

test-coverage: ## 生成测试覆盖率报告
	@echo "$(COLOR_INFO)生成测试覆盖率报告...$(COLOR_RESET)"
	cd backend && go test ./... -coverprofile=coverage.out
	cd backend && go tool cover -html=coverage.out -o coverage.html
	@echo "$(COLOR_SUCCESS)✓ 覆盖率报告已生成: backend/coverage.html$(COLOR_RESET)"

test-watch: ## 监听文件变化自动运行测试
	@echo "$(COLOR_INFO)监听测试文件变化...$(COLOR_RESET)"
	cd backend && go test ./... -v -watch
	@echo "$(COLOR_SUCCESS)✓ 测试完成$(COLOR_RESET)"

test-backend: ## 运行后端测试
	cd backend && go test ./... -v -cover

test-frontend: ## 运行前端测试
	cd frontend && npm test

test-coverage: ## 生成测试覆盖率报告
	cd backend && go test ./... -coverprofile=coverage.out
	cd backend && go tool cover -html=coverage.out -o coverage.html
	@echo "$(COLOR_SUCCESS)✓ 覆盖率报告: backend/coverage.html$(COLOR_RESET)"

##@ 构建

build: ## 构建生产版本
	@echo "$(COLOR_INFO)构建后端...$(COLOR_RESET)"
	cd backend && go build -o ../bin/tc-go main.go
	@echo "$(COLOR_INFO)构建前端...$(COLOR_RESET)"
	cd frontend && npm run build
	@echo "$(COLOR_SUCCESS)✓ 构建完成$(COLOR_RESET)"

build-backend: ## 构建后端
	cd backend && go build -ldflags="-s -w" -o ../bin/tc-go main.go
	@echo "$(COLOR_SUCCESS)✓ 后端构建完成: bin/tc-go$(COLOR_RESET)"

build-frontend: ## 构建前端
	cd frontend && npm run build
	@echo "$(COLOR_SUCCESS)✓ 前端构建完成: frontend/dist$(COLOR_RESET)"

##@ 代码质量

lint: ## 代码检查
	@echo "$(COLOR_INFO)检查后端代码...$(COLOR_RESET)"
	cd backend && golangci-lint run
	@echo "$(COLOR_INFO)检查前端代码...$(COLOR_RESET)"
	cd frontend && npm run lint

format: ## 格式化代码
	@echo "$(COLOR_INFO)格式化后端代码...$(COLOR_RESET)"
	cd backend && gofmt -s -w .
	@echo "$(COLOR_INFO)格式化前端代码...$(COLOR_RESET)"
	cd frontend && npm run format
	@echo "$(COLOR_SUCCESS)✓ 代码格式化完成$(COLOR_RESET)"

swagger: ## 生成 API 文档
	@echo "$(COLOR_INFO)生成 Swagger 文档...$(COLOR_RESET)"
	cd backend && swag init
	@echo "$(COLOR_SUCCESS)✓ API 文档生成完成$(COLOR_RESET)"
	@echo "$(COLOR_INFO)访问: http://localhost:8080/swagger/index.html$(COLOR_RESET)"

##@ 监控

metrics: ## 查看 Prometheus 指标
	@echo "$(COLOR_INFO)Prometheus 指标端点:$(COLOR_RESET)"
	@echo "  http://localhost:8080/metrics"
	@curl -s http://localhost:8080/metrics | head -n 20

monitoring-up: ## 启动监控服务（Prometheus + Grafana）
	@echo "$(COLOR_INFO)启动监控服务...$(COLOR_RESET)"
	docker-compose -f docker-compose.monitoring.yml up -d
	@echo "$(COLOR_SUCCESS)✓ 监控服务已启动$(COLOR_RESET)"
	@echo "$(COLOR_INFO)Prometheus: http://localhost:9090$(COLOR_RESET)"
	@echo "$(COLOR_INFO)Grafana: http://localhost:3001 (admin/admin)$(COLOR_RESET)"

monitoring-down: ## 停止监控服务
	@echo "$(COLOR_INFO)停止监控服务...$(COLOR_RESET)"
	docker-compose -f docker-compose.monitoring.yml down

monitoring-logs: ## 查看监控日志
	docker-compose -f docker-compose.monitoring.yml logs -f

##@ Docker

docker-build: ## 构建 Docker 镜像
	@echo "$(COLOR_INFO)构建 Docker 镜像...$(COLOR_RESET)"
	docker-compose build
	@echo "$(COLOR_SUCCESS)✓ Docker 镜像构建完成$(COLOR_RESET)"

docker-up: ## 启动 Docker 容器
	@echo "$(COLOR_INFO)启动容器...$(COLOR_RESET)"
	docker-compose up -d
	@echo "$(COLOR_SUCCESS)✓ 容器已启动$(COLOR_RESET)"

docker-down: ## 停止 Docker 容器
	docker-compose down

docker-logs: ## 查看容器日志
	docker-compose logs -f

##@ 数据库

db-migrate: ## 运行数据库迁移
	cd backend/cmd/migrate && go run main.go

db-rebuild: ## 重建数据库
	cd backend/cmd/rebuild && go run main.go

db-check: ## 检查数据库结构
	cd backend/cmd/check_schema && go run main.go

##@ 清理

clean: ## 清理构建产物
	@echo "$(COLOR_INFO)清理构建文件...$(COLOR_RESET)"
	rm -rf bin/
	rm -rf backend/data/
	rm -rf backend/uploads/
	rm -rf frontend/dist/
	rm -rf backend/logs/
	@echo "$(COLOR_SUCCESS)✓ 清理完成$(COLOR_RESET)"

clean-cache: ## 清理缓存
	@echo "$(COLOR_INFO)清理依赖缓存...$(COLOR_RESET)"
	cd backend && go clean -cache -modcache
	cd frontend && rm -rf node_modules package-lock.json
	@echo "$(COLOR_SUCCESS)✓ 缓存清理完成$(COLOR_RESET)"

##@ 其他

deps-update: ## 更新依赖
	@echo "$(COLOR_INFO)更新后端依赖...$(COLOR_RESET)"
	cd backend && go get -u ./...
	cd backend && go mod tidy
	@echo "$(COLOR_INFO)更新前端依赖...$(COLOR_RESET)"
	cd frontend && npm update
	@echo "$(COLOR_SUCCESS)✓ 依赖更新完成$(COLOR_RESET)"

init: install db-migrate ## 初始化项目（首次运行）
	@echo "$(COLOR_SUCCESS)✓ 项目初始化完成$(COLOR_RESET)"
	@echo "$(COLOR_INFO)运行 'make dev' 启动开发服务器$(COLOR_RESET)"

production: build ## 生产环境部署
	@echo "$(COLOR_SUCCESS)✓ 生产版本已构建$(COLOR_RESET)"
	@echo "$(COLOR_WARN)请设置环境变量:$(COLOR_RESET)"
	@echo "  - GIN_MODE=release"
	@echo "  - JWT_SECRET=<your-secret>"
	@echo "  - DATABASE_DSN=<your-database>"

version: ## 显示版本信息
	@echo "$(COLOR_INFO)TC-GO 图床系统 v1.0.0$(COLOR_RESET)"
	@echo "Go version: $$(go version)"
	@echo "Node version: $$(node --version)"
	@echo "NPM version: $$(npm --version)"
