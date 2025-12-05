-- SQL Schema for Short Links Redirect Service
-- 短链重定向服务数据库表结构

-- 创建数据库
CREATE DATABASE IF NOT EXISTS `short_links` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `short_links`;

-- 短链表
CREATE TABLE IF NOT EXISTS `short_links` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `short_code` VARCHAR(32) NOT NULL COMMENT '短链码',
    `targets` JSON NOT NULL COMMENT '目标URL列表（JSON数组）',
    `strategy` VARCHAR(32) NOT NULL DEFAULT 'weight' COMMENT '分流策略: weight, geo, ip, asn, hash',
    `security_config` JSON DEFAULT NULL COMMENT '安全配置（referer白名单、token密钥等）',
    `status` ENUM('active', 'paused', 'deleted') NOT NULL DEFAULT 'active' COMMENT '状态',
    `visit_count` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '访问次数',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    `expires_at` TIMESTAMP NULL DEFAULT NULL COMMENT '过期时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_short_code` (`short_code`),
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_expires_at` (`expires_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '短链表';

-- 访问日志表
CREATE TABLE IF NOT EXISTS `access_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `short_code` VARCHAR(32) NOT NULL COMMENT '短链码',
    `target_url` VARCHAR(512) NOT NULL COMMENT '目标URL',
    `client_ip` VARCHAR(45) NOT NULL COMMENT '客户端IP',
    `country` VARCHAR(32) DEFAULT NULL COMMENT '国家',
    `province` VARCHAR(64) DEFAULT NULL COMMENT '省份',
    `city` VARCHAR(64) DEFAULT NULL COMMENT '城市',
    `isp` VARCHAR(64) DEFAULT NULL COMMENT '运营商',
    `asn` VARCHAR(32) DEFAULT NULL COMMENT 'ASN号',
    `device_type` ENUM(
        'desktop',
        'mobile',
        'tablet',
        'unknown'
    ) DEFAULT 'unknown' COMMENT '设备类型',
    `user_agent` VARCHAR(512) DEFAULT NULL COMMENT 'User-Agent',
    `referer` VARCHAR(512) DEFAULT NULL COMMENT 'Referer',
    `response_time` INT UNSIGNED DEFAULT 0 COMMENT '响应时间（毫秒）',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '访问时间',
    PRIMARY KEY (`id`),
    KEY `idx_short_code` (`short_code`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_client_ip` (`client_ip`),
    KEY `idx_country_province` (`country`, `province`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = '访问日志表';

-- 分区访问日志表（按月分区，提升查询性能）
-- 如果数据量大，建议使用分区表
/*
CREATE TABLE IF NOT EXISTS `access_logs_partitioned` (
-- 字段同上 access_logs
...
`created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '访问时间',
PRIMARY KEY (`id`, `created_at`),
KEY `idx_short_code` (`short_code`),
KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
PARTITION BY RANGE (UNIX_TIMESTAMP(`created_at`)) (
PARTITION p202401 VALUES LESS THAN (UNIX_TIMESTAMP('2024-02-01')),
PARTITION p202402 VALUES LESS THAN (UNIX_TIMESTAMP('2024-03-01')),
-- 继续添加分区...
PARTITION pmax VALUES LESS THAN MAXVALUE
);
*/

-- IP 黑名单表
CREATE TABLE IF NOT EXISTS `ip_blacklist` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `ip` VARCHAR(45) NOT NULL COMMENT 'IP地址',
    `reason` VARCHAR(255) DEFAULT NULL COMMENT '封禁原因',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `expires_at` TIMESTAMP NULL DEFAULT NULL COMMENT '过期时间（NULL表示永久）',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_ip` (`ip`),
    KEY `idx_expires_at` (`expires_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci COMMENT = 'IP黑名单表';

-- 插入示例数据（使用方式2：CDN标识 + 路径，推荐）
INSERT INTO
    `short_links` (
        `short_code`,
        `targets`,
        `strategy`,
        `security_config`
    )
VALUES (
        'tc-go-demo',
        '[
        {"cdn": "north_telecom", "path": "/uploads/demo/image.jpg", "region": "cn-north", "isp": "telecom", "weight": 5},
        {"cdn": "south_unicom", "path": "/uploads/demo/image.jpg", "region": "cn-south", "isp": "unicom", "weight": 3},
        {"cdn": "overseas", "path": "/uploads/demo/image.jpg", "region": "overseas", "weight": 2}
    ]',
        'geo+weight',
        '{
        "referer_whitelist": ["*.example.com", "localhost"],
        "token_secret": "your-secret-key-here",
        "ip_blacklist_enabled": true,
        "rate_limit": {
            "enabled": true,
            "max_requests": 100,
            "window": 60
        }
    }'
    );

-- 创建视图：访问统计汇总
CREATE OR REPLACE VIEW `v_access_stats` AS
SELECT
    l.short_code,
    l.status,
    COUNT(a.id) AS total_visits,
    COUNT(DISTINCT a.client_ip) AS unique_visitors,
    AVG(a.response_time) AS avg_response_time,
    DATE(a.created_at) AS visit_date
FROM
    `short_links` l
    LEFT JOIN `access_logs` a ON l.short_code = a.short_code
WHERE
    a.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY
    l.short_code,
    l.status,
    DATE(a.created_at);

-- 索引优化建议
-- 1. 根据实际查询模式添加复合索引
-- 2. 定期清理过期的访问日志（建议保留 30-90 天）
-- 3. 考虑使用 InnoDB 的全文索引或 Elasticsearch 进行日志分析
