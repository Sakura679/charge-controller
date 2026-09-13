# 实现摘要

## 已完成的任务

### 1. 创建安装时引导文件 customize.sh
- 位置: `./customize.sh`
- 功能:
  - 设置所有脚本的执行权限 (charger-daemon.sh, post-fs-data.sh, service.sh, uninstall.sh, customize.sh)
  - 创建必要的目录（包括 config 目录）
  - 从 `config/default.conf` 读取配置值
  - 动态更新 `module.prop` 中的描述，将占位符替换为实际值
  - 输出安装信息

### 2. 使 module.prop 能读取配置文件中的阈值
- 问题: 原 module.prop 描述中显示硬编码的占位符 "LOW_THRESHOLD%" 和 "HIGH_THRESHOLD%"
- 解决方案: 
  - module.prop 已经包含正确的占位符: `description=充电阈值控制：低于LOW_THRESHOLD% 开始充电，高于HIGH_THRESHOLD% 停止充电，循环。`
  - customize.sh 在安装时会读取 `config/default.conf` 中的实际值，并替换这些占位符
  - 例如，当前配置中 LOW_THRESHOLD=30, HIGH_THRESHOLD=80，安装后 module.prop 描述将变为:
    `description=充电阈值控制：低于30% 开始充电，高于80% 停止充电，循环。`

### 3. 修复日志问题并添加日志轮转功能
- 问题: 即使配置文件中 `ENABLE_LOG=false`，模块仍会产生日志文件并随时间增长
- 根本原因:
  1. `service.sh` 中无条件地将守护进程输出重定向到 `log.txt`
  2. `charger-daemon.sh` 中的错误消息直接写入日志文件，不受 `ENABLE_LOG` 控制
- 解决方案:
  1. 修复 `service.sh`: 根据 `ENABLE_LOG` 值有条件地重定向输出
  2. 修复 `charger-daemon.sh`: 
     - 将直接写入日志的错误消息改为使用 `log_msg()` 函数
     - 添加日志轮转机制：每小时检查一次日志文件大小，超过1MB时保留最近100行
     - 添加日志轮转状态消息（仅在日志启用时记录）
  3. 更新模块版本至 1.0.6

### 4. 增强 customize.sh 的健壮性和默认行为
- 问题: 
  a. customize.sh 可能由于缺少 config 目录而无法读取配置文件，导致使用硬编码默认值
  b. module.prop 中的描述占位符替换可能失败，导致安装后仍显示 LOW_THRESHOLD% 和 HIGH_THRESHOLD% 占位符而不是实际值
- 解决方案:
  1. 添加了 `mkdir -p "$MODDIR/config"` 以确保 config 目录存在
  2. 更新了默认值中的 `ENABLE_LOG` 从 `false` 为 `true`，使其与配置文件中的新默认值保持一致
  3. 改进了 module.prop 描述更新机制：不再替换整行，而是直接替换占位符值（LOW_THRESHOLD 和 HIGH_THRESHOLD），这样更健壮，不受原有格式和间距影响
  4. 这确保即使配置文件丢失或不可读，模块也将使用所需的默认行为（日志启用）；并且 module.prop 将正确显示实际的阈值而不是占位符

## 工作原理

1. 用户通过 Magisk 安装模块时
2. Magisk 会自动执行 customize.sh (如果存在)
3. customize.sh 读取 config/default.conf 中的配置值
4. customize.sh 使用 sed 替换 module.prop 中的占位符为实际值
5. 模块安装完成后，module.prop 显示实际的阈值而不是占位符

## 当前配置值 (来自 config/default.conf)
- LOW_THRESHOLD=30% (低于此百分比开始充电)
- HIGH_THRESHOLD=80% (高于此百分比停止充电)
- POLL_INTERVAL=300秒 (5分钟)
- ENABLE_LOG=true

## 文件列表
- customize.sh (新增) - 安装时执行的脚本
- module.prop (未更改但现在能动态更新) - 模块属性文件
- config/default.conf - 配置文件
- 现有脚本: charger-daemon.sh (已修复日志问题并添加轮转), post-fs-data.sh, service.sh (已修复条件日志重定向), uninstall.sh (保持不变)