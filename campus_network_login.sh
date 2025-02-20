#!/bin/bash

# Define the SSID to check for
TARGET_SSID="Student_CX"

# Get the current SSID
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | egrep '^yes' | cut -d':' -f2)

# Check if the current SSID matches the target SSID
if [ "$CURRENT_SSID" == "$TARGET_SSID" ]; then
    # Perform the login attempt and capture the response
    RESPONSE=$(curl "http://172.18.254.6:801/eportal/?c=Portal&a=login&callback=dr1004&login_method=1&user_account=240321514%40dianxin&user_password=273515&wlan_user_ip=172.18.50.92&wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=&jsVersion=3.3.3&v=4582")
    echo "Login attempt response:"
    echo "$RESPONSE"
else
    echo "Not connected to $TARGET_SSID. No login attempt made."
fi
