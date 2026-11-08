# HANDOVER — pi-disk-check

## 0. 现状与启动

- **已安装、已实跑**（2026-11-09）：launchd 已加载（每日 10:00）；脚本多轮真实验证（pi 模式与降级模式均通过），报告与日志见 `data/`。手动调试直接 `./install.sh run`。**清理未执行，待用户逐项批准。**
- **已去硬依赖**（发布公开改造）：pi 为可选增强（`PI_DISK_CHECK_PI` env → 常见路径 → `$PATH` 定位；未装或失败自动降级纯 shell 基础扫描）；pi prompt 自包含分级规范，不读全局 AGENTS.md；plist 为模板（`@SCRIPT_PATH@`/`@DATA_DIR@` 占位符），install.sh 按实际路径替换后装入 `~/Library/LaunchAgents`。可直接发布（brew tap 候选）。

## 1. 背景与去向

用户需要定期检查磁盘、太满时提醒清理。原方案以临时脚本形式产出于主目录会话，用户叫停后要求清掉写盘产物、升格为独立项目并交接。临时脚本已删（`~/bin/pi-disk-check.sh`），headless 验证走 `--no-session` 无残留。

## 2. cwd / 环境陷阱

- **launchd 环境 PATH 精简**：pi 定位顺序 `PI_DISK_CHECK_PI` env → 常见路径（`~/.pi/agent/bin/pi` 等）→ `$PATH`；启动器自带 node 解析，不依赖 nvm。
- **无全局 AGENTS.md 依赖**：分级标准与勿动清单已内联进 prompt，脚本 `cd` 项目根而非 `$HOME`。pi 仍会读全局 AGENTS.md 并受其「产出归子文件夹」规范影响，故 prompt 必须声明报告路径为唯一允许路径（已实现，曾因此越界写过 `~/disk-cleanup/`）。
- **pi headless 参数组合已验证**：`--no-session --no-extensions --no-skills --no-mcp --no-prompt-templates -p`。
- **bash 3.2 吞字节陷阱**：`$VAR` 不带花括号紧跟全角字符会吞字节（变量值与全角首字节一起丢），多字节字符串内一律 `${VAR}`；awk 按空白分列会截断含空格路径，用 `sub(/^[^\t]*\t/, "")` 取 tab 后整段。
- bash 非交互无代理环境变量；本项目无网络操作，不受影响。

## 3. 目录地图与产出定位

```
pi-disk-check/
├── AGENTS.md                       # 项目规范：红线、架构、数据口径、pi 陷阱、多 Agent 交接（真相源）
├── HANDOVER.md                     # 本文档
├── README.md                       # 快速上手
├── install.sh                      # install/uninstall/status/run
├── bin/pi-disk-check.sh            # 主脚本：预检→触发 pi→通知
├── launchd/fh.pi-disk-check.plist  # 每日 10:00；模板源文件（占位符），安装时按实际路径替换到 ~/Library/LaunchAgents
├── .agent-handoff.json             # 交接模式开关（enabled=true，勿动）
├── scripts/agent_hook.py           # 生命周期钩子：自动运行记录（docs/execution/agent-runs/）
├── .codex/hooks.json               # Codex 钩子配置（5 事件）
├── .zcode/config.json              # ZCode 钩子配置（3 事件）
├── .qwen/settings.json             # QwenWork 钩子配置（4 事件）
├── data/                           # 运行产物（gitignore）：check.log / reports/ / last-pi-output.txt
└── .gitignore
```

## 4. 数据口径与勿动约定

- `data/reports/*.md` 是给用户看的清理决策依据，**只生成、不执行**；删除任何文件须用户逐项批准。
- 报告同日覆盖更新（`YYYY-MM-DD.md`），历史日期报告勿动。
- plist 以项目内 `launchd/` 为源（模板，含占位符），`~/Library/LaunchAgents/` 下是替换后的副本；改参数改源文件后重跑 `./install.sh install`。

## 5. 自动运行记录

交接模式已开启（`.agent-handoff.json` enabled=true）。Codex／ZCode／QwenWork 钩子配置就位，钩子脚本已实弹验证（模拟 SessionStart 生成 run 目录成功，测试数据已清理）。运行记录落 `docs/execution/agent-runs/<Agent>-<hash>/`（runtime.json + events.jsonl + handover.md）；钩子只记状态，业务结果由 Agent 核对填写。**钩子在客户端新会话才加载**：已有打开的 Codex/ZCode/QwenWork 会话需重开。

## 6. 可继续方向（未指派）

1. 发布：Homebrew tap（formula + `brew services`），README 已含发布说明；硬依赖已全部去除。
2. 通知渠道扩展：企微/邮件推送（当前仅 macOS 通知）。
3. 成本优化：限制 pi 下钻深度或白名单目录，缩短耗时。
4. 阈值精化：百分比 + 绝对剩余空间双条件（大盘 90% 仍剩几十 G 时不该报警）。

## 7. 协作红线引用

- `~/AGENTS.md`「磁盘清理」：未经用户逐项同意不得删除。
- `~/agent-project-handoff/STARTUP.md` 会话交接模式：项目根 `.agent-handoff.json` 未配置时按该流程询问用户，勿擅自写入。
