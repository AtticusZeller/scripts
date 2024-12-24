#!/bin/bash

# 配置参数
PING_COUNT=10     # 每个 IP 测试次数
PING_TIMEOUT=1    # 每次 ping 超时时间(秒)
PING_INTERVAL=0.5 # ping 间隔时间(秒)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试结果数组
declare -A results

# 函数：测试单个 IP
test_ip() {
    local ip=$1
    local total=0
    local success=0
    local min=999999
    local max=0
    local sum=0

    echo -e "${YELLOW}Testing $ip...${NC}"

    for ((i = 1; i <= $PING_COUNT; i++)); do
        # 执行 ping 测试
        result=$(ping -c 1 -W $PING_TIMEOUT $ip | grep "time=" | cut -d "=" -f 4 | cut -d " " -f 1)

        if [ ! -z "$result" ]; then
            # ping 成功
            success=$((success + 1))
            sum=$(echo "$sum + $result" | bc)

            # 更新最小值
            if (($(echo "$result < $min" | bc -l))); then
                min=$result
            fi

            # 更新最大值
            if (($(echo "$result > $max" | bc -l))); then
                max=$result
            fi

            echo -ne "\rProgress: $i/$PING_COUNT - Success: $success"
        else
            # ping 失败
            echo -ne "\rProgress: $i/$PING_COUNT - Failed: $((i - success))"
        fi

        sleep $PING_INTERVAL
    done
    echo

    # 计算平均值
    if [ $success -gt 0 ]; then
        avg=$(echo "scale=2; $sum / $success" | bc)
        loss_rate=$(echo "scale=2; ($PING_COUNT - $success) * 100 / $PING_COUNT" | bc)

        # 存储结果
        results[$ip]="min=$min max=$max avg=$avg success=$success loss=$loss_rate%"
    else
        results[$ip]="All packets lost"
    fi
}

# 主程序
echo -e "${GREEN}Ping Latency Test Tool${NC}"
echo "Enter IP addresses (one per line, empty line to finish):"

# 读取 IP 地址
ips=()
while true; do
    read ip
    [ -z "$ip" ] && break
    ips+=("$ip")
done

# 测试所有 IP
for ip in "${ips[@]}"; do
    test_ip "$ip"
done

# 显示结果
echo -e "\n${GREEN}Test Results:${NC}"
printf "%-20s %-15s %-15s %-15s %-15s %-15s\n" "IP" "Min(ms)" "Max(ms)" "Avg(ms)" "Success" "Loss Rate"
echo "--------------------------------------------------------------------------------"

for ip in "${ips[@]}"; do
    if [[ "${results[$ip]}" == "All packets lost" ]]; then
        printf "${RED}%-20s %-15s${NC}\n" "$ip" "All packets lost"
    else
        # 解析结果
        min=$(echo "${results[$ip]}" | grep -o "min=[0-9.]*" | cut -d= -f2)
        max=$(echo "${results[$ip]}" | grep -o "max=[0-9.]*" | cut -d= -f2)
        avg=$(echo "${results[$ip]}" | grep -o "avg=[0-9.]*" | cut -d= -f2)
        success=$(echo "${results[$ip]}" | grep -o "success=[0-9]*" | cut -d= -f2)
        loss=$(echo "${results[$ip]}" | grep -o "loss=[0-9.]*%" | cut -d= -f2)

        printf "%-20s %-15.2f %-15.2f %-15.2f %-15d %-15s\n" "$ip" "$min" "$max" "$avg" "$success" "$loss"
    fi
done
