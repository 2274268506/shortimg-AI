local mysql = require "resty.mysql"
local db = mysql:new()
db:set_timeout(5000)

print("连接配置:")
print("  Host: " .. (os.getenv("MYSQL_HOST") or "mysql"))
print("  Port: " .. (os.getenv("MYSQL_PORT") or "3306"))
print("  Database: " .. (os.getenv("MYSQL_DATABASE") or "short_links"))
print("  User: " .. (os.getenv("MYSQL_USER") or "root"))

local ok, err = db:connect({
    host = os.getenv("MYSQL_HOST") or "mysql",
    port = tonumber(os.getenv("MYSQL_PORT")) or 3306,
    database = os.getenv("MYSQL_DATABASE") or "short_links",
    user = os.getenv("MYSQL_USER") or "root",
    password = os.getenv("MYSQL_PASSWORD") or "",
    charset = "utf8mb4"
})

if not ok then
    print("连接失败: " .. (err or "unknown"))
    os.exit(1)
end

print("连接成功！")

local res, err = db:query("SELECT COUNT(*) as cnt FROM short_links")
if not res then
    print("查询失败: " .. (err or "unknown"))
else
    print("表中记录数: " .. res[1].cnt)
end

db:close()
