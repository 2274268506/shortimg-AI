#!/bin/bash
# 运行单元测试

# 安装 busted（如果未安装）
if ! command -v busted &> /dev/null; then
    echo "正在安装 busted 测试框架..."
    luarocks install busted
fi

# 运行测试
echo "正在运行单元测试..."
busted tests/unit/

# 生成覆盖率报告（可选）
# luacov tests/unit/
