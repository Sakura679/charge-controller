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
MMI_CHARGING_ENABLE="/sys/class/power_supply/battery/mmi_charging_enable"

# 决定控制模式
if [ -w "$CHARGE_START" ] && [ -w "$CHARGE_END" ]; then
    USE_THRESHOLDS=true
    SWITCH_NODE=""   # not used
elif [ -w "$CHARGING_ENABLED" ]; then
    USE_THRESHOLDS=false
    SWITCH_NODE="$CHARGING_ENABLED"
elif [ -w "$MMI_CHARGING_ENABLE" ]; then
    USE_THRESHOLDS=false
    SWITCH_NODE="$MMI_CHARGING_ENABLE"
else
    log_msg "错误：运行时未找到可写的充电控制接口，守护进程退出"
    exit 1
fi

log_msg() {
    local msg="$1"
    echo "[ChargeControl-daemon] $msg"
    [ "$ENABLE_LOG" = true ] && echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" >>"$MODDIR/log.txt"
}

# 确定模式描述
if $USE_THRESHOLDS; then
    MODE_DESC="thresholds"
else
    MODE_DESC="switch"
fi

log_msg "守护进程启动（模式=${MODE_DESC}，LOW=$LOW_THRESHOLD% HIGH=$HIGH_THRESHOLD% INTERVAL=$POLL_INTERVAL秒）"

# 日志轮转间隔（每隔多少次循环轮转一次，目标是每小时）
LOG_ROTATION_INTERVAL=$(( 3600 / POLL_INTERVAL ))
if [ $LOG_ROTATION_INTERVAL -lt 1 ]; then
    LOG_ROTATION_INTERVAL=1
fi
loop_count=0

# 日志轮转函数
rotate_logs() {
    if [ "$ENABLE_LOG" = true ] && [ -f "$MODDIR/log.txt" ]; then
        # 检查日志文件大小是否超过 1MB
        if [ $(wc -c < "$MODDIR/log.txt") -gt 1048576 ]; then
            # 保留最近100行
            tail -n 100 "$MODDIR/log.txt" > "$MODDIR/log.txt.tmp" && mv "$MODDIR/log.txt.tmp" "$MODDIR/log.txt"
            log_msg "日志已轮转（保留最近100行）"
        fi
    fi
}

get_battery_capacity() {
    local cap
    cap=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null) || {
        log_msg "错误：无法读取电量，守护进程退出"
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
        echo $enable > "$SWITCH_NODE"
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

    # 更新循环计数器并检查是否需要轮转日志
    loop_count=$((loop_count + 1))
    if [ $loop_count -ge $LOG_ROTATION_INTERVAL ]; then
        rotate_logs
        loop_count=0
    fi

    sleep "$POLL_INTERVAL"
done
