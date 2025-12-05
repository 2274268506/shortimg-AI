FROM openresty/openresty:alpine

# 安装基础工具
RUN apk add --no-cache curl bash

# 创建目录结构
RUN mkdir -p /usr/local/openresty/nginx/lua/api \
  /usr/local/openresty/nginx/lua/core \
  /usr/local/openresty/nginx/lua/utils \
  /usr/local/openresty/nginx/conf \
  /var/log/nginx

# 设置工作目录
WORKDIR /usr/local/openresty/nginx

# 暴露端口
EXPOSE 80 443

# 启动命令
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
