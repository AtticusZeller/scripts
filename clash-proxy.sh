#!/bin/bash

# Define constants
MIHOMO_CONFIG_DIR="$HOME/Proxy"
MIHOMO_CONFIG="$MIHOMO_CONFIG_DIR/config.yaml"
MIHOMO_SERVICE="/etc/systemd/system/mihomo.service"
SUBSCRIPTION_FILE="$MIHOMO_CONFIG_DIR/subscription.txt"
MIHOMO_PATH=$(which mihomo)

# Check if mihomo is installed
check_mihomo() {
    if [ ! -x "$MIHOMO_PATH" ]; then
        echo "Error: mihomo is not installed. Please install mihomo first."
        exit 1
    fi
}

# Ensure root privileges
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "Error: This script must be run as root."
        exit 1
    fi
}

# Create necessary directories and files
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

# Create systemd service
create_service() {
    if [ -f "$MIHOMO_SERVICE" ]; then
        echo "Notice: Service already exists. Skipping creation."
        return
    fi

    cat >"$MIHOMO_SERVICE" <<EOF
[Unit]
Description=mihomo Daemon
After=network.target

[Service]
Type=simple
LimitNPROC=500
LimitNOFILE=1000000
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
Restart=always
ExecStart=$MIHOMO_PATH -d $MIHOMO_CONFIG_DIR
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable mihomo
    echo "✓ Service created successfully."
}

# Add subscription
add_subscription() {
    if [ -z "$1" ]; then
        echo "Error: Please provide a subscription URL."
        return 1
    fi

    # Validate URL format
    if ! echo "$1" | grep -qE '^https?://'; then
        echo "Error: Invalid URL format."
        return 1
    fi

    echo "$1" >"$SUBSCRIPTION_FILE"
    echo "✓ Subscription added successfully."
    update_config
}

# Show current subscription
show_subscription() {
    if [ -s "$SUBSCRIPTION_FILE" ]; then
        echo "Current subscription URL:"
        cat "$SUBSCRIPTION_FILE"
    else
        echo "Notice: No subscription URL found."
    fi
}

# Update configuration
update_config() {
    echo "Updating configuration..."

    if [ -s "$SUBSCRIPTION_FILE" ]; then
        sub_url=$(cat "$SUBSCRIPTION_FILE")
        if curl -s "$sub_url" >"$MIHOMO_CONFIG"; then
            systemctl reload mihomo 2>/dev/null || true
            echo "✓ Configuration updated successfully."
        else
            echo "Error: Configuration update failed. Please check the subscription URL."
        fi
    else
        echo "Error: No valid subscription URL found."
    fi
}

# Disable autostart
disable_autostart() {
    if systemctl is-enabled mihomo >/dev/null 2>&1; then
        systemctl disable mihomo
        echo "✓ Autostart disabled."
    else
        echo "Notice: Autostart is already disabled."
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
check_mihomo
init_directories

case "$1" in
"start")
    create_service
    systemctl start mihomo
    echo "✓ Service started."
    echo "➜ Dashboard URL: https://metacubexd.pages.dev/"
    echo "➜ Default port: 9097"
    ;;
"stop")
    systemctl stop mihomo
    echo "✓ Service stopped."
    ;;
"restart")
    systemctl restart mihomo
    echo "✓ Service restarted."
    echo "➜ Dashboard URL: https://metacubexd.pages.dev/"
    echo "➜ Default port: 9097"
    ;;
"status")
    if systemctl is-active mihomo >/dev/null 2>&1; then
        echo "✓ Service status: Running"
        systemctl status mihomo
    else
        echo "✗ Service status: Not running"
    fi
    ;;
"logs")
    journalctl -u mihomo -o cat -f
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
    echo "Error: Unknown command: $1"
    show_help
    exit 1
    ;;
esac

exit 0
