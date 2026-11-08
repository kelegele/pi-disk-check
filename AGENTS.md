# pi-disk-check 项目规范

launchd 定时磁盘哨兵：`df` 预检 Data 卷使用率，超阈值才触发 `pi -p` 生成分级清理清单并发 macOS 通知。

## 安全红线（最高优先级）

1. **任何自动流程严禁删除文件。** 脚本与 pi 只做只读分析；清理须经用户逐项批准（承袭全局代理规范「磁盘清理」条目）。
2. 调整 THRESHOLD、触发时间等默认参数须用户确认。

## 架构

- `bin/pi-disk-check.sh`：预检 → ≥`THRESHOLD`%（默认 85）才分析；低于阈值零 token。
  - **pi 可选**：按 `PI_DISK_CHECK_PI` 环境变量 → 常见路径（`~/.pi/agent/bin/pi`、`/opt/homebrew/bin/pi`、`/usr/local/bin/pi`）→ `$PATH` 顺序定位；未装或 pi 运行失败自动降级为纯 shell 基础扫描（du 下钻 + 规则分级），无任何外部依赖。
  - pi prompt 自包含分级标准与勿动清单，不读全局 AGENTS.md；报告路径硬约束防 pi 自建目录。
- `launchd/fh.pi-disk-check.plist`：每日 10:00；睡眠错过唤醒后补跑一次（launchd 原生行为）。**源文件是模板**（`@SCRIPT_PATH@`/`@DATA_DIR@` 占位符），`install.sh install` 按实际路径替换后复制到 `~/Library/LaunchAgents`。
- `install.sh`：`install` / `uninstall` / `status` / `run`（手动立即执行一次）。

## 数据口径

- `data/check.log`：一行一事件（`时间 事件`），超 1MB 自动截断。
- `data/reports/YYYY-MM-DD.md`：当日清理清单（分级：零风险可清/低风险/需决策），同日覆盖更新。
- `data/last-pi-output.txt`：最近一次 pi 原始输出，仅诊断用。
- `data/` 全部为运行产物，不入 Git。

## pi headless 陷阱

- 必须用绝对路径 `~/.pi/agent/bin/pi`：launchd 环境无 zshrc PATH；该启动器自带 node 路径解析，不依赖 nvm。
- 参数组合已验证可用：`--no-session --no-extensions --no-skills --no-mcp --no-prompt-templates -p "<prompt>"`。
- **pi 会读全局 AGENTS.md 并受其「产出归子文件夹」规范影响自建目录**：报告路径必须在 prompt 中声明为唯一允许路径并禁自建目录（已实现），否则报告会写到 `~/disk-cleanup/` 之类越界位置。
- **bash 3.2 吞字节陷阱**：`$VAR` 不带花括号且紧跟全角字符时，变量值与全角字符首字节被吞（如 `$STATUS；` 日志变乱码）。多字节字符串内的变量一律写 `${VAR}`。
- **awk 空格路径陷阱**：du 输出按空白分列会截断含空格路径（`Application Support` → `Application`）；用 `sub(/^[^\t]*\t/, "")` 取 tab 后整段。

## 环境

- 本项目无网络操作，与「bash 非交互无代理」约束无关。

## 多 Agent 交接
- 开始时读取 HANDOVER.md 与对应任务记录，沿用原任务编号，登记负责人、目标和状态。
- 有进展、阻塞或用户新决定时更新任务记录；结束前补齐产物、证据、未完成项和下一步，在 HANDOVER.md 同步摘要和入口。
- 自动记录只反映会话状态。Agent 核对并填写业务结果；最终回复附记录路径，无法写入时标记「待同步」。
