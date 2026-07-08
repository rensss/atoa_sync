# B17：Theme token 与 MainActivity 拆壳

日期：2026-07-08
分支：`codex/android-ui-redesign`
提交：`9b6de96`
依据：`docs/superpowers/plans/2026-07-08-android-ui-redesign.md` Task 1

## 改动

Android UI 重设计首批，纯搬移不改逻辑：

- 新增 `ui/Theme.java`：深色工作台主题 token（色板与间距/圆角常量），
  数值与 macOS `Theme.swift` 一致。本批次仅定义，不接线。
- 新增 `ui/Widgets.java`：把 MainActivity 的 14 个程序化 View 工厂方法
  （`pageLayout/card/title/sectionHeader/label/icon/actionButton/smallButton/
  textButton/weightParams/color/rounded/dp/statusBarHeight`）原样搬入，
  构造 `Widgets(Activity)`，方法体逐字保留，仅把隐式 Activity 引用改为字段。
- 新增 `ui/ThumbnailLoader.java`：把缩略图/预览加载管线（缓存、失败缓存、
  线程池、in-flight 去重、`ThumbnailTarget/PreviewTarget`、bitmap 加载与
  completion）整体搬入，构造 `ThumbnailLoader(Activity, ContentResolver)`。
  原 `loadThumbnailAsync` 更名为 `loadThumbnailInto`；生命周期标志
  `destroyed` 改为本类 `shutdown`，经 `shutdown()` 置位；`renderGeneration`
  随管线迁入，经 `bumpGeneration()` 递增。
- MainActivity：新增 `widgets`/`thumbnailLoader` 字段（`onCreate` 内构造，
  在 `render()` 之前），所有旧调用点改为 `widgets.xxx(...)`；`render()` 的
  代次递增改调 `thumbnailLoader.bumpGeneration()`；`onDestroy` 改调
  `thumbnailLoader.shutdown()`；`thumbnail()` 与 `detailView()` 的加载触发
  改调 loader。行数由 1914 降至 1502。

## 验证

- `./android/run_tests.sh` 通过（core JVM 测试 harness，`SyncQueueTest`）。
- `./android/build.sh` 生成 `AndroidSync-debug.apk`。
- UI 层无自动化测试（harness 只编译 `core`）。纯搬移预期行为零变化，
  但真机 QA 未执行——不得表述为已验证。

## 风险

- 未新增风险 ID。缩略图管线的并发/生命周期语义（R-001/R-002 相关）逐字保留：
  锁、in-flight 去重、weak 引用、代次比对均未改；`shutdown()` 复刻原
  `onDestroy` 的清理顺序（清 request、清 in-flight、`shutdownNow` 线程池）。
- 唯一语义变更：`renderGeneration`/生命周期标志的持有者由 Activity 迁至
  loader，二者仍单实例、同主线程驱动，等价。

## 不变量

- 上传协议、队列锁内无 I/O 约束、`.part` 暂存均不受影响（本批次不触及）。
- 主题 token 已定义但未接线；各页仍用旧浅色硬编码值，观感不变。
