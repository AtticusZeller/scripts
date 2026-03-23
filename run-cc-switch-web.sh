#!/bin/bash

# 配置信息
REPO="cp-yu/cc-switch-web"
BINARY_NAME="cc-switch-web-bin"
LIB_DIR="$(pwd)/libs"

echo "------------------------------------------------"
echo "🔍 检查运行环境..."

# 1. 下载二进制文件（如果不存在）
if [ ! -f "$BINARY_NAME" ]; then
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)
    DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name | contains("linux-x86_64")) | .browser_download_url')
    
    if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" == "null" ]; then
        echo "❌ 错误：未找到适用于 Linux x86_64 的二进制文件。"
        exit 1
    fi
    echo "📥 正在下载最新版本..."
    curl -L -o "$BINARY_NAME" "$DOWNLOAD_URL"
    chmod +x "$BINARY_NAME"
fi

# 2. 强制检测 libssl1.1 缺失或准备兼容库
# 只要检测到 ldd 输出中包含 "not found"，或者本地已经下载了兼容库，就执行加载逻辑
if ldd ./$BINARY_NAME | grep -q "not found" || [ -d "$LIB_DIR" ]; then
    
    if [ ! -f "$LIB_DIR/libssl.so.1.1" ]; then
        echo "ℹ️  检测到系统缺失 libssl1.1，正在下载兼容性库..."
        mkdir -p "$LIB_DIR"
        
        # 下载 libssl1.1 (Ubuntu 20.04 版本)
        SSL_DEB="libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb"
        SSL_URL="http://security.ubuntu.com/ubuntu/pool/main/o/openssl/$SSL_DEB"
        
        echo "📥 下载 libssl1.1 兼容包..."
        curl -L -o "/tmp/$SSL_DEB" "$SSL_URL"
        
        # 解压获取 .so 文件
        cd "$LIB_DIR"
        ar x "/tmp/$SSL_DEB"
        tar -xf data.tar.xz ./usr/lib/x86_64-linux-gnu/libssl.so.1.1 ./usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
        mv usr/lib/x86_64-linux-gnu/*.so.1.1 .
        rm -rf usr control.tar.xz data.tar.xz debian-binary
        cd ..
    fi
    
    # 核心修复：确保每次运行都导出这个路径
    export LD_LIBRARY_PATH="$LIB_DIR:$LD_LIBRARY_PATH"
    echo "✅ 已加载本地兼容库路径。"
fi

# 3. 启动说明
echo "------------------------------------------------"
echo "🚀 正在启动 cc-switch-web..."
echo "📍 默认访问地址: http://127.0.0.1:17666"
echo "💡 提示: 停止运行请按 Ctrl+C"
echo "------------------------------------------------"

# 4. 运行
./$BINARY_NAME
