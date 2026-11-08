# pi-disk-check 项目规范

launchd 定时磁盘哨兵：`df` 预检 Data 卷使用率，超阈值才触发 `pi -p` 生成分级清理清单并发 macOS 通知。

## 安全红线（最高优先级）

1. **任何自动流程严禁删除文件。** 脚本与 pi 只做只读分析；清理须经用户逐项批准（承袭 `/Users/fh/AGENTS.md`「磁盘清理」规范）。
2. 调整 THRESHOLD、触发时间等默认参数须用户确认。

## 架构

- `bin/pi-disk-check.sh`：预检 → ≥`THRESHOLD`%（默认 85）才调 pi；低于阈值零 token。数据路径由脚本自身位置推导。
- `launchd/fh.pi-disk-check.plist`：每日 10:00；睡眠错过唤醒后补跑一次。源文件在项目内，`install.sh install` 复制到 `~/Library/LaunchAgents`。
- `install.sh`：`install` / `uninstall` / `status` / `run`（手动立即执行一次）。

## 数据口径

- `data/check.log`：一行一事件（`时间 事件`），超 1MB 自动截断。
- `data/reports/YYYY-MM-DD.md`：当日清理清单（分级：零风险可清/低风险/需决策），同日覆盖更新。
- `data/last-pi-output.txt`：最近一次 pi 原始输出，仅诊断用。
- `data/` 全部为运行产物，不入 Git。

## pi headless 陷阱

- 必须用绝对路径 `~/.pi/agent/bin/pi`：launchd 环境无 zshrc PATH；该启动器自带 node 路径解析，不依赖 nvm。
- 参数组合已验证可用：`--no-session --no-extensions --no-skills --no-mcp --no-prompt-templates -p "<prompt>"`。
- 调 pi 前必须 `cd $HOME`：使 pi 读到全局 AGENTS.md 的磁盘清理规范（du 下钻路径与分级标准皆出自彼）。

## 环境

- 本项目无网络操作，与「bash 非交互无代理」约束无关。

## 多 Agent 交接
- 开始时读取 HANDOVER.md 与对应任务记录，沿用原任务编号，登记负责人、目标和状态。
- 有进展、阻塞或用户新决定时更新任务记录；结束前补齐产物、证据、未完成项和下一步，在 HANDOVER.md 同步摘要和入口。
- 自动记录只反映会话状态。Agent 核对并填写业务结果；最终回复附记录路径，无法写入时标记「待同步」。
