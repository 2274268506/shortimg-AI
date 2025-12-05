-- Prometheus metric library for nginx-lua

local ngx_shared = ngx.shared
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_WARN = ngx.WARN
local setmetatable = setmetatable
local tostring = tostring
local table_insert = table.insert
local table_concat = table.concat
local string_format = string.format
local math_floor = math.floor

local _M = {}
local mt = { __index = _M }

-- Initialize Prometheus instance
function _M.init(dict_name, prefix)
    local self = setmetatable({}, mt)
    self.dict = ngx_shared[dict_name]
    if not self.dict then
        ngx_log(ngx_ERR, "Prometheus: shared dictionary '", dict_name, "' not found")
        return nil
    end
    self.prefix = prefix or ""
    self.metrics = {}
    self.initialized = true
    return self
end

-- Counter metric
function _M:counter(name, help, label_names)
    local metric = {
        name = self.prefix .. name,
        help = help,
        type = "counter",
        label_names = label_names or {},
    }
    self.metrics[name] = metric
    return {
        inc = function(labels, value)
            local key = self:_key(metric.name, labels or {})
            local newval, err = self.dict:incr(key, value or 1, 0)
            if not newval then
                ngx_log(ngx_ERR, "Prometheus: inc failed: ", err)
            end
        end
    }
end

-- Histogram metric
function _M:histogram(name, help, label_names, buckets)
    buckets = buckets or {0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}
    local metric = {
        name = self.prefix .. name,
        help = help,
        type = "histogram",
        label_names = label_names or {},
        buckets = buckets,
    }
    self.metrics[name] = metric

    return {
        observe = function(labels, value)
            labels = labels or {}
            -- Update sum
            local sum_key = self:_key(metric.name .. "_sum", labels)
            local newval, err = self.dict:incr(sum_key, value, 0)
            if not newval then
                ngx_log(ngx_ERR, "Prometheus: histogram sum failed: ", err)
            end

            -- Update count
            local count_key = self:_key(metric.name .. "_count", labels)
            newval, err = self.dict:incr(count_key, 1, 0)
            if not newval then
                ngx_log(ngx_ERR, "Prometheus: histogram count failed: ", err)
            end

            -- Update buckets
            for _, bucket in ipairs(buckets) do
                if value <= bucket then
                    local bucket_labels = self:_merge_labels(labels, {le = tostring(bucket)})
                    local bucket_key = self:_key(metric.name .. "_bucket", bucket_labels)
                    newval, err = self.dict:incr(bucket_key, 1, 0)
                    if not newval then
                        ngx_log(ngx_ERR, "Prometheus: histogram bucket failed: ", err)
                    end
                end
            end

            -- +Inf bucket
            local inf_labels = self:_merge_labels(labels, {le = "+Inf"})
            local inf_key = self:_key(metric.name .. "_bucket", inf_labels)
            newval, err = self.dict:incr(inf_key, 1, 0)
            if not newval then
                ngx_log(ngx_ERR, "Prometheus: histogram +Inf bucket failed: ", err)
            end
        end
    }
end

-- Gauge metric
function _M:gauge(name, help, label_names)
    local metric = {
        name = self.prefix .. name,
        help = help,
        type = "gauge",
        label_names = label_names or {},
    }
    self.metrics[name] = metric

    return {
        set = function(labels, value)
            local key = self:_key(metric.name, labels or {})
            local ok, err = self.dict:set(key, value)
            if not ok then
                ngx_log(ngx_ERR, "Prometheus: gauge set failed: ", err)
            end
        end,
        inc = function(labels, value)
            local key = self:_key(metric.name, labels or {})
            local newval, err = self.dict:incr(key, value or 1, 0)
            if not newval then
                ngx_log(ngx_ERR, "Prometheus: gauge inc failed: ", err)
            end
        end,
        dec = function(labels, value)
            local key = self:_key(metric.name, labels or {})
            local newval, err = self.dict:incr(key, -(value or 1), 0)
            if not newval then
                ngx_log(ngx_ERR, "Prometheus: gauge dec failed: ", err)
            end
        end
    }
end

-- Generate metric key with labels
function _M:_key(name, labels)
    if not labels or next(labels) == nil then
        return name
    end

    local parts = {}
    for k, v in pairs(labels) do
        table_insert(parts, k .. '="' .. tostring(v) .. '"')
    end
    table.sort(parts)
    return name .. "{" .. table_concat(parts, ",") .. "}"
end

-- Merge label tables
function _M:_merge_labels(labels1, labels2)
    local result = {}
    for k, v in pairs(labels1) do
        result[k] = v
    end
    for k, v in pairs(labels2) do
        result[k] = v
    end
    return result
end

-- Collect all metrics in Prometheus format
function _M:collect()
    local output = {}

    for name, metric in pairs(self.metrics) do
        table_insert(output, "# HELP " .. metric.name .. " " .. (metric.help or ""))
        table_insert(output, "# TYPE " .. metric.name .. " " .. metric.type)

        -- Get all keys for this metric
        local keys = self.dict:get_keys(0)
        for _, key in ipairs(keys) do
            if key:sub(1, #metric.name) == metric.name then
                local value = self.dict:get(key)
                if value then
                    table_insert(output, key .. " " .. tostring(value))
                end
            end
        end
    end

    return table_concat(output, "\n") .. "\n"
end

return _M
