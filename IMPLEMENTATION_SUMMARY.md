# 实现摘要

## 已完成的任务

### 1. 创建安装时引导文件 customize.sh
- 位置: `./customize.sh`
- 功能:
  - 设置所有脚本的执行权限 (charger-daemon.sh, post-fs-data.sh, service.sh, uninstall.sh, customize.sh)
  - 创建必要的目录
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
- ENABLE_LOG=false

## 文件列表
- customize.sh (新增) - 安装时执行的脚本
- module.prop (未更改但现在能动态更新) - 模块属性文件
- config/default.conf - 配置文件
- 现有脚本: charger-daemon.sh, post-fs-data.sh, service.sh, uninstall.sh (保持不变)