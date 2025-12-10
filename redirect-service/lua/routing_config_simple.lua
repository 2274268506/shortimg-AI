-- routing_config_simple.lua
-- 简化的路由配置（不依赖YAML，避免lyaml问题）

local _M = {}

-- CDN节点配置
_M.cdn_nodes = {
    -- 私有网络
    {
        id = "private",
        name = "私有网络CDN",
        domain = os.getenv("CDN_PRIVATE_DOMAIN") or "localhost",
        protocol = os.getenv("CDN_PRIVATE_PROTOCOL") or "http",
        port = os.getenv("CDN_PRIVATE_PORT") or "8080"
    },
    
    -- 图床服务器群组
    {
        id = "imagebed_unicom",
        name = "图床联通CDN",
        domain = os.getenv("CDN_IMAGEBED_UNICOM_DOMAIN") or "img-unicom.example.com",
        protocol = os.getenv("CDN_IMAGEBED_UNICOM_PROTOCOL") or "https",
        port = os.getenv("CDN_IMAGEBED_UNICOM_PORT") or ""
    },
    {
        id = "imagebed_mobile",
        name = "图床移动CDN",
        domain = os.getenv("CDN_IMAGEBED_MOBILE_DOMAIN") or "img-mobile.example.com",
        protocol = os.getenv("CDN_IMAGEBED_MOBILE_PROTOCOL") or "https",
        port = os.getenv("CDN_IMAGEBED_MOBILE_PORT") or ""
    },
    {
        id = "imagebed_telecom",
        name = "图床电信CDN",
        domain = os.getenv("CDN_IMAGEBED_TELECOM_DOMAIN") or "img-telecom.example.com",
        protocol = os.getenv("CDN_IMAGEBED_TELECOM_PROTOCOL") or "https",
        port = os.getenv("CDN_IMAGEBED_TELECOM_PORT") or ""
    },
    {
        id = "imagebed_overseas",
        name = "图床海外CDN",
        domain = os.getenv("CDN_IMAGEBED_OVERSEAS_DOMAIN") or "img-overseas.example.com",
        protocol = os.getenv("CDN_IMAGEBED_OVERSEAS_PROTOCOL") or "https",
        port = os.getenv("CDN_IMAGEBED_OVERSEAS_PORT") or ""
    },
    {
        id = "imagebed_default",
        name = "图床默认CDN",
        domain = os.getenv("CDN_IMAGEBED_DEFAULT_DOMAIN") or "img-cdn.example.com",
        protocol = os.getenv("CDN_IMAGEBED_DEFAULT_PROTOCOL") or "https",
        port = os.getenv("CDN_IMAGEBED_DEFAULT_PORT") or ""
    },
    
    -- 文件服务器群组
    {
        id = "file_unicom",
        name = "文件联通CDN",
        domain = os.getenv("CDN_FILE_UNICOM_DOMAIN") or "file-unicom.example.com",
        protocol = os.getenv("CDN_FILE_UNICOM_PROTOCOL") or "https",
        port = os.getenv("CDN_FILE_UNICOM_PORT") or ""
    },
    {
        id = "file_mobile",
        name = "文件移动CDN",
        domain = os.getenv("CDN_FILE_MOBILE_DOMAIN") or "file-mobile.example.com",
        protocol = os.getenv("CDN_FILE_MOBILE_PROTOCOL") or "https",
        port = os.getenv("CDN_FILE_MOBILE_PORT") or ""
    },
    {
        id = "file_telecom",
        name = "文件电信CDN",
        domain = os.getenv("CDN_FILE_TELECOM_DOMAIN") or "file-telecom.example.com",
        protocol = os.getenv("CDN_FILE_TELECOM_PROTOCOL") or "https",
        port = os.getenv("CDN_FILE_TELECOM_PORT") or ""
    },
    {
        id = "file_overseas",
        name = "文件海外CDN",
        domain = os.getenv("CDN_FILE_OVERSEAS_DOMAIN") or "file-overseas.example.com",
        protocol = os.getenv("CDN_FILE_OVERSEAS_PROTOCOL") or "https",
        port = os.getenv("CDN_FILE_OVERSEAS_PORT") or ""
    },
    {
        id = "file_default",
        name = "文件默认CDN",
        domain = os.getenv("CDN_FILE_DEFAULT_DOMAIN") or "file-cdn.example.com",
        protocol = os.getenv("CDN_FILE_DEFAULT_PROTOCOL") or "https",
        port = os.getenv("CDN_FILE_DEFAULT_PORT") or ""
    },
    
    -- 视频服务器群组
    {
        id = "video_unicom",
        name = "视频联通CDN",
        domain = os.getenv("CDN_VIDEO_UNICOM_DOMAIN") or "video-unicom.example.com",
        protocol = os.getenv("CDN_VIDEO_UNICOM_PROTOCOL") or "https",
        port = os.getenv("CDN_VIDEO_UNICOM_PORT") or ""
    },
    {
        id = "video_mobile",
        name = "视频移动CDN",
        domain = os.getenv("CDN_VIDEO_MOBILE_DOMAIN") or "video-mobile.example.com",
        protocol = os.getenv("CDN_VIDEO_MOBILE_PROTOCOL") or "https",
        port = os.getenv("CDN_VIDEO_MOBILE_PORT") or ""
    },
    {
        id = "video_telecom",
        name = "视频电信CDN",
        domain = os.getenv("CDN_VIDEO_TELECOM_DOMAIN") or "video-telecom.example.com",
        protocol = os.getenv("CDN_VIDEO_TELECOM_PROTOCOL") or "https",
        port = os.getenv("CDN_VIDEO_TELECOM_PORT") or ""
    },
    {
        id = "video_overseas",
        name = "视频海外CDN",
        domain = os.getenv("CDN_VIDEO_OVERSEAS_DOMAIN") or "video-overseas.example.com",
        protocol = os.getenv("CDN_VIDEO_OVERSEAS_PROTOCOL") or "https",
        port = os.getenv("CDN_VIDEO_OVERSEAS_PORT") or ""
    },
    {
        id = "video_default",
        name = "视频默认CDN",
        domain = os.getenv("CDN_VIDEO_DEFAULT_DOMAIN") or "video-cdn.example.com",
        protocol = os.getenv("CDN_VIDEO_DEFAULT_PROTOCOL") or "https",
        port = os.getenv("CDN_VIDEO_DEFAULT_PORT") or ""
    }
    
    -- 注意：通用类型(general)不需要CDN服务器群组
    -- 因为通用短链直接重定向到完整URL，不经过CDN分流
}

-- 路由规则配置
_M.routing_rules = {
    -- 内网IP路由
    {
        name = "内网IP路由",
        priority = 10,
        enabled = true,
        conditions = {
            {
                type = "ip_range",
                ranges = {"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8"}
            }
        },
        target = "private"
    },
    
    -- 图床类型路由规则
    {
        name = "图床_电信",
        priority = 20,
        enabled = true,
        conditions = {
            {type = "service_type", value = "imagebed"},
            {type = "isp", values = {"China Telecom", "ChinaNet", "电信"}}
        },
        target = "imagebed_telecom"
    },
    {
        name = "图床_联通",
        priority = 21,
        enabled = true,
        conditions = {
            {type = "service_type", value = "imagebed"},
            {type = "isp", values = {"China Unicom", "联通"}}
        },
        target = "imagebed_unicom"
    },
    {
        name = "图床_移动",
        priority = 22,
        enabled = true,
        conditions = {
            {type = "service_type", value = "imagebed"},
            {type = "isp", values = {"China Mobile", "移动"}}
        },
        target = "imagebed_mobile"
    },
    {
        name = "图床_海外",
        priority = 23,
        enabled = true,
        conditions = {
            {type = "service_type", value = "imagebed"},
            {type = "country", operator = "not_equals", value = "CN"}
        },
        target = "imagebed_overseas"
    },
    {
        name = "图床_国内默认",
        priority = 24,
        enabled = true,
        conditions = {
            {type = "service_type", value = "imagebed"}
        },
        target = "imagebed_default"
    },
    
    -- 文件类型路由规则
    {
        name = "文件_电信",
        priority = 30,
        enabled = true,
        conditions = {
            {type = "service_type", value = "file"},
            {type = "isp", values = {"China Telecom", "ChinaNet", "电信"}}
        },
        target = "file_telecom"
    },
    {
        name = "文件_联通",
        priority = 31,
        enabled = true,
        conditions = {
            {type = "service_type", value = "file"},
            {type = "isp", values = {"China Unicom", "联通"}}
        },
        target = "file_unicom"
    },
    {
        name = "文件_移动",
        priority = 32,
        enabled = true,
        conditions = {
            {type = "service_type", value = "file"},
            {type = "isp", values = {"China Mobile", "移动"}}
        },
        target = "file_mobile"
    },
    {
        name = "文件_海外",
        priority = 33,
        enabled = true,
        conditions = {
            {type = "service_type", value = "file"},
            {type = "country", operator = "not_equals", value = "CN"}
        },
        target = "file_overseas"
    },
    {
        name = "文件_国内默认",
        priority = 34,
        enabled = true,
        conditions = {
            {type = "service_type", value = "file"}
        },
        target = "file_default"
    },
    
    -- 视频类型路由规则
    {
        name = "视频_电信",
        priority = 40,
        enabled = true,
        conditions = {
            {type = "service_type", value = "video"},
            {type = "isp", values = {"China Telecom", "ChinaNet", "电信"}}
        },
        target = "video_telecom"
    },
    {
        name = "视频_联通",
        priority = 41,
        enabled = true,
        conditions = {
            {type = "service_type", value = "video"},
            {type = "isp", values = {"China Unicom", "联通"}}
        },
        target = "video_unicom"
    },
    {
        name = "视频_移动",
        priority = 42,
        enabled = true,
        conditions = {
            {type = "service_type", value = "video"},
            {type = "isp", values = {"China Mobile", "移动"}}
        },
        target = "video_mobile"
    },
    {
        name = "视频_海外",
        priority = 43,
        enabled = true,
        conditions = {
            {type = "service_type", value = "video"},
            {type = "country", operator = "not_equals", value = "CN"}
        },
        target = "video_overseas"
    },
    {
        name = "视频_国内默认",
        priority = 44,
        enabled = true,
        conditions = {
            {type = "service_type", value = "video"}
        },
        target = "video_default"
    }
    
    -- 注意：通用类型(general)不需要路由规则
    -- 因为通用短链直接重定向到完整URL，不经过CDN分流
}

-- 默认路由配置（用于无法匹配任何规则时的降级处理）
_M.default_routing = {
    target = "private"  -- 降级到内网CDN
}

return _M
