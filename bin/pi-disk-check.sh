#!/bin/sh
# 定时磁盘检查：预检超阈值时生成清理清单并通知
# pi 可用 → pi 智能分析（prompt 自包含分级规范，不依赖任何外部规则文件）；
# pi 未装/失败 → 自动降级为纯 shell 基础扫描。只分析，不删除。

THRESHOLD=85                      # 使用率百分比门槛
VOLUME=/System/Volumes/Data
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
DATA_DIR="$PROJECT_ROOT/data"
LOG="$DATA_DIR/check.log"
REPORTS="$DATA_DIR/reports"

mkdir -p "$REPORTS"
cd "$PROJECT_ROOT" || exit 1

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

# 日志超 1MB 则截断
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 1048576 ] && : > "$LOG"

USE_PCT=$(df -h "$VOLUME" | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
FREE_H=$(df -h "$VOLUME" | awk 'NR==2 {print $4}')
log "check: Data 卷使用率 ${USE_PCT}%，剩 ${FREE_H}（阈值 ${THRESHOLD}%）"

# 未超阈值：仅记日志，不分析
[ "${USE_PCT:-100}" -lt "$THRESHOLD" ] && exit 0

TODAY=$(date '+%F')
REPORT="$REPORTS/$TODAY.md"

# ---- pi 定位：显式 env > 常见安装路径 > PATH ----
PI_BIN="${PI_DISK_CHECK_PI:-}"
if [ -z "$PI_BIN" ]; then
  for c in "$HOME/.pi/agent/bin/pi" /opt/homebrew/bin/pi /usr/local/bin/pi; do
    [ -x "$c" ] && PI_BIN="$c" && break
  done
fi
[ -z "$PI_BIN" ] && PI_BIN=$(command -v pi 2>/dev/null || true)

run_pi() {
  log "超阈值，触发 pi 分析（${PI_BIN}）"
  # 分级标准与勿动清单已内联，pi 无需读取任何外部规则文件
  "$PI_BIN" --no-session --no-extensions --no-skills --no-mcp --no-prompt-templates -p "磁盘空间紧张：Data 卷使用率 ${USE_PCT}%，仅剩 ${FREE_H}。做只读分析，严禁删除任何文件。

方法：df -h /System/Volumes/Data 确认总量；du -xsh 逐层下钻 ~/Library/{Application Support,Containers,Group Containers,Caches,Logs,Developer}，再看 /Applications 与 ~/Projects，找出空间大头。

分级标准：
- 零风险可清：纯缓存与可再生数据——~/Library/Caches 中非 com.apple.* 项、各类 *-updater 残留、Chrome Service Worker CacheStorage、node_modules、Rust target/、DerivedData、go-build 缓存等。
- 低风险：可再生或有明确重建路径——应用日志、构建产物、旧版本残留、应用内 cache 目录；聊天类 App（微信/企业微信/Telegram 等）的媒体缓存删后历史消息媒体不可再看，只建议应用内清理。
- 需用户决策：应用本体（/Applications）、SDK 与开发工具、聊天媒体原件等，须用户逐项确认。

勿动红线：微信 Data/Library（消息库）与 db_storage（消息数据库）、~/Library/Metadata/CoreSpotlight（系统索引）、虚拟机/容器数据仅可经 docker 命令回收。

产出：将完整报告写入 $REPORT —— 这是唯一允许的报告路径，必须原样使用此绝对路径，禁止自建目录或写到其他位置（Markdown，无则创建，同日已有则覆盖更新）。报告含：卷状态、空间大头分布、三级清单（每项含路径、大小、说明、建议清理命令）、勿动清单。最后回复一行摘要：总用量、估计可释放量、报告路径。" > "$DATA_DIR/last-pi-output.txt" 2>&1
  STATUS=$?
  log "pi exit=${STATUS}；报告存在: $([ -f "$REPORT" ] && echo yes || echo no)"  # ${} 必带：bash3.2 下 $STATUS 紧跟全角字符会吞字节
  [ "$STATUS" -eq 0 ] && [ -f "$REPORT" ]
}

# ---- 降级：纯 shell 基础扫描 + 规则分级 ----
run_degraded() {
  log "降级为基础扫描（未检测到可用的 pi）"
  CACHES=$(find "$HOME/Library/Caches" -maxdepth 1 -mindepth 1 ! -name 'com.apple.*' -exec du -xsh {} + 2>/dev/null | sort -rh | head -15)
  CACHE_TOTAL=$(find "$HOME/Library/Caches" -maxdepth 1 -mindepth 1 ! -name 'com.apple.*' -exec du -xsk {} + 2>/dev/null | awk '{s+=$1} END {printf "%.1fG", s/1048576}')
  NODE_MODULES=$(find "$HOME/Projects" -maxdepth 4 -type d -name node_modules -prune -exec du -xsh {} + 2>/dev/null | sort -rh | head -15)
  NM_TOTAL=$(find "$HOME/Projects" -maxdepth 4 -type d -name node_modules -prune -exec du -xsk {} + 2>/dev/null | awk '{s+=$1} END {printf "%.1fG", s/1048576}')
  LOGS=$(du -xsh "$HOME/Library/Logs" 2>/dev/null | cut -f1)
  APP_CACHES=$(find "$HOME/Library/Application Support" -maxdepth 3 -type d -iname 'cache*' -exec du -xsh {} + 2>/dev/null | sort -rh | head -10)
  APPS=$(du -xsh /Applications/* 2>/dev/null | sort -rh | head -10)
  CONTAINERS=$(du -xsh "$HOME/Library/Containers"/* 2>/dev/null | sort -rh | head -8)
  OVERVIEW=$(du -xsh "$HOME/Library/Caches" "$HOME/Library/Application Support" "$HOME/Library/Containers" "$HOME/Library/Group Containers" "$HOME/Library/Logs" "$HOME/Library/Developer" /Applications "$HOME/Projects" 2>/dev/null | sort -rh)

  {
    echo "# 磁盘清理基础报告 — $TODAY"
    echo
    echo "> **基础模式**：未检测到 pi，纯 shell 扫描 + 规则分级。安装 pi 后重跑可获逐项智能分析。**只分析，未删除任何文件。**"
    echo
    echo "## 卷状态"
    echo
    df -h "$VOLUME" | awk 'NR==2 {printf "| 总量 | %s |\n| 已用 | %s（%s） |\n| 剩余 | %s |\n", $2, $3, $5, $4}'
    echo
    echo "## 空间概览"
    echo
    echo "\`\`\`"
    echo "$OVERVIEW"
    echo "\`\`\`"
    echo
    echo "## 零风险可清（规则匹配，删前请逐项确认）"
    echo
    echo "### ~/Library/Caches 非 com.apple.* 项（合计 ${CACHE_TOTAL}）"
    echo
    [ -n "$CACHES" ] && echo "$CACHES" | awk '{s=$1; sub(/^[^\t]*\t/, ""); printf "- `%s` %s\n", $0, s}' || echo "- 无"
    echo
    echo "### ~/Projects 下 node_modules（合计 ${NM_TOTAL}，pnpm/npm install 可重装）"
    echo
    [ -n "$NODE_MODULES" ] && echo "$NODE_MODULES" | awk '{s=$1; sub(/^[^\t]*\t/, ""); printf "- `%s` %s\n", $0, s}' || echo "- 无"
    echo
    echo "## 低风险（可再生，逐项确认后清）"
    echo
    [ -n "$LOGS" ] && echo "- \`~/Library/Logs\` ${LOGS}（应用日志，自动重建）"
    [ -n "$APP_CACHES" ] && echo "$APP_CACHES" | awk '{s=$1; sub(/^[^\t]*\t/, ""); printf "- `%s` %s（应用缓存目录）\n", $0, s}'
    echo "- \`~/Library/Developer/DerivedData\`、\`CoreSimulator\`（构建产物/模拟器，可再生）"
    echo
    echo "## 需用户决策（空间大头，逐项判断）"
    echo
    echo "### /Applications"
    echo
    echo "$APPS" | awk '{s=$1; sub(/^[^\t]*\t/, ""); printf "- `%s` %s\n", $0, s}'
    echo
    echo "### ~/Library/Containers（含聊天数据，媒体删除后历史不可再看，优先应用内清理）"
    echo
    echo "$CONTAINERS" | awk '{s=$1; sub(/^[^\t]*\t/, ""); printf "- `%s` %s\n", $0, s}'
    echo
    echo "## 勿动清单（红线）"
    echo
    echo "- 微信 \`Data/Library\`（消息库）与 \`db_storage\`（消息数据库）"
    echo "- \`~/Library/Metadata/CoreSpotlight\`（系统索引）"
    echo "- 虚拟机/容器数据仅经 docker 命令回收"
  } > "$REPORT"
  log "基础扫描完成；报告存在: yes"
}

if [ -n "$PI_BIN" ] && [ -x "$PI_BIN" ] && run_pi; then
  MODE_NOTE="清理清单已生成（pi 分析）"
else
  run_degraded
  MODE_NOTE="基础模式清单已生成（安装 pi 可获智能分级）"
fi

osascript -e "display notification \"磁盘 ${USE_PCT}%，仅剩 ${FREE_H}。${MODE_NOTE}：$REPORT\" with title \"磁盘空间告警\" sound name \"Glass\"" >/dev/null 2>&1
