#!/system/bin/sh
# post-fs-data.sh – Magisk/KernelSU 通用入口
MODDIR=${0%/*}                 # 模块根目录，例如 /data/adb/modules/charge-control-module
CONF="$MODDIR/config/default.conf"

# ------ 载入配置（若文件不存在则使用默认值）------
[ -f "$CONF" ] && . "$CONF"
LOW_THRESHOLD=${LOW_THRESHOLD:-20}
HIGH_THRESHOLD=${HIGH_THRESHOLD:-80}
POLL_INTERVAL=${POLL_INTERVAL:-300}   # 默认 5 分钟（300秒）
ENABLE_LOG=${ENABLE_LOG:-false}

# 辅助函数：把信息既打印到控制台（供管理器显示）又写入模块内部日志
log_msg() {
    local msg="$1"
    echo "[ChargeControl] $msg"
    [ "$ENABLE_LOG" = true ] && echo "$(date '+%Y-%m-%d %H:%M:%S') $msg" >> "$MODDIR/log.txt"
}

log_msg "=== Charge Control 模块启动（post-fs-data） ==="
log_msg "读取配置：LOW=$LOW_THRESHOLD%  HIGH=$HIGH_THRESHOLD%  INTERVAL=$POLL_INTERVAL秒  LOG=$ENABLE_LOG"

# ------ 内核兼容性检测 ------
# 探测可能的充电控制文件（按优先级）
CHARGING_ENABLED="/sys/class/power_supply/battery/charging_enabled"
CHARGE_START="/sys/class/power_supply/battery/charge_control_start_threshold"
CHARGE_END="/sys/class/power_supply/battery/charge_control_end_threshold"

# 判断是否可写
if [ -w "$CHARGE_START" ] && [ -w "$CHARGE_END" ]; then
    CTL_MODE="threshold"
    log_msg "检测到可写的充电阈值接口：$CHARGE_START 、 $CHARGE_END"
elif [ -w "$CHARGING_ENABLED" ]; then
    CTL_MODE="switch"
    log_msg "仅检测到可写的充电开关接口：$CHARGING_ENABLED（将使用开/关方式）"
else
    log_msg "错误：未找到任何可写的充电控制接口！"
    log_msg "请确认内核已开放以下任意文件的写权限："
    log_msg "  $CHARGING_ENABLED"
    log_msg "  $CHARGE_START"
    log_msg "  $CHARGE_END"
    # 创建禁用标志，供 service.sh 检测
    touch "$MODDIR/.charge_control_disabled"
    exit 1   # 非零退出会让管理器把模块标记为安装失败
fi

# 支持的情况下创建启用标志
touch "$MODDIR/.charge_control_enabled"
log_msg "内核兼容性检测通过，控制模式：$CTL_MODE"
log_msg "=== post-fs-data 结束 ==="
