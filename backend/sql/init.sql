-- ==========================================
-- TC-GO 图床系统 MySQL 数据库初始化脚本
-- ==========================================

-- 创建数据库 (如果不存在)
CREATE DATABASE IF NOT EXISTS imagebed CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE imagebed;

-- 设置字符集
SET NAMES utf8mb4;

SET CHARACTER_SET_CLIENT = utf8mb4;

SET CHARACTER_SET_CONNECTION = utf8mb4;

SET CHARACTER_SET_RESULTS = utf8mb4;

-- 注意: 表结构由 Go 应用的 GORM 自动迁移创建
-- 这个脚本主要用于创建数据库和设置字符集

-- 可选: 创建初始管理员用户 (密码需要在应用中生成)
-- 默认管理员:
-- 用户名: admin
-- 密码: admin123 (首次登录后请立即修改)
