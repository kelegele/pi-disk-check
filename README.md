# pi-disk-check

launchd 定时磁盘哨兵。每日 10:00 预检 Data 卷使用率，≥85% 才触发 pi 生成分级清理清单（零风险可清/低风险/需决策）并发 macOS 通知。**只分析，不删除。**

## 快速上手

```sh
./install.sh install   # 安装并加载 launchd 任务
./install.sh run       # 手动立即执行一次
./install.sh status    # 查看加载状态
./install.sh uninstall # 卸载（项目与历史报告保留）
```

## 调参

- 阈值：`bin/pi-disk-check.sh` 顶部 `THRESHOLD`。
- 时间：`launchd/fh.pi-disk-check.plist` 的 `StartCalendarInterval`。
- 改完重跑 `./install.sh install` 生效。

## 产出

- 报告：`data/reports/YYYY-MM-DD.md`
- 日志：`data/check.log`

详见 `AGENTS.md`（规范真相源）与 `HANDOVER.md`（交接）。
