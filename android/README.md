# Android Sync MVP

这是一个无第三方依赖的 Android MVP，使用本地 Android SDK 工具直接构建，不使用
Gradle。

## 构建

```bash
./android/run_tests.sh
./android/build.sh
```

签名调试 APK 输出到：

```text
android/build/AndroidSync-debug.apk
```

## 运行行为

- 通过 Android `MediaStore` 扫描手机媒体库。
- 使用稳定去重逻辑把照片和视频加入同步队列。
- 通过 HTTP/WebDAV 风格的 `PUT` 上传等待或失败的任务。
- 允许用户在应用内编辑局域网/NAS 目标 URL。
- 显示原生首页仪表盘和队列详情页。

如需在本机接收文件，请运行原生 macOS 应用：

```bash
./macos/build_and_run.sh
```

然后把 Android 目标 URL 设置为 macOS 应用显示的局域网地址，例如：

```text
http://192.168.1.10:8765/uploads/
```

如需使用 Synology、QNAP 或其他 NAS，请启用 WebDAV，或运行任何能在配置目标 URL
接受 HTTP `PUT` 的接收端。

## 浏览器原型

最初的交互式 UI 概念保留在 `android/prototype/`。可使用任意静态 HTTP 服务器
托管该目录并在浏览器中查看。
