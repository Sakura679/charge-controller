#!/system/bin/sh
# service.sh – Magisk/KernelSU 晚期启动入口
MODDIR=${0%/*}
PIDFILE="$MODDIR/charger.pid"
DAEMON="$MODDIR/charger-daemon.sh"

# 读取配置（确保守护进程能拿到同样的变量）
CONF="$MODDIR/config/default.conf"
[ -f "$CONF" ] && . "$CONF"
LOW_THRESHOLD=${LOW_THRESHOLD:-30}
HIGH_THRESHOLD=${HIGH_THRESHOLD:-80}
POLL_INTERVAL=${POLL_INTERVAL:-300}
ENABLE_LOG=${ENABLE_LOG:-false}

log_msg() {
    local msg="$1"
    echo "[ChargeControl-service] $msg"
    [ "$ENABLE_LOG" = true ] && echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" >> "$MODDIR/log.txt"
}

log_msg "=== Charge Control service.sh 启动 ==="

# 检测是否被 post-fs-data 标记为禁用
if [ -f "$MODDIR/.charge_control_disabled" ]; then
    log_msg "检测到内核不支持充电控制，服务不会启动。"
    log_msg "请刷入支持充电阈值控制的内核（如 GKI 主线内核）后重试。"
    exit 0
fi

# 确认启用标志存在（防止意外情况）
if [ ! -f "$MODDIR/.charge_control_enabled" ]; then
    log_msg "警告：未找到启用标志，可能 post-fs-data 未成功运行。"
    # 仍然尝试继续，但会在守护进程里再次检测接口
fi

# 如果已有旧的守护进程，先杀掉（防止重复刷入导致多实例）
if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    log_msg "发现旧的守护进程 PID=$(cat "$PIDFILE")，先行终止。"
    kill "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
fi

# 启动守护进程（后台、脱离终端）
log_msg "启动充电控制守护进程…"
if [ "$ENABLE_LOG" = true ]; then
    setsid sh "$DAEMON" \
        >>"$MODDIR/log.txt" 2>&1 &
else
    setsid sh "$DAEMON" >/dev/null 2>&1 &
fi
echo $! > "$PIDFILE"
log_msg "守护进程已启动，PID=$(cat "$PIDFILE")"
log_msg "=== service.sh 结束 ==="
