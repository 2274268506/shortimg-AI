-- 数据库迁移：添加日志汇总表
-- 用于存储按天汇总的访问日志，提升统计查询性能

-- 创建按日汇总的访问日志表
CREATE TABLE IF NOT EXISTS access_logs_daily (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    short_code VARCHAR(50) NOT NULL COMMENT '短链代码',
    log_date DATE NOT NULL COMMENT '日期',
    total_visits INT UNSIGNED DEFAULT 0 COMMENT '总访问量',
    unique_visitors INT UNSIGNED DEFAULT 0 COMMENT '独立访客数',
    total_response_time DECIMAL(10, 2) DEFAULT 0 COMMENT '总响应时间(ms)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_short_code_date (short_code, log_date),
    KEY idx_log_date (log_date),
    KEY idx_short_code (short_code)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '按日汇总的访问日志';

-- 创建按月汇总的访问日志表
CREATE TABLE IF NOT EXISTS access_logs_monthly (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    short_code VARCHAR(50) NOT NULL COMMENT '短链代码',
    log_month VARCHAR(7) NOT NULL COMMENT '月份(YYYY-MM)',
    total_visits INT UNSIGNED DEFAULT 0 COMMENT '总访问量',
    unique_visitors INT UNSIGNED DEFAULT 0 COMMENT '独立访客数',
    avg_response_time DECIMAL(10, 2) DEFAULT 0 COMMENT '平均响应时间(ms)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_short_code_month (short_code, log_month),
    KEY idx_log_month (log_month),
    KEY idx_short_code (short_code)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '按月汇总的访问日志';

-- 创建地区访问统计表
CREATE TABLE IF NOT EXISTS access_stats_geo (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    short_code VARCHAR(50) NOT NULL COMMENT '短链代码',
    country VARCHAR(100) DEFAULT NULL COMMENT '国家',
    province VARCHAR(100) DEFAULT NULL COMMENT '省份',
    city VARCHAR(100) DEFAULT NULL COMMENT '城市',
    visit_count INT UNSIGNED DEFAULT 0 COMMENT '访问次数',
    unique_visitors INT UNSIGNED DEFAULT 0 COMMENT '独立访客',
    last_visit_time TIMESTAMP NULL COMMENT '最后访问时间',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_short_code_location (
        short_code,
        country,
        province,
        city
    ),
    KEY idx_short_code (short_code),
    KEY idx_country (country)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '地区访问统计';

-- 创建设备类型统计表
CREATE TABLE IF NOT EXISTS access_stats_device (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    short_code VARCHAR(50) NOT NULL COMMENT '短链代码',
    device_type VARCHAR(50) DEFAULT NULL COMMENT '设备类型',
    visit_count INT UNSIGNED DEFAULT 0 COMMENT '访问次数',
    unique_visitors INT UNSIGNED DEFAULT 0 COMMENT '独立访客',
    avg_response_time DECIMAL(10, 2) DEFAULT 0 COMMENT '平均响应时间',
    last_visit_time TIMESTAMP NULL COMMENT '最后访问时间',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_short_code_device (short_code, device_type),
    KEY idx_short_code (short_code)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '设备类型统计';

-- 创建实时统计缓存表（Redis 备份）
CREATE TABLE IF NOT EXISTS realtime_stats_cache (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    short_code VARCHAR(50) NOT NULL COMMENT '短链代码',
    stats_type VARCHAR(50) NOT NULL COMMENT '统计类型',
    stats_data JSON COMMENT '统计数据',
    cache_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '缓存时间',
    expires_at TIMESTAMP NULL COMMENT '过期时间',
    UNIQUE KEY uk_short_code_type (short_code, stats_type),
    KEY idx_expires_at (expires_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '实时统计缓存';

-- 添加访问日志分区（按月分区，提升查询性能）
-- 注意：如果表已有数据，需要先备份数据再执行分区

-- ALTER TABLE access_logs PARTITION BY RANGE (UNIX_TIMESTAMP(access_time)) (
--     PARTITION p202401 VALUES LESS THAN (UNIX_TIMESTAMP('2024-02-01')),
--     PARTITION p202402 VALUES LESS THAN (UNIX_TIMESTAMP('2024-03-01')),
--     PARTITION p202403 VALUES LESS THAN (UNIX_TIMESTAMP('2024-04-01')),
--     PARTITION p202404 VALUES LESS THAN (UNIX_TIMESTAMP('2024-05-01')),
--     PARTITION p202405 VALUES LESS THAN (UNIX_TIMESTAMP('2024-06-01')),
--     PARTITION p202406 VALUES LESS THAN (UNIX_TIMESTAMP('2024-07-01')),
--     PARTITION pmax VALUES LESS THAN MAXVALUE
-- );

-- 创建性能优化视图
CREATE OR REPLACE VIEW v_link_stats_summary AS
SELECT
    sl.short_code,
    sl.status,
    sl.strategy,
    sl.visit_count,
    COUNT(DISTINCT al.ip_address) as unique_visitors,
    COUNT(al.id) as total_access_logs,
    AVG(al.response_time) as avg_response_time,
    MAX(al.access_time) as last_access_time,
    sl.created_at,
    sl.updated_at
FROM
    short_links sl
    LEFT JOIN access_logs al ON sl.short_code = al.short_code
GROUP BY
    sl.short_code,
    sl.status,
    sl.strategy,
    sl.visit_count,
    sl.created_at,
    sl.updated_at;
