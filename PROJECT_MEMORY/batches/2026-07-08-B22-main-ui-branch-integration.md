# B22：UI 分支合入 main 与真机测试准备

日期：2026-07-08
分支：`main`
集成提交：Android UI 快进到 `2eb0889`；macOS UI 合并提交 `784139a`

## 目标

把两个待合并 UI 分支合入 `main`，构建并启动 Android/macOS 两端，为 Android 真机
传输测试准备可运行环境。

## 范围

- 合入 `codex/android-ui-redesign` 的 B17-B21 Android UI 重设计。
- 合入 `codex/macos-ui-redesign` 的 B10-B15 macOS UI 重设计。
- 解决 `PROJECT_MEMORY/00_PROJECT_STATUS.md` 与 `PROJECT_MEMORY/HANDOFF.md`
  的合并冲突，保留两个分支的状态事实。
- 构建、安装并启动 Android debug APK。
- 构建并启动 macOS 接收端应用。

## 非目标

- 不关闭 Android 真机 QA 清单。
- 不关闭 macOS GUI 手工 QA。
- 不改变上传协议、存储布局或发布版本号。
- 不推送远端分支或远端 `main`。

## 风险和决策

- R-001/R-002：仍需真机压力测试；本批只完成安装启动和自动化验证。
- R-003：接收端仍仅限可信局域网使用。
- R-004/R-005/R-007：macOS UI 合并保留接收端 `.part` 暂存、尺寸校验和失败处理。
- ADR-003/ADR-004/ADR-005/ADR-006/ADR-007 保持不变。

## 不变量

- Android 仍使用本地 SDK 脚本构建，不引入 Gradle 或第三方库。
- macOS 仍使用 SwiftPM/SwiftUI/SwiftData。
- `.part` 上传暂存、尺寸校验、manifest tombstone、队列锁内无 I/O 约束不变。
- `0.1.2` 产品版本不变。

## 验证

```bash
git diff --check --cached
./android/run_tests.sh
./android/build.sh
adb devices -l
adb install -r android/build/AndroidSync-debug.apk
adb shell monkey -p com.androidsync.app -c android.intent.category.LAUNCHER 1
./macos/build_and_run.sh verify
curl -fsS http://127.0.0.1:8765/health
swift test --package-path macos
```

结果：

- `git diff --check --cached` 在 macOS 合并冲突解决后通过。
- `./android/run_tests.sh` 通过，输出 `AlbumFilterTest passed`。
- `./android/build.sh` 通过，输出 `android/build/AndroidSync-debug.apk`。
- ADB 发现无线设备 `22081212C`（`adb-accebf07-sPKmgf._adb-tls-connect._tcp.`）。
- `adb install -r android/build/AndroidSync-debug.apk` 成功。
- `adb shell monkey -p com.androidsync.app -c android.intent.category.LAUNCHER 1`
  成功启动 `com.androidsync.app/.MainActivity`。
- `./macos/build_and_run.sh verify` 构建并启动 `dist/Android Sync.app` 成功。
- `curl -fsS http://127.0.0.1:8765/health` 返回 `{"status":"ok"}`。
- `swift test --package-path macos` 运行 92 个测试，全部通过。
- Mac 局域网测试 URL：`http://192.168.1.6:8765/uploads/`。

## 回滚

- 回滚 Android UI：把 `main` 回退到 `2eb0889` 之前的 `3bea146` 后重新应用必要
  后续提交，或用 Git revert 按 B17-B21 提交逆序回滚。
- 回滚 macOS UI：revert 合并提交 `784139a`。
- 回滚不会删除用户媒体、`uploads.jsonl` 或 Android 设备上的已安装应用；如需回退
  设备应用，需重新安装旧 APK。

## 结果

- 提交：Android UI 快进到 `2eb0889`；macOS UI 合并提交 `784139a`。
- 结果：两个 UI 分支已进入本地 `main`，自动化检查通过，Android APK 已安装并启动，
  macOS 接收端已启动且 health 正常。
- 后续：执行 B21 的 Android 真机 QA 清单；执行 macOS UI 的 GUI 手工 QA；根据结果
  更新 M1/M2/M3 里程碑和风险状态。
