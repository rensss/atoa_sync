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

## 手动调试指南

以下流程用于在本机手动启动 macOS 接收端、把调试 APK 安装到 Android 真机，并
验证两端能通过局域网通信。当前接收端没有认证令牌，只应在可信私有局域网内测试，
不要把 `8765` 端口暴露到公网。

### 1. 开启 Android ADB 调试

1. 在 Android 设备上打开 **设置**。
2. 进入 **关于手机**，连续点击 **版本号**、**MIUI 版本** 或厂商等价入口约 7 次，
   直到系统提示已进入开发者模式。
3. 返回设置，进入 **系统**、**更多设置** 或 **开发者选项**。
4. 打开 **USB 调试**。部分国产 ROM 还需要打开 **USB 安装** 或
   **USB 调试（安全设置）**，否则命令行安装 APK 可能被拒绝。
5. 用 USB 线连接 Mac 和 Android 设备。手机弹出 **允许 USB 调试吗？** 时，确认
   RSA 指纹来自可信电脑，然后点允许。
6. 在仓库根目录确认设备状态：

```bash
adb devices -l
```

正常状态会显示 `device`。如果显示 `unauthorized`，解锁手机并重新确认授权；如果
显示 `offline`，重新插拔 USB，或执行：

```bash
adb kill-server
adb start-server
adb devices -l
```

### 2. 可选：开启无线 ADB 调试

Android 11 及以上通常支持无线调试。无线调试需要 Android 设备和 Mac 连接到同一个
可信 Wi-Fi。

1. 在 Android 设备的 **开发者选项** 中打开 **无线调试**。
2. 进入无线调试详情页，选择 **使用配对码配对设备**。
3. 在 Mac 上输入设备显示的配对地址和端口：

```bash
adb pair <phone-ip>:<pairing-port>
```

4. 输入手机上显示的配对码。
5. 配对成功后，用无线调试详情页显示的连接地址和端口连接设备：

```bash
adb connect <phone-ip>:<debug-port>
adb devices -l
```

注意：`pairing-port` 和 `debug-port` 通常不是同一个端口。最终列表中显示 `device`
才表示无线 ADB 可用。

### 3. 启动 macOS 接收端

在仓库根目录运行：

```bash
./macos/build_and_run.sh
```

首次启动时：

1. 在 macOS 应用中选择接收文件夹。
2. 如果系统提示允许传入网络连接，选择允许。
3. 确认接收端健康检查通过：

```bash
curl -fsS http://127.0.0.1:8765/health
```

返回 `{"status":"ok"}` 表示本机接收端已启动。获取 Mac 局域网 IP：

```bash
ipconfig getifaddr en0
```

如果当前不是 Wi-Fi，先用下面命令查看默认网络接口，再从 `ifconfig` 查对应 IP：

```bash
route -n get default
ifconfig
```

Android 应用中要填写的上传地址格式为：

```text
http://<Mac-LAN-IP>:8765/uploads/
```

例如：

```text
http://192.168.1.9:8765/uploads/
```

### 4. 构建、安装并启动 Android 应用

在仓库根目录构建调试 APK：

```bash
./android/build.sh
```

安装到当前 ADB 设备：

```bash
adb install -r android/build/AndroidSync-debug.apk
```

可选：提前授予媒体读取权限，避免首次打开时手动点系统授权弹窗：

```bash
adb shell pm grant com.androidsync.app android.permission.READ_MEDIA_IMAGES
adb shell pm grant com.androidsync.app android.permission.READ_MEDIA_VIDEO
```

如果设备系统版本不支持某个权限，命令可能报错；这种情况下直接在应用里按系统弹窗
授权即可。

启动应用：

```bash
adb shell am start -n com.androidsync.app/.MainActivity
```

### 5. 配置目标并开始测试

1. 在 Android 应用首页点 **编辑**。
2. 把目标地址设置为 macOS 接收端地址，例如
   `http://192.168.1.9:8765/uploads/`。
3. 保存后点 **重新扫描**。
4. 如果页面显示 `接收端已有 ... 个记录`，且没有 `failed to connect`，说明 Android
   已经能访问 macOS 接收端。
5. 确认目标地址无误后，再点 **开始同步**。大媒体库会上传较多文件，测试前先确认
   接收目录磁盘空间充足。

### 6. 常用排查命令

查看 ADB 设备：

```bash
adb devices -l
```

确认 Android 应用进程：

```bash
adb shell pidof com.androidsync.app
```

查看 Android 应用日志：

```bash
adb logcat -s AndroidSync
```

确认 macOS 应用进程：

```bash
pgrep -fl AndroidSyncMac
```

确认接收端监听端口：

```bash
lsof -Pan -iTCP:8765 -sTCP:LISTEN
```

确认接收端 manifest 可读：

```bash
curl -fsS --max-time 2 http://127.0.0.1:8765/manifest.json
```

常见问题：

- `adb devices` 显示 `unauthorized`：解锁手机，重新允许 USB 调试。
- `adb devices` 显示 `offline`：重新插拔 USB，或重启 ADB server。
- Android 连接不上 Mac：确认两端在同一局域网，Mac 防火墙允许传入连接，目标 URL
  使用的是当前 Mac 局域网 IP，不是旧地址或 `127.0.0.1`。
- Android 扫描不到媒体：检查系统照片/视频权限，必要时在系统设置中重新授权。
- 无线 ADB 断开：确认无线调试仍开启，然后重新执行
  `adb connect <phone-ip>:<debug-port>`。

## 开发和代理上下文

- 贡献者和编码代理从 `AGENTS.md` 开始。
- 当前技术状态、架构、风险、路线图、决策和交接信息维护在 `PROJECT_MEMORY/`。
