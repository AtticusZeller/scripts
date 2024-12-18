#!/data/data/com.termux/files/usr/bin/bash

# 定义路径和版本
MIHOMO_VERSION="v1.19.0"
MIHOMO_CONFIG_DIR="$HOME/proxy"
MIHOMO_CONFIG="$MIHOMO_CONFIG_DIR/config.yaml"
SUBSCRIPTION_FILE="$MIHOMO_CONFIG_DIR/subscription.txt"
MIHOMO_PATH="$PREFIX/bin/mihomo"
PID_FILE="$MIHOMO_CONFIG_DIR/mihomo.pid"
DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/$MIHOMO_VERSION/mihomo-android-arm64-v8-$MIHOMO_VERSION.gz"

# 检查并安装必要的工具
check_dependencies() {
    if ! command -v curl >/dev/null; then
        echo "Installing curl..."
        pkg install curl -y
    fi
}

# 下载并安装 mihomo
install_mihomo() {
    echo "Downloading mihomo..."
    if curl -L "$DOWNLOAD_URL" -o "/tmp/mihomo.gz"; then
        echo "Extracting mihomo..."
        gunzip -f "/tmp/mihomo.gz"
        mv "/tmp/mihomo" "$MIHOMO_PATH"
        chmod +x "$MIHOMO_PATH"
        echo "✓ mihomo installed successfully."
    else
        echo "Error: Failed to download mihomo."
        exit 1
    fi
}

# 检查更新
check_update() {
    echo "Checking for updates..."
    local latest_version=$(curl -s "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -n "$latest_version" ] && [ "$latest_version" != "$MIHOMO_VERSION" ]; then
        echo "New version available: $latest_version"
        echo "Current version: $MIHOMO_VERSION"
        read -p "Do you want to update? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            MIHOMO_VERSION=$latest_version
            DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/$MIHOMO_VERSION/mihomo-android-arm64-v8-$MIHOMO_VERSION.gz"
            stop_service
            install_mihomo
            start_service
        fi
    else
        echo "You are using the latest version."
    fi
}

# 检查 mihomo 是否安装
check_mihomo() {
    if [ ! -x "$MIHOMO_PATH" ]; then
        echo "mihomo not found. Installing..."
        install_mihomo
    fi
}

# 创建必要的目录和文件
init_directories() {
    if [ ! -d "$MIHOMO_CONFIG_DIR" ]; then
        mkdir -p "$MIHOMO_CONFIG_DIR"
        echo "✓ Created configuration directory: $MIHOMO_CONFIG_DIR"
    fi

    if [ ! -f "$SUBSCRIPTION_FILE" ]; then
        touch "$SUBSCRIPTION_FILE"
        echo "✓ Created subscription file: $SUBSCRIPTION_FILE"
    fi
}

# 启动服务
start_service() {
    if [ -f "$PID_FILE" ]; then
        if kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            echo "mihomo is already running."
            return
        fi
    fi
    
    nohup "$MIHOMO_PATH" -d "$MIHOMO_CONFIG_DIR" > "$MIHOMO_CONFIG_DIR/mihomo.log" 2>&1 &
    echo $! > "$PID_FILE"
    echo "✓ Service started."
    echo "➜ Dashboard URL: https://metacubexd.pages.dev/"
    echo "➜ Default port: 9097"
}

# 停止服务
stop_service() {
    if [ -f "$PID_FILE" ]; then
        if kill -15 $(cat "$PID_FILE") 2>/dev/null; then
            rm "$PID_FILE"
            echo "✓ Service stopped."
        else
            echo "Service not running."
        fi
    else
        echo "Service not running."
    fi
}

# 添加订阅
add_subscription() {
    if [ -z "$1" ]; then
        echo "Error: Please provide a subscription URL."
        return 1
    fi

    if ! echo "$1" | grep -qE '^https?://'; then
        echo "Error: Invalid URL format."
        return 1
    fi

    echo "$1" > "$SUBSCRIPTION_FILE"
    echo "✓ Subscription added successfully."
    update_config
}

# 显示当前订阅
show_subscription() {
    if [ -s "$SUBSCRIPTION_FILE" ]; then
        echo "Current subscription URL:"
        cat "$SUBSCRIPTION_FILE"
    else
        echo "Notice: No subscription URL found."
    fi
}

# 更新配置
update_config() {
    echo "Updating configuration..."

    if [ -s "$SUBSCRIPTION_FILE" ]; then
        sub_url=$(cat "$SUBSCRIPTION_FILE")
        if curl -s "$sub_url" > "$MIHOMO_CONFIG"; then
            if [ -f "$PID_FILE" ]; then
                if kill -1 $(cat "$PID_FILE") 2>/dev/null; then
                    echo "✓ Configuration updated and reloaded."
                else
                    echo "✓ Configuration updated but service not running."
                fi
            else
                echo "✓ Configuration updated."
            fi
        else
            echo "Error: Configuration update failed. Please check the subscription URL."
        fi
    else
        echo "Error: No valid subscription URL found."
    fi
}

# 显示日志
show_logs() {
    if [ -f "$MIHOMO_CONFIG_DIR/mihomo.log" ]; then
        tail -f "$MIHOMO_CONFIG_DIR/mihomo.log"
    else
        echo "No logs found."
    fi
}

# 显示帮助信息
show_help() {
    echo "Usage: $0 [command] [arguments]"
    echo "Commands:"
    echo "  start           Start the service"
    echo "  stop            Stop the service"
    echo "  restart         Restart the service"
    echo "  status          Check service status"
    echo "  logs            Show service logs"
    echo "  add-sub [URL]   Add a subscription URL"
    echo "  show-sub        Display the current subscription URL"
    echo "  update          Update the configuration"
    echo "  check-update    Check for mihomo updates"
    echo "  help            Display this help information"
}

# 主程序
check_dependencies
init_directories

case "$1" in
    "start")
        check_mihomo
        start_service
        ;;
    "stop")
        stop_service
        ;;
    "restart")
        stop_service
        sleep 1
        check_mihomo
        start_service
        ;;
    "status")
        if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            echo "✓ Service status: Running"
        else
            echo "✗ Service status: Not running"
        fi
        ;;
    "logs")
        show_logs
        ;;
    "add-sub")
        add_subscription "$2"
        ;;
    "show-sub")
        show_subscription
        ;;
    "update")
        update_config
        ;;
    "check-update")
        check_update
        ;;
    "help"|"")
        show_help
        ;;
    *)
        echo "Error: Unknown command: $1"
        show_help
        exit 1
        ;;
esac

exit 0
