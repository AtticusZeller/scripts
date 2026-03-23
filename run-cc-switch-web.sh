#!/bin/bash

# 配置信息
REPO="cp-yu/cc-switch-web"
BINARY_NAME="cc-switch-web-bin"
LIB_DIR="$(pwd)/libs"

echo "------------------------------------------------"
echo "🔍 检查运行环境 (无 jq 依赖版)..."

# 1. 下载二进制文件（如果不存在）
if [ ! -f "$BINARY_NAME" ]; then
    # 使用 grep 和 sed 提取下载链接，不再需要 jq
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)
    DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep "browser_download_url" | grep "linux-x86_64" | head -n 1 | cut -d '"' -f 4)
    
    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" == "null" ]; then
        echo "❌ 错误：未能解析到下载地址，请检查网络。"
        exit 1
    fi
    echo "📥 正在下载最新版本..."
    curl -L -o "$BINARY_NAME" "$DOWNLOAD_URL"
    chmod +x "$BINARY_NAME"
fi

# 2. 补全 libssl1.1 兼容库
if ldd ./$BINARY_NAME | grep -q "not found" || [ ! -f "$LIB_DIR/libssl.so.1.1" ]; then
    echo "ℹ️  正在准备 libssl1.1 兼容性库..."
    mkdir -p "$LIB_DIR"
    
    SSL_DEB="libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb"
    SSL_URL="http://security.ubuntu.com/ubuntu/pool/main/o/openssl/$SSL_DEB"
    
    if [ ! -f "$LIB_DIR/libssl.so.1.1" ]; then
        curl -L -o "/tmp/$SSL_DEB" "$SSL_URL"
        cd "$LIB_DIR"
        ar x "/tmp/$SSL_DEB"
        tar -xf data.tar.xz ./usr/lib/x86_64-linux-gnu/libssl.so.1.1 ./usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
        mv usr/lib/x86_64-linux-gnu/*.so.1.1 .
        rm -rf usr control.tar.xz data.tar.xz debian-binary
        cd ..
    fi
    echo "✅ 兼容库准备就绪。"
fi

# 核心：每次运行都必须加载路径
export LD_LIBRARY_PATH="$LIB_DIR:$LD_LIBRARY_PATH"

# 3. 启动说明
echo "------------------------------------------------"
echo "🚀 正在启动 cc-switch-web..."
echo "📍 默认访问地址: http://127.0.0.1:17666"
echo "💡 提示: 停止运行请按 Ctrl+C"
echo "------------------------------------------------"

# 4. 运行
./$BINARY_NAME
