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
- 本次 run 在远端 manifest 过滤后计算实际待传任务数与字节总量；上传到原生 macOS 时
  通过可选 `X-Android-Sync-Batch-Total-Bytes` header 发送整批字节量。此 header 只供
  macOS 显示整任务剩余量和 ETA，不改变 Android 通知的进度口径。
- 允许用户在应用内编辑局域网/NAS 目标 URL。
- 支持用系统相机扫描 macOS 应用显示的地址二维码；打开 Android Sync 后会校验并
  自动保存新的 HTTP/HTTPS 目标 URL。
- 相册白名单变更会替换本次同步范围；确认页只上传明确保留的媒体。
- 同步由原生 `ForegroundService` 执行；退后台、锁屏或 Activity 重建后仍可继续传输，通知栏显示进度。
- 应用进程被系统回收后，重新打开应用会恢复未完成任务；用户强制停止应用或厂商省电策略可能中断服务。
- 单个文件失败后会继续后续文件；失败项需要用户手动重试。本版本不支持单文件字节级断点续传。
- 当目标明确识别为原生 macOS Android Sync Receiver 时，Mac 暂停会让当前被中断文件保持
  等待；Mac 恢复后 Android 从文件开头重传该文件，不把暂停记为普通失败。通用 WebDAV/HTTP
  目标及普通网络错误仍遵循单次尝试和手动重试规则。
- 同步期间可继续滚动媒体库，并可从传输卡点击“停止”中断当前上传和后续任务。
  如果同步正等待 Mac 恢复，点击“停止”也会退出等待并停止本次 run，不会在 Mac 恢复后重传。
- 显示原生首页仪表盘和队列详情页。
- Android launcher 使用 adaptive icon，品牌标志为由 cyan、coral red、warm yellow 和 deep charcoal
  组成的模块化 `SYNC` 字标。

如需在本机接收文件，请运行原生 macOS 应用：

```bash
./macos/build_and_run.sh
```

然后把 Android 目标 URL 设置为 macOS 应用显示的局域网地址，例如：

```text
http://192.168.1.10:8765/uploads/
```

也可以点击 macOS 工具栏中的二维码按钮，再用 Android 手机的系统相机扫码并选择
打开 Android Sync。应用会切换到设置页并提示“接收地址已更新”，无需手工输入。
只扫描可信电脑显示的二维码。

如需使用 Synology、QNAP 或其他 NAS，请启用 WebDAV，或运行任何能在配置目标 URL
接受 HTTP `PUT` 的接收端。

原生 Mac 暂停控制通过接收端根端点的 `service: Android Sync Receiver` 标识协商；`GET /health`
提供 `status`、`receiver_state`（`running`、`pausing`、`paused`）和 `pause_epoch`。Android 只在
该控制通道明确证明接收端暂停/恢复代次变化后，才把 PUT 中断归类为暂停并整文件重传；临时
健康检查失败不会被当作恢复或重试证据。

## 浏览器原型

最初的交互式 UI 概念保留在 `android/prototype/`。可使用任意静态 HTTP 服务器
托管该目录并在浏览器中查看。
