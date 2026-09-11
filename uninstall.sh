#!/system/bin/sh
# uninstall.sh – 卸载时恢复默认充电行为
MODDIR=${0%/*}
PIDFILE="$MODDIR/charger.pid"
log_msg() {
    echo "[ChargeControl-uninstall] $1"
}
log_msg "卸载 Charge Control 模块……"

# 1. 停止守护进程
if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    log_msg "停止守护进程 PID=$(cat "$PIDFILE")"
    kill "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
else
    log_msg "未发现运行中的守护进程。"
fi

# 2. 恢复默认充电状态（尽量把控制权交还给系统）
CHARGING_ENABLED="/sys/class/power_supply/battery/charging_enabled"
CHARGE_START="/sys/class/power_supply/battery/charge_control_start_threshold"
CHARGE_END="/sys/class/power_supply/battery/charge_control_end_threshold"

if [ -w "$CHARGE_START" ] && [ -w "$CHARGE_END" ]; then
    # 把阈值还原为全范围，并确保充电开关处于开启状态
    echo 0   > "$CHARGE_START"
    echo 100 > "$CHARGE_END"
    echo 1   > "$CHARGING_ENABLED"
    log_msg "已把充电阈值还原为 0‑100 并开启充电开关。"
elif [ -w "$CHARGING_ENABLED" ]; then
    echo 1 > "$CHARGING_ENABLED"
    log_msg "已开启充电开关（threshold 接口不可用）。"
else
    log_msg "未找到可写的充电控制接口，无法恢复默认状态。"
fi

# 3. 清理模块留下的标志文件（可选）
rm -f "$MODDIR/.charge_control_enabled" "$MODDIR/.charge_control_disabled"
log_msg "卸载完成。"
