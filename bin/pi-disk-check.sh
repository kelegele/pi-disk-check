#!/bin/sh
# 定时磁盘检查：预检超阈值时调 pi 生成清理清单并通知
# 数据落在项目内 data/；由 launchd/fh.pi-disk-check.plist 每日 10:00 触发

THRESHOLD=85                      # 使用率百分比门槛
VOLUME=/System/Volumes/Data
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
DATA_DIR="$PROJECT_ROOT/data"
LOG="$DATA_DIR/check.log"
REPORTS="$DATA_DIR/reports"
PI_BIN="$HOME/.pi/agent/bin/pi"

mkdir -p "$REPORTS"
cd "$HOME" || exit 1              # pi 需在 $HOME 下读 AGENTS.md 磁盘清理规范

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

# 日志超 1MB 则截断
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 1048576 ] && : > "$LOG"

USE_PCT=$(df -h "$VOLUME" | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
FREE_H=$(df -h "$VOLUME" | awk 'NR==2 {print $4}')
log "check: Data 卷使用率 ${USE_PCT}%，剩 ${FREE_H}（阈值 ${THRESHOLD}%）"

# 未超阈值：仅记日志，不触发 pi
[ "${USE_PCT:-100}" -lt "$THRESHOLD" ] && exit 0

log "超阈值，触发 pi 分析"
TODAY=$(date '+%F')
REPORT="$REPORTS/$TODAY.md"

"$PI_BIN" --no-session --no-extensions --no-skills --no-mcp --no-prompt-templates -p "本机磁盘空间紧张：Data 卷使用率 ${USE_PCT}%，仅剩 ${FREE_H}。按 /Users/fh/AGENTS.md 的「磁盘清理」规范做只读分析：df -h 确认总量后，du 逐层下钻 ~/Library/{Application Support,Containers,Caches}，再看 /Applications 与 ~/Projects，找出空间大头。产出分级清单（零风险可清 / 低风险 / 需用户决策），每项含路径、大小、建议清理命令。严禁删除任何文件。将完整报告写入 $REPORT（Markdown，无则创建，同日已有则覆盖更新）。最后回复一行摘要：总用量、估计可释放量、报告路径。" > "$DATA_DIR/last-pi-output.txt" 2>&1
STATUS=$?
log "pi exit=$STATUS；报告存在: $([ -f "$REPORT" ] && echo yes || echo no)"

osascript -e "display notification \"磁盘 ${USE_PCT}%，仅剩 ${FREE_H}。清理清单已生成：$REPORT\" with title \"磁盘空间告警\" sound name \"Glass\"" >/dev/null 2>&1
