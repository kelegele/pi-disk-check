# pi-disk-check

launchd 定时磁盘哨兵。每日 10:00 预检 Data 卷使用率，≥85% 才生成清理清单（零风险可清 / 低风险 / 需决策）并发 macOS 通知。**只分析，不删除；清理须用户逐项批准。**

## 两种模式

| 模式 | 触发条件 | 产出 |
|---|---|---|
| pi 智能分析 | 检测到 [pi](https://github.com/earendil-works/pi)（自动扫描 `~/.pi/agent/bin/pi`、`/opt/homebrew/bin/pi`、`/usr/local/bin/pi`、`$PATH`，可用环境变量 `PI_DISK_CHECK_PI` 显式指定） | 逐项智能分级报告，含建议命令；调 LLM 有 token 成本，每次数分钟 |
| 基础扫描（降级） | pi 未装或 pi 运行失败 | 纯 shell `du` 下钻 + 规则分级，无任何外部依赖 |

分级标准与勿动清单已内置于脚本，两种模式均不读取外部规则文件。

## 安装

### Homebrew（推荐）

```sh
brew install kelegele/tap/pi-disk-check
brew services start pi-disk-check   # 注册 launchd 每日 10:00 定时
```

数据与报告落 `$(brew --prefix)/var/pi-disk-check/`；升级 `brew upgrade`，停用 `brew services stop pi-disk-check`。

### 克隆安装

```sh
git clone https://github.com/kelegele/pi-disk-check
cd pi-disk-check
./install.sh install   # 按实际路径生成 plist 并加载 launchd 任务（~/Library/LaunchAgents）
```

## 手动命令

```sh
pi-disk-check run      # 立即执行一次检查（默认；克隆安装用 bin/pi-disk-check.sh）
pi-disk-check report   # 显示最近一次清理报告
pi-disk-check status   # 检查记录与定时任务状态
```

环境变量：`PI_DISK_CHECK_THRESHOLD` 门槛百分比（默认 85）、`PI_DISK_CHECK_DATA` 数据目录、`PI_DISK_CHECK_PI` 指定 pi 路径、`PI_DISK_CHECK_MAX_NOTIFS` 每日通知上限（默认 2，0=静默；报告照常生成）。

## 调参

- 阈值：环境变量 `PI_DISK_CHECK_THRESHOLD`，或克隆版改 `bin/pi-disk-check.sh` 顶部 `THRESHOLD`。
- 触发时间：克隆版改 `launchd/fh.pi-disk-check.plist` 后重跑 `./install.sh install`；brew 版固定每日 10:00（睡眠错过唤醒后由 launchd 补跑）。

## 产出

- 报告：`data/reports/YYYY-MM-DD.md`（同日覆盖更新）
- 日志：`data/check.log`（超 1MB 自动截断）
- pi 原始输出：`data/last-pi-output.txt`（仅诊断用）
- 通知：默认 osascript（点击仅激活发送方应用）；装 terminal-notifier（`brew install terminal-notifier`）后首次需授权，点击即直达当日报告

## 发布

安装脚本与 plist 模板均无硬编码路径、无项目外依赖（pi 为可选增强），可直接发布；Homebrew 分发建议走 tap + `brew services start`。
