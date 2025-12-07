# 多阶段构建 Dockerfile - 使用 Debian
# 第一阶段：编译
FROM golang:1.24-bookworm AS builder

WORKDIR /build

# 复制 go mod 文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 编译（启用 CGO 以支持 SQLite）
RUN CGO_ENABLED=1 GOOS=linux go build -a -o imagebed main.go

# 第二阶段：运行
FROM debian:bookworm-slim

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
  ca-certificates \
  tzdata \
  libwebp7 \
  wget \
  && rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Shanghai
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /build/imagebed .

# 创建必要的目录
RUN mkdir -p uploads logs data \
  && groupadd -g 1000 appuser \
  && useradd -u 1000 -g appuser -s /bin/bash -m appuser \
  && chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

CMD ["./imagebed"]
