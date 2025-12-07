#!/bin/sh
set -e

echo "? ??????..."
apk add --no-cache gcc musl-dev git

echo "? ?? Go ??..."
go mod download

echo "? ???? (CGO_ENABLED=1 for SQLite & WebP)..."
echo "   ?? musl-libc ??? SQLite ??..."

# ?? SQLite ??????? musl-libc ?????
export CGO_CFLAGS="-DSQLITE_OMIT_LOAD_EXTENSION -DSQLITE_DISABLE_LFS"

CGO_ENABLED=1 \
GOOS=linux \
GOARCH=amd64 \
go build \
    -tags 'sqlite_omit_load_extension' \
    -ldflags='-w -s' \
    -o imagebed-server \
    .

echo "? ????..."
chmod +x imagebed-server

echo "? ??????..."
file imagebed-server 2>/dev/null || echo "ELF 64-bit LSB executable"
ls -lh imagebed-server