-- 简化版 lua-resty-http
-- 基于 https://github.com/ledgetech/lua-resty-http

local _M = { _VERSION = '0.17.1' }

local http = require "resty.http"

_M.new = function()
    return http.new()
end

return _M
