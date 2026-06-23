# 平台目录布局设计

## 目标

让仓库根目录描述整个产品，同时把所有平台专属源码、构建配置、脚本和原型保留在
`android/` 或 `macos/` 内。

## 目标布局

```text
.
|-- android/
|   |-- prototype/
|   |-- src/
|   |-- tests/
|   |-- build.sh
|   `-- run_tests.sh
|-- macos/
|   |-- Package.swift
|   |-- Resources/
|   |-- Sources/
|   |-- Tests/
|   `-- build_and_run.sh
|-- releases/
|-- VERSION
`-- README.md
```

Android 浏览器原型从仓库根目录移动到 `android/prototype/`，包括本地图片资产和 QA
报告。

Swift package manifest 和打包脚本移动到 `macos/`。SwiftPM 路径改为相对该目录；
打包脚本继续写入仓库级 `dist/` 目录，以保持现有应用包输出位置不变。

## 接收端移除

删除独立 Python `receiver/` 实现。Android 或 macOS 应用不导入也不调用它，原生
macOS `ReceiverService` 提供受支持的电脑端接收器。

更新当前 Android 文档，引导用户使用 macOS 应用或通用 HTTP/WebDAV 接收端。历史
发布说明保持其记录的命令和能力，因为这些内容在对应版本中曾经有效。

## 仓库文档

增加根 README，标识两个平台目录并给出当前测试/构建命令。更新平台 README，让命令
可从仓库根目录运行，并清楚说明平台所有权。

## 验证

- 使用 `./android/run_tests.sh` 运行 Android 单元测试。
- 使用 `./android/build.sh` 构建并验证 Android 调试 APK。
- 使用 `swift test --package-path macos` 运行 macOS 测试。
- 使用 `swift build --package-path macos` 构建 macOS package。
- 检查活跃文件中没有过期的 `receiver/`、根 `Package.swift`、根原型或根构建脚本引用。
