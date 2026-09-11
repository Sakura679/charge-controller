# Charge Control Module / 充电控制模块

## English

A Magisk/KernelSU module that controls charging based on battery thresholds:
- When battery level falls below `LOW_THRESHOLD`%, charging is enabled.
- When battery level rises above `HIGH_THRESHOLD`%, charging is disabled.
- The cycle repeats, keeping the battery within a desired range to reduce wear when the device is constantly plugged in.

### Features
- Compatible with both **Magisk** and **KernelSU**.
- Detects kernel support for charging control interfaces (`charging_enabled` or `charge_control_start/end_threshold`).
- Provides real‑time status output during flashing (visible in the manager UI).
- Configurable thresholds and polling interval via module options.
- Low‑impact daemon (default polling every 5 minutes).
- Clean uninstall that restores default charging behavior.

### Installation
1. Download the latest `charge-control-module.zip` from the releases page.
2. Open **Magisk Manager** or **KernelSU Manager**.
3. Tap **+** → **Select a ZIP File** → choose the downloaded zip.
4. Reboot the device.

### Configuration
After installation, you can adjust the parameters:
- **LOW_THRESHOLD** – Battery % at which charging starts (default: 30).
- **HIGH_THRESHOLD** – Battery % at which charging stops (default: 80).
- **POLL_INTERVAL** – Seconds between each check (default: 300 seconds = 5 min).
- **ENABLE_LOG** – Set to `true` to write debug logs to `/data/adb/modules/charge-control-module/log.txt`.

These can be edited via the manager’s **Modules → Charge Control Module → Options** screen, or by manually editing `/data/adb/modules/charge-control-module/config/default.conf` and then restarting the daemon (or rebooting).

### How It Works
- The module’s `post-fs-data.sh` script checks for writable charging control sysfs nodes.
- If supported, it creates an enable flag and starts a daemon via `service.sh` (late_start).
- The daemon (`charger-daemon.sh`) reads the battery capacity from `/sys/class/power_supply/battery/capacity` and:
  - If ≤ LOW_THRESHOLD → enables charging (either writes `1` to `charging_enabled` or sets start/end thresholds).
  - If ≥ HIGH_THRESHOLD → disables charging (writes `0` to `charging_enabled` or sets thresholds).
  - Otherwise, does nothing to avoid unnecessary sysfs writes.
- On uninstall, the daemon is stopped and the charging interface is restored to its default state (full range thresholds or charging enabled).

### Notes
- The module **requires** a kernel that exposes at least one of the following files with write permission:
  - `/sys/class/power_supply/battery/charging_enabled`
  - `/sys/class/power_supply/battery/charge_control_start_threshold`
  - `/sys/class/power_supply/battery/charge_control_end_threshold`
- If your device’s kernel does not expose these (common on some vendor kernels), the module will refuse to install and display an error message. In that case, flash a kernel that supports charging control (e.g., a GKI‑compatible or mainline kernel) before using this module.
- The module is designed to be safe: it only writes when the battery crosses a threshold, minimizing wear on the sysfs nodes.

### License
This project is licensed under the MIT License – see the LICENSE file for details.

## 中文说明

一个适用于 Magisk/KernelSU 的充电控制模块，基于电量阈值控制充电：
- 当电量低于 `LOW_THRESHOLD`% 时，开始充电。
- 当电量高于 `HIGH_THRESHOLD`% 时，停止充电。
- 循环进行，使电池保持在设定区间内，以降低长时间插充电器造成的电池磨损。

### 特性
- 同时兼容 **Magisk** 与 **KernelSU**，同一个 ZIP 可直接刷入。
- 在挂载阶段检测内核是否提供可写的充电控制接口（`charging_enabled`、`charge_control_start_threshold`、`charge_control_end_threshold`）。
- 刷入过程中在管理器窗口实时输出检测结果、读取的配置以及守护进程 PID，便于用户确认状态。
- 可通过模块选项修改阈值和轮询间隔。
- 默认轮询间隔 5 分钟（可调），低资源占用。
- 卸载时会停止守护进程并恢复默认充电行为。

### 安装方法
1. 下载最新的 `charge-control-module.zip`（ releases 页面）。
2. 打开 **Magisk Manager** 或 **KernelSU Manager**。
3. 点击 「+」 → 「选择 ZIP 文件」 → 选择下载的 zip。
4. 刷入后重启设备。

### 配置说明
安装后，可在管理器的「模块 → Charge Control Module → 选项」界面修改以下参数，或直接编辑 `/data/adb/modules/charge-control-module/config/default.conf` 并重启守护进程（或重启）：
- **LOW_THRESHOLD** – 开始充电的电量百分比（默认 30%）。
- **HIGH_THRESHOLD** – 停止充电的电量百分比（默认 80%）。
- **POLL_INTERVAL** – 检测间隔（秒），默认 300（5 分钟），可设为 600（10 分钟）等。
- **ENABLE_LOG** – 是否开启日志（true/false），默认 false，开启后日志写入 `/data/adb/modules/charge-control-module/log.txt`.

### 工作原理
- `post-fs-data.sh` 脚本在 data 分区挂载后运行，读取配置并检测内核充电控制接口是否可写。
- 若支持，则创建启用标志并通过 `service.sh`（在 late_start 阶段）启动守护进程 `charger-daemon.sh`。
- 守护进程循环读取 `/sys/class/power_supply/battery/capacity`：
  - 当电量 ≤ LOW_THRESHOLD 时，打开充电（写入 1 到 `charging_enabled` 或设定开始阈值）。
  - 当电量 ≥ HIGH_THRESHOLD 时，关闭充电（写入 0 到 `charging_enabled` 或设定结束阈值）。
  - 中间区间不做任何写入，以免频繁触发充电IC。
- 卸载时 `uninstall.sh` 会停止守护进程，并把充电控制恢复为默认状态（阈值设为 0‑100 或打开 `charging_enabled`）。

### 注意事项
- 本模块 **要求** 内核至少提供以下任意一个文件且具有写权限：
  - `/sys/class/power_supply/battery/charging_enabled`
  - `/sys/class/power_supply/battery/charge_control_start_threshold`
  - `/sys/class/power_supply/battery/charge_control_end_threshold`
- 如果设备的内核没有这些可写接口（某些厂商定制内核常见），模块将在刷入过程中报错并拒绝安装，管理器会显示错误信息。此时需要刷入支持充电控制的内核（如 GKI 主线内核或其他开源内核）后才能使用。
- 模块设计为安全：仅在电量跨越阈值时才写入 sysfs，减少对节点的磨损。

### 许可证
本项目采用 MIT 许可证，详见 LICENSE 文件。

