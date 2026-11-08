#!/bin/sh
# pi-disk-check launchd 安装管理
# 用法: ./install.sh install|uninstall|status|run
set -e

LABEL=fh.pi-disk-check
ROOT=$(cd "$(dirname "$0")" && pwd)
PLIST_SRC="$ROOT/launchd/$LABEL.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_N=$(id -u)

bootout() { launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null || true; }

case "${1:-help}" in
  install)
    mkdir -p "$ROOT/data"
    bootout
    # 模板占位符按实际安装位置替换，不写死任何路径
    SCRIPT_ESC=$(printf '%s' "$ROOT/bin/pi-disk-check.sh" | sed 's/[&|]/\\&/g')
    DATA_ESC=$(printf '%s' "$ROOT/data" | sed 's/[&|]/\\&/g')
    sed -e "s|@SCRIPT_PATH@|$SCRIPT_ESC|g" -e "s|@DATA_DIR@|$DATA_ESC|g" "$PLIST_SRC" > "$PLIST_DST"
    launchctl bootstrap "gui/$UID_N" "$PLIST_DST"
    echo "已安装并加载。查看排程: ./install.sh status"
    echo "立即首跑验证: ./install.sh run"
    ;;
  uninstall)
    bootout
    rm -f "$PLIST_DST"
    echo "已卸载（项目与历史报告保留于 $ROOT）"
    ;;
  status)
    launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | grep -E 'state|program|run interval' || echo "未加载"
    ;;
  run)
    /bin/sh "$ROOT/bin/pi-disk-check.sh"
    echo "执行完毕，见 $ROOT/data/"
    ;;
  *)
    echo "用法: $0 install|uninstall|status|run"
    ;;
esac
