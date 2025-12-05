-- utils/code_generator.lua
-- 短链代码生成工具

local _M = {}

-- Base62 字符集
local base62_charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

-- 生成随机字符串
local function random_string(length)
    local result = {}
    for i = 1, length do
        local index = math.random(1, #base62_charset)
        table.insert(result, base62_charset:sub(index, index))
    end
    return table.concat(result)
end

-- 生成短链代码
-- @param length 代码长度，默认为6
-- @return string 生成的代码
function _M.generate(length)
    length = length or 6
    return random_string(length)
end

-- 验证代码格式
-- @param code 待验证的代码
-- @param min_length 最小长度，默认为6
-- @param max_length 最大长度，默认为20
-- @return boolean 是否有效
-- @return string 错误信息（如果无效）
function _M.validate(code, min_length, max_length)
    min_length = min_length or 6
    max_length = max_length or 20

    if not code or type(code) ~= "string" then
        return false, "代码必须是字符串"
    end

    local len = #code
    if len < min_length or len > max_length then
        return false, string.format("代码长度必须在 %d-%d 个字符之间", min_length, max_length)
    end

    -- 只允许字母、数字、下划线、连字符
    if not code:match("^[a-zA-Z0-9_-]+$") then
        return false, "代码只能包含字母、数字、下划线和连字符"
    end

    return true
end

-- 检查代码是否为系统保留关键字
-- @param code 待检查的代码
-- @return boolean 是否为保留关键字
function _M.is_reserved(code)
    local reserved_keywords = {
        "api", "admin", "dashboard", "health", "stats",
        "metrics", "prometheus", "grafana",
        "create", "update", "delete", "batch",
        "redirect", "short", "link", "url",
        "test", "debug", "dev", "prod",
        "system", "root", "public", "private"
    }

    local lower_code = code:lower()
    for _, keyword in ipairs(reserved_keywords) do
        if lower_code == keyword then
            return true
        end
    end

    return false
end

return _M
