FROM openresty/openresty:alpine

# 安装基础工具和 libmaxminddb（OPM 需要 perl，maxminddb 需要 C 库）
RUN apk add --no-cache curl bash git perl tar libmaxminddb libmaxminddb-dev

# 使用 OPM 安装 lua-resty-http
RUN /usr/local/openresty/bin/opm get pintsized/lua-resty-http

# 手动安装 lua-resty-maxminddb（从 GitHub）
RUN mkdir -p /tmp/maxminddb && \
  cd /tmp/maxminddb && \
  curl -L https://github.com/anjia0532/lua-resty-maxminddb/archive/refs/heads/master.tar.gz -o maxminddb.tar.gz && \
  tar -xzf maxminddb.tar.gz && \
  mkdir -p /usr/local/openresty/site/lualib/resty && \
  cp lua-resty-maxminddb-master/lib/resty/maxminddb.lua /usr/local/openresty/site/lualib/resty/ && \
  cd / && rm -rf /tmp/maxminddb

# 手动安装 lua-prometheus（从 GitHub）
RUN mkdir -p /tmp/prometheus && \
  cd /tmp/prometheus && \
  curl -L https://github.com/knyar/nginx-lua-prometheus/archive/refs/heads/master.tar.gz -o prometheus.tar.gz && \
  tar -xzf prometheus.tar.gz && \
  cp nginx-lua-prometheus-main/prometheus.lua /usr/local/openresty/site/lualib/resty/ && \
  cp nginx-lua-prometheus-main/prometheus_keys.lua /usr/local/openresty/site/lualib/resty/ && \
  cp nginx-lua-prometheus-main/prometheus_resty_counter.lua /usr/local/openresty/site/lualib/resty/ && \
  cd / && rm -rf /tmp/prometheus

# 创建目录结构
RUN mkdir -p /usr/local/openresty/nginx/lua/api \
  /usr/local/openresty/nginx/lua/core \
  /usr/local/openresty/nginx/lua/utils \
  /usr/local/openresty/nginx/lua/storage \
  /usr/local/openresty/nginx/lua/strategies \
  /usr/local/openresty/nginx/lua/middleware \
  /usr/local/openresty/nginx/lua/conf \
  /usr/local/openresty/nginx/conf \
  /usr/local/openresty/nginx/geoip \
  /var/log/nginx

# 设置工作目录
WORKDIR /usr/local/openresty/nginx

# 暴露端口
EXPOSE 80 443

# 启动命令
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
