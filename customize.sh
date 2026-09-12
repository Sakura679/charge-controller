#!/system/bin/sh
# customize.sh – Magisk 模块安装时执行的脚本
# 用于设置权限、创建目录、以及动态更新 module.prop 中的配置值

MODDIR=${0%/*}

# 确保脚本有执行权限
chmod 755 "$MODDIR/charger-daemon.sh"
chmod 755 "$MODDIR/post-fs-data.sh"
chmod 755 "$MODDIR/service.sh"
chmod 755 "$MODDIR/uninstall.sh"
chmod 755 "$MODDIR/customize.sh"

# 创建必要的目录（如果不存在的话）
mkdir -p "$MODDIR"

# 读取配置文件中的实际值
CONF="$MODDIR/config/default.conf"
if [ -f "$CONF" ]; then
    . "$CONF"
    # 使用配置文件中的值，如果未设置则使用默认值
    LOW_THRESHOLD=${LOW_THRESHOLD:-30}
    HIGH_THRESHOLD=${HIGH_THRESHOLD:-80}
    POLL_INTERVAL=${POLL_INTERVAL:-300}
    ENABLE_LOG=${ENABLE_LOG:-false}
else
    # 如果配置文件不存在，使用默认值
    LOW_THRESHOLD=30
    HIGH_THRESHOLD=80
    POLL_INTERVAL=300
    ENABLE_LOG=false
fi

# 动态更新 module.prop 中的描述，替换占位符为实际值
MODPROP="$MODDIR/module.prop"
if [ -f "$MODPROP" ]; then
    # 使用 sed 替换占位符为实际值
    # 使用不同的分隔符避免与 % 冲突
    sed -i "s|LOW_THRESHOLD%|$LOW_THRESHOLD|g" "$MODPROP"
    sed -i "s|HIGH_THRESHOLD%|$HIGH_THRESHOLD|g" "$MODPROP"

    # 同时更新描述中的中文文本来反映实际值（可选）
    # 原描述: "充电阈值控制：低于LOW_THRESHOLD% 开始充电，高于HIGH_THRESHOLD% 停止充电，循环。"
    # 更新后: "充电阈值控制：低于20% 开始充电，高于80% 停止充电，循环。"
fi

# 输出安装信息
echo "=== Charge Control Module 安装 ==="
echo "LOW_THRESHOLD: $LOW_THRESHOLD%"
echo "HIGH_THRESHOLD: $HIGH_THRESHOLD%"
echo "POLL_INTERVAL: $POLL_INTERVAL秒"
echo "ENABLE_LOG: $ENABLE_LOG"
echo "================================"

exit 0