#!/bin/bash
# WebDAV和SFTP存储测试脚本

echo "========================================="
echo "TC-GO 存储测试工具"
echo "========================================="
echo ""

# 测试文件
TEST_FILE="test_image.txt"
echo "This is a test file for storage verification." > $TEST_FILE

# 读取配置
echo "请选择要测试的存储类型:"
echo "1. WebDAV (坚果云)"
echo "2. SFTP (SSH服务器)"
read -p "请输入选项 (1/2): " CHOICE

case $CHOICE in
    1)
        echo ""
        echo "=== WebDAV 连接测试 ==="
        read -p "WebDAV URL (例: https://dav.jianguoyun.com/dav/): " WEBDAV_URL
        read -p "用户名/邮箱: " WEBDAV_USER
        read -sp "密码 (应用密码): " WEBDAV_PASS
        echo ""

        echo "正在测试连接..."

        # 使用curl测试WebDAV连接
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PROPFIND \
            -u "$WEBDAV_USER:$WEBDAV_PASS" \
            "$WEBDAV_URL")

        if [ "$STATUS" == "207" ] || [ "$STATUS" == "200" ]; then
            echo "✅ WebDAV连接成功 (HTTP $STATUS)"

            # 测试文件上传
            echo "正在测试文件上传..."
            UPLOAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
                -X PUT \
                -u "$WEBDAV_USER:$WEBDAV_PASS" \
                --data-binary @$TEST_FILE \
                "${WEBDAV_URL}${TEST_FILE}")

            if [ "$UPLOAD_STATUS" == "201" ] || [ "$UPLOAD_STATUS" == "204" ]; then
                echo "✅ 文件上传成功 (HTTP $UPLOAD_STATUS)"

                # 测试文件删除
                echo "正在清理测试文件..."
                curl -s -X DELETE \
                    -u "$WEBDAV_USER:$WEBDAV_PASS" \
                    "${WEBDAV_URL}${TEST_FILE}" > /dev/null
                echo "✅ 测试完成"
            else
                echo "❌ 文件上传失败 (HTTP $UPLOAD_STATUS)"
            fi
        else
            echo "❌ WebDAV连接失败 (HTTP $STATUS)"
            echo "提示: 坚果云需要使用应用密码，不是登录密码"
            echo "获取应用密码: 坚果云网页版 → 账户信息 → 安全选项 → 添加应用"
        fi
        ;;

    2)
        echo ""
        echo "=== SFTP 连接测试 ==="
        read -p "服务器地址: " SFTP_HOST
        read -p "端口 (默认22): " SFTP_PORT
        SFTP_PORT=${SFTP_PORT:-22}
        read -p "用户名: " SFTP_USER
        read -p "认证方式 (1=密码, 2=密钥): " AUTH_TYPE

        if [ "$AUTH_TYPE" == "1" ]; then
            # 密码认证
            echo "正在测试SSH连接 (密码认证)..."
            ssh -p $SFTP_PORT -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
                $SFTP_USER@$SFTP_HOST "echo '✅ SSH连接成功'" 2>/dev/null

            if [ $? -eq 0 ]; then
                echo "正在测试SFTP文件操作..."
                echo "put $TEST_FILE" | sftp -P $SFTP_PORT -o StrictHostKeyChecking=no \
                    $SFTP_USER@$SFTP_HOST 2>/dev/null

                if [ $? -eq 0 ]; then
                    echo "✅ SFTP文件上传成功"
                    # 清理
                    echo "rm $TEST_FILE" | sftp -P $SFTP_PORT -o StrictHostKeyChecking=no \
                        $SFTP_USER@$SFTP_HOST 2>/dev/null
                    echo "✅ 测试完成"
                else
                    echo "❌ SFTP文件上传失败"
                fi
            else
                echo "❌ SSH连接失败"
                echo "请检查: 服务器地址、端口、用户名、密码"
            fi
        else
            # 密钥认证
            read -p "私钥路径 (例: ~/.ssh/id_rsa): " KEY_PATH
            KEY_PATH=${KEY_PATH/#\~/$HOME}  # 展开 ~ 符号

            if [ ! -f "$KEY_PATH" ]; then
                echo "❌ 私钥文件不存在: $KEY_PATH"
                exit 1
            fi

            echo "正在测试SSH连接 (密钥认证)..."
            ssh -p $SFTP_PORT -i "$KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
                $SFTP_USER@$SFTP_HOST "echo '✅ SSH连接成功'" 2>/dev/null

            if [ $? -eq 0 ]; then
                echo "正在测试SFTP文件操作..."
                echo "put $TEST_FILE" | sftp -P $SFTP_PORT -i "$KEY_PATH" \
                    -o StrictHostKeyChecking=no $SFTP_USER@$SFTP_HOST 2>/dev/null

                if [ $? -eq 0 ]; then
                    echo "✅ SFTP文件上传成功"
                    # 清理
                    echo "rm $TEST_FILE" | sftp -P $SFTP_PORT -i "$KEY_PATH" \
                        -o StrictHostKeyChecking=no $SFTP_USER@$SFTP_HOST 2>/dev/null
                    echo "✅ 测试完成"
                else
                    echo "❌ SFTP文件上传失败"
                fi
            else
                echo "❌ SSH连接失败"
                echo "请检查:"
                echo "  1. 私钥文件权限是否为600: chmod 600 $KEY_PATH"
                echo "  2. 公钥是否已添加到服务器 ~/.ssh/authorized_keys"
                echo "  3. 服务器防火墙是否开放端口 $SFTP_PORT"
            fi
        fi
        ;;

    *)
        echo "❌ 无效选项"
        exit 1
        ;;
esac

# 清理本地测试文件
rm -f $TEST_FILE

echo ""
echo "========================================="
echo "测试结束"
echo "========================================="
