#!/bin/sh
# 定时磁盘检查：预检超阈值时生成清理清单并通知
# pi 可用 → pi 智能分析（prompt 自包含分级规范，不依赖任何外部规则文件）；
# pi 未装/失败 → 自动降级为纯 shell 基础扫描。只分析，不删除。
#
# 用法: pi-disk-check [run|report|status]
#   run     立即执行一次检查（默认）
#   report  显示最近一次清理报告
#   status  检查记录与定时任务状态
#
# 环境变量:
#   PI_DISK_CHECK_THRESHOLD  使用率门槛百分比（默认 85）
#   PI_DISK_CHECK_DATA       数据目录（默认 brew 安装树内固定 var 路径；克隆安装为项目内 data/）
#   PI_DISK_CHECK_PI         pi 可执行文件路径（默认自动定位）
#
# 容量展示口径：一律 GB（十进制，1 GB = 10⁹ 字节），四位小数。

THRESHOLD="${PI_DISK_CHECK_THRESHOLD:-85}"
VOLUME=/System/Volumes/Data
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
# 数据目录：显式 env > Homebrew 安装树内固定 var 路径 > 项目内 data（克隆安装）
case "$0" in
  /opt/homebrew/*) BREW_PREFIX=/opt/homebrew ;;
  /usr/local/*)    BREW_PREFIX=/usr/local ;;
  *)               BREW_PREFIX= ;;
esac
DATA_DIR="${PI_DISK_CHECK_DATA:-${BREW_PREFIX:+$BREW_PREFIX/var/pi-disk-check}}"
DATA_DIR="${DATA_DIR:-$PROJECT_ROOT/data}"
LOG="$DATA_DIR/check.log"
REPORTS="$DATA_DIR/reports"

mkdir -p "$REPORTS"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

# 日志超 1MB 则截断
[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 1048576 ] && : > "$LOG"

show_report() {
  LATEST=$(ls -t "$REPORTS"/*.md 2>/dev/null | head -1)
  [ -z "$LATEST" ] && echo "暂无报告，先执行: pi-disk-check run" && exit 1
  echo "最近报告: $LATEST"
  echo
  cat "$LATEST"
}

show_status() {
  echo "== 定时任务 =="
  FOUND=0
  for L in fh.pi-disk-check homebrew.pi-disk-check sh.brew.pi-disk-check; do
    if launchctl print "gui/$(id -u)/$L" >/dev/null 2>&1; then
      echo "已加载（launchd）: $L"
      FOUND=1
    fi
  done
  BREW_SVC=$(brew services list 2>/dev/null | grep pi-disk-check)
  if [ -n "$BREW_SVC" ]; then
    echo "brew services: $BREW_SVC"
    FOUND=1
  fi
  [ "$FOUND" -eq 0 ] && echo "未检测到定时任务（手动执行: pi-disk-check run；克隆安装: ./install.sh install；brew: brew services start pi-disk-check）"
  echo
  echo "== 最近检查记录 =="
  tail -8 "$LOG" 2>/dev/null || echo "无"
  echo
  echo "== 历史报告 =="
  ls -t "$REPORTS"/*.md 2>/dev/null | head -5 || echo "无"
}

run_check() {
  USE_PCT=$(df "$VOLUME" | awk 'NR==2 {printf "%.4f", $3*100/($3+$4)}')
  FREE_GB=$(df "$VOLUME" | awk 'NR==2 {printf "%.4f", $4*512/1e9}')
  log "check: Data 卷使用率 ${USE_PCT}%，剩 ${FREE_GB} GB（阈值 ${THRESHOLD}%）"

  # 未超阈值：仅记日志，不分析（浮点比较）
  awk -v u="$USE_PCT" -v t="$THRESHOLD" 'BEGIN {exit (u<t) ? 0 : 1}' && exit 0

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
    # launchd 上下文 PATH 极简：pi 包 bin 用 `#!/usr/bin/env node` 找 node，
    # 本机 node 常在 nvm/homebrew，需显式补 PATH，否则 pi 子进程 exit 127
    for n in "$HOME/.nvm/versions/node"/*/bin /opt/homebrew/bin /usr/local/bin; do
      [ -d "$n" ] && PATH="$n:$PATH"
    done
    export PATH
    log "超阈值，触发 pi 分析（${PI_BIN}）"
    # 分级标准与勿动清单已内联，pi 无需读取任何外部规则文件
    "$PI_BIN" --no-session --no-extensions --no-skills --no-mcp --no-prompt-templates -p "磁盘空间紧张：Data 卷使用率 ${USE_PCT}%，仅剩 ${FREE_GB} GB。做只读分析，严禁删除任何文件。

方法：df /System/Volumes/Data 确认总量；du -xk 逐层下钻 ~/Library/{Application Support,Containers,Group Containers,Caches,Logs,Developer}，再看 /Applications 与 ~/Projects，找出空间大头。报告中大小一律以 GB 为单位、保留四位小数（1 GB = 10⁹ 字节）。

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
    # du -xk 采集 KB；展示统一 GB 四位小数；路径取首个 tab 之后整段
    fmt_list() { awk '{p=substr($0, index($0,"\t")+1); printf "- `%s` %12.4f GB\n", p, $1*1024/1e9}'; }
    fmt_raw()  { awk '{p=substr($0, index($0,"\t")+1); printf "%12.4f GB  %s\n", $1*1024/1e9, p}'; }
    CACHES=$(find "$HOME/Library/Caches" -maxdepth 1 -mindepth 1 ! -name 'com.apple.*' -exec du -xk {} + 2>/dev/null | sort -k1,1nr | head -15 | fmt_list)
    CACHE_TOTAL=$(find "$HOME/Library/Caches" -maxdepth 1 -mindepth 1 ! -name 'com.apple.*' -exec du -xk {} + 2>/dev/null | awk '{s+=$1} END {printf "%.4f", s*1024/1e9}')
    NODE_MODULES=$(find "$HOME/Projects" -maxdepth 4 -type d -name node_modules -prune -exec du -xk {} + 2>/dev/null | sort -k1,1nr | head -15 | fmt_list)
    NM_TOTAL=$(find "$HOME/Projects" -maxdepth 4 -type d -name node_modules -prune -exec du -xk {} + 2>/dev/null | awk '{s+=$1} END {printf "%.4f", s*1024/1e9}')
    LOGS=$(du -xk "$HOME/Library/Logs" 2>/dev/null | cut -f1 | awk '{printf "%.4f", $1*1024/1e9}')
    APP_CACHES=$(find "$HOME/Library/Application Support" -maxdepth 3 -type d -iname 'cache*' -exec du -xk {} + 2>/dev/null | sort -k1,1nr | head -10 | fmt_list)
    APPS=$(du -xk /Applications/* 2>/dev/null | sort -k1,1nr | head -10 | fmt_list)
    CONTAINERS=$(du -xk "$HOME/Library/Containers"/* 2>/dev/null | sort -k1,1nr | head -8 | fmt_list)
    OVERVIEW=$(du -xk "$HOME/Library/Caches" "$HOME/Library/Application Support" "$HOME/Library/Containers" "$HOME/Library/Group Containers" "$HOME/Library/Logs" "$HOME/Library/Developer" /Applications "$HOME/Projects" 2>/dev/null | sort -k1,1nr | fmt_raw)
    T_GB=$(df "$VOLUME" | awk 'NR==2 {printf "%.4f", ($3+$4)*512/1e9}')
    U_GB=$(df "$VOLUME" | awk 'NR==2 {printf "%.4f", $3*512/1e9}')

    {
      echo "# 磁盘清理基础报告 — $TODAY"
      echo
      echo "> **基础模式**：未检测到 pi，纯 shell 扫描 + 规则分级。安装 pi 后重跑可获逐项智能分析。**只分析，未删除任何文件。**"
      echo
      echo "## 卷状态"
      echo
      echo "| 总计 | 已用 | 剩余 | 使用率 |"
      echo "|---|---|---|---|"
      echo "| ${T_GB} GB | ${U_GB} GB | ${FREE_GB} GB | ${USE_PCT}% |"
      echo
      echo "## 空间概览"
      echo
      echo "\`\`\`"
      echo "$OVERVIEW"
      echo "\`\`\`"
      echo
      echo "## 零风险可清（规则匹配，删前请逐项确认）"
      echo
      echo "### ~/Library/Caches 非 com.apple.* 项（合计 ${CACHE_TOTAL} GB）"
      echo
      [ -n "$CACHES" ] && echo "$CACHES" || echo "- 无"
      echo
      echo "### ~/Projects 下 node_modules（合计 ${NM_TOTAL} GB，pnpm/npm install 可重装）"
      echo
      [ -n "$NODE_MODULES" ] && echo "$NODE_MODULES" || echo "- 无"
      echo
      echo "## 低风险（可再生，逐项确认后清）"
      echo
      [ -n "$LOGS" ] && echo "- \`~/Library/Logs\` ${LOGS} GB（应用日志，自动重建）"
      [ -n "$APP_CACHES" ] && echo "$APP_CACHES" | sed 's/$/（应用缓存目录）/'
      echo "- \`~/Library/Developer/DerivedData\`、\`CoreSimulator\`（构建产物/模拟器，可再生）"
      echo
      echo "## 需用户决策（空间大头，逐项判断）"
      echo
      echo "### /Applications"
      echo
      echo "$APPS"
      echo
      echo "### ~/Library/Containers（含聊天数据，媒体删除后历史不可再看，优先应用内清理）"
      echo
      echo "$CONTAINERS"
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

  osascript -e "display notification \"磁盘 ${USE_PCT}%，仅剩 ${FREE_GB} GB。${MODE_NOTE}：$REPORT\" with title \"磁盘空间告警\" sound name \"Glass\"" >/dev/null 2>&1
}

case "${1:-run}" in
  run)    run_check ;;
  report) show_report ;;
  status) show_status ;;
  *)      echo "用法: pi-disk-check [run|report|status]（详见脚本头部注释）"; exit 2 ;;
esac
