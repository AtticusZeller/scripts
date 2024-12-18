#!/data/data/com.termux/files/usr/bin/bash

# 定义路径和版本
MIHOMO_CONFIG_DIR="$HOME/proxy"
MIHOMO_CONFIG="$MIHOMO_CONFIG_DIR/config.yaml"
SUBSCRIPTION_FILE="$MIHOMO_CONFIG_DIR/subscription.txt"
MIHOMO_PATH="$PREFIX/bin/mihomo"
PID_FILE="$MIHOMO_CONFIG_DIR/mihomo.pid"

# 检查并安装必要的工具
check_dependencies() {
    if ! command -v curl >/dev/null; then
        echo "Installing curl..."
        pkg install curl -y
    fi
}

# 获取当前安装的 mihomo 版本
get_current_version() {
    if [ -x "$MIHOMO_PATH" ]; then
        local version=$("$MIHOMO_PATH" -v | grep -o 'v[0-9.]*' | head -n 1)
        echo "$version"
    else
        echo "not_installed"
    fi
}

# 从 GitHub 获取最新版本
get_latest_version() {
    local latest_version=$(curl -s "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" | jq -r .tag_name)
    echo "$latest_version"
}

# 下载并安装指定版本的 mihomo
# 下载并安装指定版本的 mihomo
install_mihomo() {
    local version=$1
    local download_url="https://github.com/MetaCubeX/mihomo/releases/download/${version}/mihomo-android-arm64-v8-${version}.gz"
    local temp_dir="$MIHOMO_CONFIG_DIR/temp"
    
    # 创建临时目录
    mkdir -p "$temp_dir"

    echo "Downloading mihomo ${version}..."
    if curl -L "$download_url" -o "$temp_dir/mihomo.gz"; then
        echo "Extracting mihomo..."
        # 确保目标目录存在
        mkdir -p "$(dirname "$MIHOMO_PATH")"
        
        # 解压缩到临时目录
        gunzip -f "$temp_dir/mihomo.gz"
        
        # 移动到最终位置
        mv "$temp_dir/mihomo" "$MIHOMO_PATH"
        chmod +x "$MIHOMO_PATH"
        
        # 清理临时文件
        rm -rf "$temp_dir"
        
        echo "✓ mihomo ${version} installed successfully."
        return 0
    else
        echo "Error: Failed to download mihomo."
        # 清理临时文件
        rm -rf "$temp_dir"
        return 1
    fi
}


# 检查更新
check_update() {
    echo "Checking for updates..."
    
    local current_version=$(get_current_version)
    local latest_version=$(get_latest_version)
    
    if [ "$current_version" = "not_installed" ]; then
        echo "mihomo is not installed. Installing latest version..."
        install_mihomo "$latest_version"
        return
    fi
    
    if [ -n "$latest_version" ] && [ "$current_version" != "$latest_version" ]; then
        echo "New version available: $latest_version"
        echo "Current version: $current_version"
        read -p "Do you want to update? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            stop_service
            if install_mihomo "$latest_version"; then
                start_service
                echo "✓ Update completed successfully."
            else
                echo "! Update failed, reverting to previous version..."
                install_mihomo "$current_version"
                start_service
            fi
        fi
    else
        echo "You are using the latest version ($current_version)."
    fi
}

check_mihomo() {
    if [ ! -x "$MIHOMO_PATH" ]; then
        echo "mihomo not found. Installing..."
        local latest_version=$(get_latest_version)
        install_mihomo "$latest_version"
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

    echo "Starting mihomo in VPN mode..."
    echo "! Important: When Android system prompts, please:"
    echo "1. Allow VPN connection"
    echo "2. Trust this application"
    echo "3. Accept the VPN configuration"
    echo ""
    
    # 使用 VPN 模式启动
    nohup "$MIHOMO_PATH" -d "$MIHOMO_CONFIG_DIR" > "$MIHOMO_CONFIG_DIR/mihomo.log" 2>&1 &
    local PID=$!
    echo $PID > "$PID_FILE"
    
    # 等待几秒检查服务是否正常启动
    sleep 3
    if kill -0 $PID 2>/dev/null; then
        echo "✓ Service started."
        echo "➜ Dashboard URL: https://metacubexd.pages.dev/"
        echo "➜ Default port: 9097"
        echo "➜ Checking logs for VPN status..."
        
        # 显示最近的日志
        tail -n 5 "$MIHOMO_CONFIG_DIR/mihomo.log"
        
        echo ""
        echo "! If no VPN prompt appears, please:"
        echo "1. Check if mihomo is compiled with VPN support"
        echo "2. Check the logs using: ./mihomo-android.sh logs"
        echo "3. Make sure your config.yaml has correct tun settings"
    else
        echo "! Service failed to start. Checking logs:"
        tail -n 10 "$MIHOMO_CONFIG_DIR/mihomo.log"
        rm -f "$PID_FILE"
        return 1
    fi
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
        if grep -q "tun:" "$MIHOMO_CONFIG"; then
            if ! check_vpn_permission; then
                echo "Starting in VPNService mode..."
                echo "Please accept the VPN configuration prompt."
            fi
        fi
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
