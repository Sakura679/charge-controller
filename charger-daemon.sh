#!/system/bin/sh
# charger-daemon.sh – 实际的充电阈值监控循环
MODDIR=${0%/*}
CONF="$MODDIR/config/default.conf"
[ -f "$CONF" ] && . "$CONF"
LOW_THRESHOLD=${LOW_THRESHOLD:-30}
HIGH_THRESHOLD=${HIGH_THRESHOLD:-80}
POLL_INTERVAL=${POLL_INTERVAL:-300}
ENABLE_LOG=${ENABLE_LOG:-false}

# 信号处理：确保异常终止时退出
cleanup() {
    exit 0
}
trap cleanup TERM INT

# 探测接口（与 post-fs-data 保持一致，防止运行时环境变化）
CHARGING_ENABLED="/sys/class/power_supply/battery/charging_enabled"
CHARGE_START="/sys/class/power_supply/battery/charge_control_start_threshold"
CHARGE_END="/sys/class/power_supply/battery/charge_control_end_threshold"

# 决定控制模式
if [ -w "$CHARGE_START" ] && [ -w "$CHARGE_END" ]; then
    USE_THRESHOLDS=true
elif [ -w "$CHARGING_ENABLED" ]; then
    USE_THRESHOLDS=false
else
    echo "$(date) 错误：运行时未找到可写的充电控制接口，守护进程退出" >>"$MODDIR/log.txt"
    exit 1
fi

log_msg() {
    local msg="$1"
    echo "[ChargeControl-daemon] $msg"
    [ "$ENABLE_LOG" = true ] && echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" >>"$MODDIR/log.txt"
}

log_msg "守护进程启动（模式=${USE_THRESHOLDS:+thresholds：switch}，LOW=$LOW_THRESHOLD% HIGH=$HIGH_THRESHOLD% INTERVAL=$POLL_INTERVAL秒）"

get_battery_capacity() {
    local cap
    cap=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null) || {
        echo "$(date) 错误：无法读取电量，守护进程退出" >>"$MODDIR/log.txt"
        exit 1
    }
    echo "$cap"
}

set_charging() {
    local enable=$1   # 1=开, 0=关
    if $USE_THRESHOLDS; then
        if [ "$enable" -eq 1 ]; then
            echo $LOW_THRESHOLD > "$CHARGE_START"
            echo $HIGH_THRESHOLD > "$CHARGE_END"
        else
            echo 100 > "$CHARGE_START"
            echo 0 > "$CHARGE_END"
        fi
    else
        echo $enable > "$CHARGING_ENABLED"
    fi
}

# 主循环
while true; do
    CAP=$(get_battery_capacity)
    if [ "$CAP" -le "$LOW_THRESHOLD" ]; then
        set_charging 1
        log_msg "电量 $CAP% ≤ $LOW_THRESHOLD% → 开启充电"
    elif [ "$CAP" -ge "$HIGH_THRESHOLD" ]; then
        set_charging 0
        log_msg "电量 $CAP% ≥ $HIGH_THRESHOLD% → 关闭充电"
    fi
    # 其余区间保持现状，不做任何写入，以免频繁触发充电IC
    sleep "$POLL_INTERVAL"
done
