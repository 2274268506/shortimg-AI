-- core/worker.lua
-- Worker 进程初始化

local scheduler = require "core.scheduler"

-- Worker 进程启动时执行
ngx.log(ngx.INFO, "Worker 进程启动，PID: ", ngx.worker.pid())

-- 只在第一个 Worker 进程中启动定时任务
if ngx.worker.id() == 0 then
    ngx.log(ngx.INFO, "在 Worker 0 中启动定时任务调度器")

    -- 创建定时器，每分钟检查一次是否有需要执行的任务
    local function schedule_timer()
        local ok, err = ngx.timer.at(60, function(premature)
            if not premature then
                -- 执行定时任务检查
                scheduler.run()

                -- 递归创建下一个定时器
                schedule_timer()
            end
        end)

        if not ok then
            ngx.log(ngx.ERR, "创建定时器失败: ", err)
        end
    end

    -- 启动定时器
    schedule_timer()
else
    ngx.log(ngx.INFO, "Worker ", ngx.worker.id(), " 不启动定时任务")
end

-- 预热连接池（测试环境禁用 - init_worker 阶段不允许网络操作）
-- local redis_client = require "storage.redis_client"
-- local mysql_client = require "storage.mysql_client"

-- 测试 Redis 连接
-- local ok, err = redis_client.get("warmup")
-- if err then
--     ngx.log(ngx.WARN, "Redis 连接预热失败: ", err)
-- else
--     ngx.log(ngx.INFO, "Redis 连接预热成功")
-- end

-- 测试 MySQL 连接
-- local link, err = mysql_client.get_link("warmup")
-- if err then
--     ngx.log(ngx.WARN, "MySQL 连接预热失败: ", err)
-- else
--     ngx.log(ngx.INFO, "MySQL 连接预热成功")
-- end

ngx.log(ngx.INFO, "Worker initialized (connection warmup disabled for testing)")
