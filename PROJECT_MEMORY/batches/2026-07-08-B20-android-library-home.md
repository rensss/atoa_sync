# B20：传输卡片行与深色媒体库首页

日期：2026-07-08
分支：`codex/android-ui-redesign`
提交：Task 6 `6257ce7`（TransferCardView）+ Task 7 `6cf64d8`（媒体库首页/两 tab）
依据：`docs/superpowers/plans/2026-07-08-android-ui-redesign.md` Task 6–7

## 改动

- `ui/TransferCardView`：渐变进度卡（“接收中 done/total · 剩 X”）+ 今日统计卡
  + 失败横幅（`STATUS_FAILED` 12% 底）+ 点击展开逐文件行（失败行带“重试”，
  经 `RetryHandler`）。默认 GONE；`showProgress/showTodayStats/showFailure/
  clearFailure/bindTasks/hide` 驱动，均 UI 线程调用。
- `ui/LibraryPageView`：深色媒体库首页——相册 chips 过滤行（选中高亮，尾部
  “管理”chip）+ `host.transferCard()` + 三列缩略图网格（点击预览）+ 右下同步 FAB。
- `MainActivity`（重写 UI 层，815 行）：
  - `screen` 收敛为 `library/settings/albumPicker/confirm`，默认 `library`；
    `navBar` 缩为两项（媒体库/设置），深色样式。
  - 删除全部旧 home/queue/detail 页方法、刷新方法、`ProgressRing`、
    `QueueRowViews`、`RecentTaskTileViews` 及其专属字段（grep 校验
    `homeView|queueView|detailView|ProgressRing` 无命中）。
  - 同步回调改驱动 `TransferCardView`：任务状态变化聚合 `SyncQueue` 活动任务
    调 `showProgress`+`bindTasks`；失败调 `showFailure`；全部完成调
    `showTodayStats(进程内今日计数, 字节)` 后 `postDelayed` 3 秒 `hide()`。
  - 预览改为全屏 `Dialog`（图片 `loadPreviewAsync`；视频“用系统播放器打开”→
    `openMedia`），替代旧 detailView。
  - `chipFilter` 只改显示过滤不改白名单；`computeVisibleItems`/
    `computeWhitelistAlbums` 从 `scannedMedia` 派生。

## 验证

- `./android/run_tests.sh` 通过；`./android/build.sh` 生成 APK。
- 今日统计口径为进程内完成计数（`SyncTask` 无完成时间字段）——已在代码与本记录注明。
- 媒体库网格/chips 过滤/传输卡片进度与展开/预览弹层/返回键路径等真机行为未验证——
  留待设备 QA（见 B21 清单）。

## 风险

- 未新增风险 ID。上传主循环并发/生命周期逻辑（R-001/R-002 相关）逐字保留：
  `submitTask/postTask/destroyed/syncRuns/queue.*` 均未改；仅把原按屏刷新调用点
  替换为 `driveTransferProgress()`（读 `queue.summary()`/`queue.tasks()`，UI 线程）。
- `transferCard` 单实例，`build()` 每次 library 渲染重建视图树；驱动方法作用于
  最新树。渲染期间若正在同步，`libraryView()` 末尾补一次 `driveTransferProgress()`
  以恢复进度显示。

## 不变量

- 上传协议、`.part` 暂存、队列锁内无 I/O 均不受影响。
- 缩略图/预览管线（B17 ThumbnailLoader）语义不变。
