# Android Sync v0.1.0

首个可工作的 MVP 发布。

## 包含内容

- Android 调试 APK：`AndroidSync-v0.1.0-debug.apk`
- 通过 Android `MediaStore` 扫描手机媒体
- 同步队列，包含缩略图、打开项目、重试和扫描反馈
- 通过 HTTP/WebDAV 风格上传到本地接收端
- 接收端上传 manifest，用于 reconciliation
- 通过原始文件字节、接收端 mtime、`uploads.jsonl` 和 `.metadata.json` 保留元数据

## 安装

启动接收端：

```bash
./receiver/start.sh
```

在手机上安装 APK，然后把应用目标 URL 设置为接收端 URL：

```text
http://<computer-lan-ip>:8765/uploads/
```

## 验证

- `python3 -m unittest receiver.tests.test_receiver`
- `android/run_tests.sh`
- `android/build.sh`
- `apksigner verify android/build/AndroidSync-debug.apk`

## 已知限制

- APK 使用调试签名。
- 尚未实现后台自动同步。
- macOS 文件创建时间不会被重写；手机侧 created/taken/added/modified 元数据保留在
  sidecar JSON 和上传日志中。
