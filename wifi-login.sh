#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 /path/to/wifi-login.sh"
    exit 1
fi

WIFI_SCRIPT_PATH=$(readlink -f "$1")

if [ ! -f "$WIFI_SCRIPT_PATH" ]; then
    echo "Error: Script file $WIFI_SCRIPT_PATH does not exist!"
    exit 1
fi

echo "Using script path: $WIFI_SCRIPT_PATH"

sudo tee /etc/systemd/system/wifi-login.service << EOF
[Unit]
Description=WiFi Login Service
Documentation=https://github.com/atticuszz
After=network-online.target
Before=sing-box.service

[Service]
Type=oneshot
ExecStart=/bin/bash $WIFI_SCRIPT_PATH
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo chmod +x "$WIFI_SCRIPT_PATH" && \
sudo systemctl daemon-reload && \
sudo systemctl enable wifi-login.service && \
sudo systemctl start wifi-login.service && \
echo "Services configured and started successfully!" && \
echo "Checking services status:" && \
sudo systemctl status wifi-login.service