#!/bin/bash

REAL_USER="${SUDO_USER:-$USER}"
REAL_USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
SINGBOX_CONFIG_DIR="$REAL_USER_HOME/proxy/sing-box"
SINGBOX_CONFIG="$SINGBOX_CONFIG_DIR/config.json"
SINGBOX_SERVICE="/etc/systemd/system/sing-box.service"
SUBSCRIPTION_FILE="$SINGBOX_CONFIG_DIR/subscription.txt"
SINGBOX_PATH=$(which sing-box)

# Check if sing-box is installed
check_singbox() {
    if [ ! -x "$SINGBOX_PATH" ]; then
        echo "❌ sing-box not found. Installing..."
        exit 1
    else
        echo "✅ sing-box is found."
    fi
}

# Ensure root privileges
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "⚠️ This script must be run as root."
        exit 1
    fi
}

# Create necessary directories and files
init_directories() {
    if [ ! -d "$SINGBOX_CONFIG_DIR" ]; then
        mkdir -p "$SINGBOX_CONFIG_DIR"
        chown "$REAL_USER":"$REAL_USER" "$SINGBOX_CONFIG_DIR"
        echo "📁 Created configuration directory: $INSTALL_DIR"
    fi

    if [ ! -f "$SUBSCRIPTION_FILE" ]; then
        touch "$SUBSCRIPTION_FILE"
        chown "$REAL_USER":"$REAL_USER" "$SUBSCRIPTION_FILE"
        echo "📁 Created subscription file: $SUBSCRIPTION_FILE"
    fi
}

# Create systemd service
create_service() {
    cat >"$SINGBOX_SERVICE" <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
Type=simple
LimitNPROC=500
LimitNOFILE=1000000
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE
Restart=always
ExecStartPre=$SINGBOX_PATH tools synctime -w -C $SINGBOX_CONFIG_DIR
ExecStart=$SINGBOX_PATH run -C $SINGBOX_CONFIG_DIR
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable sing-box
    echo "⌛ Service created successfully."
}

ensure_service() {
    if ! systemctl list-unit-files | grep -q "^sing-box.service"; then
        create_service
    fi
}

# Add subscription
add_subscription() {
    if [ -z "$1" ]; then
        echo "❌ Please provide a subscription URL."
        return 1
    fi

    if ! echo "$1" | grep -qE '^https?://'; then
        echo "❌ Invalid URL format."
        return 1
    fi

    echo "$1" > "$SUBSCRIPTION_FILE"
    echo "📁 Subscription added successfully."
    update_config
}

# Show current subscription
show_subscription() {
    if [ -s "$SUBSCRIPTION_FILE" ]; then
        echo "🔗 Current subscription URL:"
        cat "$SUBSCRIPTION_FILE"
    else
        echo "❌ No subscription URL found."
    fi
}

# Update configuration
update_config() {
    if [ -s "$SUBSCRIPTION_FILE" ]; then
        local url
        url=$(cat "$SUBSCRIPTION_FILE")
        echo "⌛ Update Configuration from $url"
        if curl -s "$url" >"$SINGBOX_CONFIG"; then
            chown "$REAL_USER":"$REAL_USER" "$SINGBOX_CONFIG"
            echo "✅ Configuration updated successfully."
            restart_service
        else
            echo "❌ Configuration update failed. Please check the subscription URL."
        fi
    else
        echo "❌ No valid subscription URL found."
    fi
}

restart_service() {
    ensure_service
    stop_service
    systemctl restart sing-box
    echo "✅ Service restarted."
    echo "🔗 Dashboard URL: https://metacubexd.pages.dev/"
    echo "🔌 Default API: http://127.0.0.1:9090"
}

stop_service() {
    systemctl stop sing-box
    echo "✋ Service stopped."
}

disable_autostart() {
    stop_service
    systemctl disable sing-box
    echo "✋ Autostart disabled."
}

start_service() {
    ensure_service
    systemctl start sing-box
    echo "✅ Service started."
    echo "🔗 Dashboard URL: https://metacubexd.pages.dev/"
    echo "🔌 Default API: http://127.0.0.1:9090"
}

get_status() {
    if systemctl is-active sing-box >/dev/null 2>&1; then
        echo "🏃 Service status: Running"
        systemctl status sing-box
    else
        echo "⚠️ Service status: Not running"
    fi
}

# Display help information
show_help() {
    echo "Usage: $0 [command] [arguments]"
    echo "Commands:"
    echo "  start           Start the service and enable autostart"
    echo "  stop            Stop the service"
    echo "  restart         Restart the service"
    echo "  status          Check service status"
    echo "  logs            Show service logs"
    echo "  disable         Disable autostart"
    echo "  add-sub [URL]   Add a subscription URL"
    echo "  show-sub        Display the current subscription URL"
    echo "  update          Update the configuration"
    echo "  help            Display this help information"
}

# Main program
check_root
check_singbox
init_directories

case "$1" in
"start")
    create_service
    start_service
    ;;
"stop")
    stop_service
    ;;
"restart")
    restart_service
    ;;
"status")
    get_status
    ;;
"logs")
    journalctl -u sing-box -o cat -f
    ;;
"disable")
    disable_autostart
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
"help" | "")
    show_help
    ;;
*)
    echo "❌ Unknown command: $1"
    show_help
    exit 1
    ;;
esac

exit 0
