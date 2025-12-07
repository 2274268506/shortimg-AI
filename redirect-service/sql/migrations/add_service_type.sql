-- 添加 service_type 字段
-- 执行时间: 2025-12-06

USE `short_links`;

-- 添加 service_type 字段
ALTER TABLE `short_links`
ADD COLUMN `service_type` VARCHAR(32) NOT NULL DEFAULT 'general' COMMENT '服务类型: general, imagebed, custom' AFTER `security_config`;

-- 添加索引
ALTER TABLE `short_links`
ADD KEY `idx_service_type` (`service_type`);

-- 更新现有数据：根据 short_code 前缀判断类型
UPDATE `short_links`
SET
    `service_type` = 'imagebed'
WHERE
    `short_code` LIKE 'img-%';

-- 验证
SELECT service_type, COUNT(*) as count
FROM short_links
GROUP BY
    service_type;
