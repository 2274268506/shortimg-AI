-- API 密钥管理表
USE `short_links`;

CREATE TABLE IF NOT EXISTS `api_keys` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `api_key` VARCHAR(64) NOT NULL COMMENT 'API密钥（sk_开头）',
    `name` VARCHAR(100) NOT NULL COMMENT '密钥名称',
    `allowed_domains` TEXT DEFAULT NULL COMMENT '允许的域名（逗号分隔，*表示所有）',
    `max_requests_per_day` INT UNSIGNED DEFAULT 10000 COMMENT '每日最大请求数（0表示无限制）',
    `current_requests` INT UNSIGNED DEFAULT 0 COMMENT '当前请求计数',
    `last_reset_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT '上次重置时间',
    `is_active` TINYINT(1) DEFAULT 1 COMMENT '是否激活',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `last_used_at` TIMESTAMP NULL DEFAULT NULL COMMENT '最后使用时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_api_key` (`api_key`),
    KEY `idx_is_active` (`is_active`),
    KEY `idx_created_at` (`created_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = 'API密钥表';

-- 插入测试API Key
INSERT IGNORE INTO
    `api_keys` (
        `api_key`,
        `name`,
        `allowed_domains`,
        `max_requests_per_day`,
        `is_active`
    )
VALUES (
        'sk_test_12345678901234567890123456789012',
        '测试密钥',
        '*',
        0,
        1
    );

SELECT '✅ API 密钥表创建成功！' AS status;

SELECT *
FROM `api_keys`
WHERE
    `api_key` = 'sk_test_12345678901234567890123456789012';
