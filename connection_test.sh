#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 默认测试次数
TEST_COUNT=1

# 解析命令行参数
while getopts "t:" opt; do
    case $opt in
        t) TEST_COUNT="$OPTARG";;
        *) echo "Usage: $0 [-t test_count]"; exit 1;;
    esac
done

# 存储结果的数组
declare -A results
declare -A min_times
declare -A max_times
declare -A avg_times

format_time() {
    local time=$1
    if [[ $time == "Failed" || $time == "-" ]]; then
        echo "$time"
    else
        printf "%.3f ms" $(echo "$time * 1000" | bc)
    fi
}

show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

test_https_handshake() {
    local host=$1
    local service=$2
    local iteration=$3
    local total_tests=$4
    
    echo -ne "\rTesting $service ($iteration/$total_tests)..."
    
    result=$(timeout 5 curl -sI -w "Connect: %{time_connect}\nSSL: %{time_appconnect}\nTotal: %{time_total}\n" https://$host -o /dev/null)
    status=$?
    
    if [ $status -eq 0 ]; then
        connect_time=$(echo "$result" | grep "Connect:" | awk '{print $2}')
        ssl_time=$(echo "$result" | grep "SSL:" | awk '{print $2}')
        total_time=$(echo "$result" | grep "Total:" | awk '{print $2}')
        
        # 更新最小值
        if [ -z "${min_times[$service]}" ] || [ $(echo "$total_time < ${min_times[$service]}" | bc) -eq 1 ]; then
            min_times[$service]=$total_time
        fi
        
        # 更新最大值
        if [ -z "${max_times[$service]}" ] || [ $(echo "$total_time > ${max_times[$service]}" | bc) -eq 1 ]; then
            max_times[$service]=$total_time
        fi
        
        # 累加总时间用于计算平均值
        avg_times[$service]=$(echo "${avg_times[$service]:-0} + $total_time" | bc)
        
        results["$service"]="OK|$connect_time|$ssl_time|$total_time"
    else
        results["$service"]="FAIL|Failed|Failed|Failed"
    fi
}

# 服务列表
services=(
    # "www.google.com:Google"
    # "open.spotify.com:Spotify"
    # "www.reddit.com:Reddit"
    # "github.com:GitHub"
    # "microsoft.com:Microsoft"
    "www.youtube.com:YouTube"
    # "netflix.com:Netflix"
    # "twitter.com:Twitter"
    # "facebook.com:Facebook"
)

echo "Starting tests (${TEST_COUNT} iterations per service)..."

# 运行测试
for ((i=1; i<=$TEST_COUNT; i++)); do
    for service in "${services[@]}"; do
        host="${service%%:*}"
        name="${service#*:}"
        test_https_handshake "$host" "$name" "$i" "$TEST_COUNT"
    done
done

# 计算平均值
for service in "${!avg_times[@]}"; do
    avg_times[$service]=$(echo "scale=6; ${avg_times[$service]} / $TEST_COUNT" | bc)
done

# 打印表格头部
printf "\n\n%-20s %-15s %-15s %-15s %-15s %-15s %-15s\n" \
    "Service" "Status" "Connect Time" "SSL Time" "Total Time" "Min Time" "Max Time"
printf "%.0s=" {1..110}
printf "\n"

# 按照服务名称排序并打印结果
for service in $(echo "${!results[@]}" | tr ' ' '\n' | sort); do
    IFS='|' read -r status connect ssl total <<< "${results[$service]}"
    if [ "$status" = "OK" ]; then
        status_colored="${GREEN}✓${NC}"
    else
        status_colored="${RED}✗${NC}"
    fi
    
    # 格式化时间并添加单位
    connect_formatted=$(format_time "$connect")
    ssl_formatted=$(format_time "$ssl")
    total_formatted=$(format_time "$total")
    min_formatted=$(format_time "${min_times[$service]}")
    max_formatted=$(format_time "${max_times[$service]}")

    printf "%-20s %-15b %-15s %-15s %-15s %-15s %-15s\n" \
        "$service" \
        "$status_colored                " \
        "$connect_formatted" \
        "$ssl_formatted" \
        "$total_formatted" \
        "$min_formatted" \
        "$max_formatted"
done

printf "%.0s=" {1..110}
printf "\n"
echo "Test completed"
