# Perform the login attempt and capture the response
$RESPONSE = Invoke-WebRequest -Uri "http://172.18.254.6:801/eportal/?c=Portal&a=login&callback=dr1004&login_method=1&user_account=240321514%40dianxin&user_password=273515&wlan_user_ip=172.18.50.92&wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=&jsVersion=3.3.3&v=4582" -UseBasicParsing

Write-Host "Login attempt response:"
Write-Host $RESPONSE.Content
