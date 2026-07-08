# B19：AlbumFilter 纯逻辑与同步前确认态

日期：2026-07-08
分支：`codex/android-ui-redesign`
提交：Task 4 `d2db3fb`（AlbumFilter+测试）+ Task 5 `f571a1f`（确认态）
依据：`docs/superpowers/plans/2026-07-08-android-ui-redesign.md` Task 4–5

## 改动

- `core/AlbumFilter`（JVM 可测纯逻辑）：`pending(scanned, synced, excluded)`
  过滤已同步/已排除项并汇总 `totalBytes`，返回 `Selection`；
  `inWhitelist(item, bucketIds)`——null 白名单=未配置=不放行。
- `tests/AlbumFilterTest` + `run_tests.sh` 接入（TDD：先红后绿）。
- `ui/Widgets`：新增 `formatBytes(long)` 提为 `public static`；MainActivity
  原 `formatBytes` 删除，调用点改引用 `Widgets.formatBytes`。
- `ui/ConfirmSelectionView`：三列缩略图网格，点击单元格切换排除（角标 ✕ +
  0.35 alpha），底部“开始同步（N 项 · X）/取消”按钮随排除实时更新；
  构造 `(Activity, Widgets, ThumbnailLoader)`。
- `MainActivity`：新增 `confirm` 屏与 `confirmExcluded` 集合。首页“开始同步”
  （未在传输时）改为 `confirmExcluded.clear(); screen="confirm"`；`confirmView()`
  的待传清单用 `AlbumFilter.pending`（scanned=全部 task media，synced=DONE
  的 stableId，excluded=空）计算；`onConfirm` 回首页并 `startSync()`；
  `startSync()` 上传循环新增 `confirmExcluded.contains(media.stableId())` 跳过；
  `onBackPressed` confirm→home。

## 验证

- `./android/run_tests.sh` 通过（新增 `AlbumFilterTest passed`）；
  `./android/build.sh` 生成 APK。
- 确认态交互、排除后上传数量/字节吻合等真机行为未验证——留待设备 QA。

## 风险

- 未新增风险 ID。排除逻辑只在 `startSync` 上传循环内加一处 `continue`，
  不改队列锁语义、不在锁内做 I/O（R-009 不受影响）。
- `confirmExcluded` 为进程内临时态（不持久化）：进入确认态时清空，符合
  “临时排除”定义；排除项仍留在队列（WAITING），下次开始同步若未再排除会照常传。

## 不变量

- 上传协议、`.part` 暂存、队列锁内无 I/O 均不受影响。
- `AlbumFilter.pending` 与 `scanAll(空集合)` 的“空=不放行/无项”语义一致。
