# Android Sync

Android Sync 用于把 Android 设备上的照片和视频传输到 macOS，或传输到局域网内
兼容 HTTP/WebDAV 的目标。

## 仓库结构

- `android/`：无第三方依赖的 Android 应用、测试、构建脚本和浏览器 UI 原型。
- `macos/`：原生 Swift 接收端、媒体库、测试、SwiftPM 清单和打包脚本。
- `docs/`：共享设计、计划和规格文档。
- `releases/`：版本化 APK 和历史发布说明。
- `PROJECT_MEMORY/`：当前技术状态、架构、风险、路线图、决策和交接上下文。

## Android

```bash
./android/run_tests.sh
./android/build.sh
```

签名调试 APK 输出到：

```text
android/build/AndroidSync-debug.apk
```

## macOS

```bash
swift test --package-path macos
./macos/build_and_run.sh
```

打包脚本会把应用包写入：

```text
dist/Android Sync.app
```

平台细节见 `android/README.md` 和 `macos/README.md`。

## 开发和代理上下文

- 贡献者和编码代理从 `AGENTS.md` 开始。
- 当前技术状态、架构、风险、路线图、决策和交接信息维护在 `PROJECT_MEMORY/`。
