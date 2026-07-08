# B23：Android 与 macOS QA 反馈修复

日期：2026-07-08
分支：`main`
提交：`7c2c0c6`
依据：用户真机/GUI QA 反馈（Android 7 项、macOS 4 项）

## 目标

修复 Android 端深色 UI 可读性、缩略图/预览、同步状态显示和横竖屏重扫问题；修复
macOS 端已删除清空、传输卡跳动、总任务进度和媒体原始时间排序问题。

## 范围

- Android：
  - 深色 theme、状态栏/导航栏亮色图标、控件默认深色化。
  - `MainActivity` 固定竖屏，避免旋转重建触发重扫。
  - 缩略图 `ImageView` 设置 stable tag，并让缩略图/placeholder 铺满 cell。
  - 预览 dialog 显示后再触发加载，并允许未 attach 时完成设置；增加图片 fallback
    采样解码。
  - 确认页补状态栏 padding，避免同步确认页贴左贴上。
  - 媒体库网格显示 `未同步`/`已同步`/`上传中`/`失败` badge。
  - 上传增加可选 `X-Android-Sync-Batch-Index` 与 `X-Android-Sync-Batch-Total` header。
- macOS：
  - 接收端解析 batch header，并传入 `AppModel` 传输状态。
  - 传输卡固定高度，速度行占位，显示完成/总数、接收中数量和剩余字节。
  - 已删除分类 toolbar 新增“清空已删除”；清空只隐藏已删除 tombstone，不擦除
    `uploads.jsonl`。
  - 列表排序/日期过滤/列表显示改用媒体原始时间（`dateTaken` → `dateModified`
    → `dateAdded` → `receivedAt`），Inspector 也显示原始时间 fallback。
  - `LibraryRepository.libraryRecords()` 从 sidecar fallback 读取原始时间字段。

## 非目标

- 不改变产品版本号 `0.1.2`。
- 不擦除 manifest tombstone，不做 manifest compaction。
- 不实现认证/TLS。
- 不宣称 Android 到 Mac 的真实大文件端到端传输已通过。

## 风险和决策

- R-001/R-002：触及 Android 缩略图、预览和 UI 更新；用有界请求、tag 校验、采样
  fallback 保持内存控制，真机压力仍需继续观察。
- R-003：新增 batch header 不改变可信局域网安全边界。
- R-004/R-007：macOS 接收端仍保留 `.part` 暂存和尺寸校验。
- R-008：已删除清空不擦 `uploads.jsonl`，避免破坏 tombstone 语义；manifest 增长
  风险仍开放。
- ADR-003、ADR-004、ADR-005、ADR-006、ADR-007 保持不变。

## 不变量

- Android 仍使用本地 SDK 脚本构建，无 Gradle/第三方依赖。
- macOS 仍使用 SwiftPM/SwiftUI/SwiftData。
- 上传请求体、Content-Length、`.part` 暂存、原子提交、尺寸校验不变。
- 文件字节不转码、不重写，EXIF 等原始文件内嵌信息保留。
- 删除 tombstone 保留，Android reconciliation 语义不变。

## 验证

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
adb devices -l
adb install -r android/build/AndroidSync-debug.apk
adb shell am start -n com.androidsync.app/.MainActivity
adb exec-out screencap -p > /tmp/android-sync-current.png
curl -fsS http://127.0.0.1:8765/health
git diff --check
```

结果：

- Android JVM 测试通过，输出 `AlbumFilterTest passed`。
- Android APK 构建通过，输出 `android/build/AndroidSync-debug.apk`。
- macOS `swift test --package-path macos` 运行 96 个测试，全部通过。
- `./macos/build_and_run.sh verify` 通过。
- 无线 ADB 设备 `22081212C` 在线，APK 安装成功，应用启动到
  `com.androidsync.app/.MainActivity`。
- ADB 截图人工检查：状态栏为亮色文字，首屏缩略图可见，网格显示同步状态 badge。
- `curl -fsS http://127.0.0.1:8765/health` 返回 `{"status":"ok"}`。
- `git diff --check` 通过。

## 回滚

- Android 回滚涉及 `AndroidManifest.xml`、`MainActivity`、`HttpFileUploader`、`ui/`
  组件和 `styles.xml`；回滚后会恢复旧深色可读性/缩略图问题。
- macOS 回滚涉及 batch header、AppModel 传输状态、删除清空隐藏、媒体原始时间排序
  和测试；回滚不会删除用户媒体或 `uploads.jsonl`。
- 如需设备回退，重新安装上一版 APK。

## 结果

- 提交：`7c2c0c6`
- 结果：Android 与 macOS QA 反馈已实现代码修复并通过自动化/安装/启动验证。
- 后续：用户继续真机端到端传输 QA，尤其 GB 级视频、相册白名单、同步状态 badge、
  macOS 传输卡总数/进度和已删除清空行为。
