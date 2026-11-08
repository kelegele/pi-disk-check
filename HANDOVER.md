# HANDOVER — pi-disk-check

## 0. 现状与启动

- **未安装、未实跑**：launchd 未加载，脚本从未执行过。续接第一步：
  `cd /Users/fh/Projects/pi-disk-check && ./install.sh install && ./install.sh run`
- 首跑即真实分析：建项侦察时磁盘已 **99%（剩 7.2Gi）**，超阈值 85%，会真实触发 pi 分析 + 系统通知，预计数分钟。
- 手动调试脚本可直接 `./install.sh run`，无需经过 launchd。

## 1. 背景与去向

用户需要定期检查磁盘、太满时提醒清理。原方案以临时脚本形式产出于主目录会话，用户叫停后要求清掉写盘产物、升格为独立项目并交接。临时脚本已删（`~/bin/pi-disk-check.sh`），headless 验证走 `--no-session` 无残留。

## 2. cwd / 环境陷阱

- **launchd 环境 PATH 精简**：pi 必须用绝对路径 `~/.pi/agent/bin/pi`；启动器自带 node 解析，不依赖 nvm。
- **launchd 无 cwd 概念（实为 `/`）**：脚本内已 `cd $HOME`，保证 pi 读到 `/Users/fh/AGENTS.md` 磁盘清理规范。
- **pi headless 参数组合已验证**：`--no-session --no-extensions --no-skills --no-mcp --no-prompt-templates -p`。
- bash 非交互无代理环境变量；本项目无网络操作，不受影响。

## 3. 目录地图与产出定位

```
pi-disk-check/
├── AGENTS.md                       # 项目规范：红线、架构、数据口径、pi 陷阱（真相源）
├── HANDOVER.md                     # 本文档
├── README.md                       # 快速上手
├── install.sh                      # install/uninstall/status/run
├── bin/pi-disk-check.sh            # 主脚本：预检→触发 pi→通知
├── launchd/fh.pi-disk-check.plist  # 每日 10:00；源文件，安装时复制到 ~/Library/LaunchAgents
├── data/                           # 运行产物（gitignore）：check.log / reports/ / last-pi-output.txt
└── .gitignore
```

## 4. 数据口径与勿动约定

- `data/reports/*.md` 是给用户看的清理决策依据，**只生成、不执行**；删除任何文件须用户逐项批准。
- 报告同日覆盖更新（`YYYY-MM-DD.md`），历史日期报告勿动。
- plist 以项目内 `launchd/` 为源，`~/Library/LaunchAgents/` 下是副本；改参数改源文件后重跑 `./install.sh install`。

## 5. 可继续方向（未指派）

1. 安装 + 首跑验证（第 0 节命令），核对通知与报告质量。
2. 通知渠道扩展：企微/邮件推送（当前仅 macOS 通知）。
3. 成本优化：限制 pi 下钻深度或白名单目录，缩短首跑耗时。
4. 阈值精化：百分比 + 绝对剩余空间双条件（大盘 90% 仍剩几十 G 时不该报警）。

## 6. 协作红线引用

- `/Users/fh/AGENTS.md`「磁盘清理」：未经用户逐项同意不得删除。
- `/Users/fh/AGENTS.md` 会话交接模式：项目根 `.agent-handoff.json` 未配置，续接会话按 `/Users/fh/agent-project-handoff/STARTUP.md` 询问用户，勿擅自写入。
