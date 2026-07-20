# B24：地址二维码配置

日期：2026-07-14
分支：`main`
工作基线：`b0092d1`
提交：待提交

## 目标

macOS 接收端显示当前上传地址二维码；Android 用户用系统相机扫码并打开 Android Sync
后，应用直接校验、保存并显示新的接收地址。

## 范围

- macOS 使用 Core Image 生成二维码，在主窗口工具栏提供二维码 popover，并补齐中英
  文案与编码/渲染测试。
- Android 注册 `androidsync://configure` 的 `VIEW`/`BROWSABLE` Intent，解析二维码
  深链，只接受有效 HTTP/HTTPS 目标，然后复用现有 `target_url` 偏好。
- 更新双端 README、架构、风险、状态和交接文档。

## 非目标

- 不引入相机、二维码或网络第三方依赖；扫码识别由手机系统相机完成。
- 不改变上传 HTTP 端点、header、请求体、接收端监听策略或存储布局。
- 不增加认证、TLS、配对码或公网部署能力。
- 不包含工作区在本批开始前已经存在的同步停止、队列与传输卡相关未提交改动。

## 风险和决策

- R-003：二维码仍只展示现有明文局域网上传地址，不扩大接收端监听范围；可信局域网
  边界保持不变。
- R-012：自定义 scheme 可被其他来源调用；Android 固定 scheme/host、限制目标为
  HTTP/HTTPS 且要求有效 host，成功后以 Toast 和设置页明确反馈。
- ADR-003、ADR-006、ADR-007 保持不变；未增加构建系统或依赖。

## 不变量

- Android 继续使用本地 SDK 脚本且无第三方依赖；macOS 继续使用 SwiftPM/SwiftUI。
- 原上传 URL 手工编辑入口继续可用。
- 上传字节、定长流式模式、`.part` 暂存、尺寸校验、原子提交和 manifest 不变。
- 二维码不包含密钥、文件信息或用户媒体元数据。

## 验证

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

当前结果：

- `./android/run_tests.sh` 通过，新增 `AddressConfigurationTest passed`。
- 组合工作区最终 `swift test --package-path macos` 运行 101 个测试，全部通过；新增
  `AddressQRCodeTests` 4 个测试覆盖深链编码、目标校验和二维码图像生成。
- `./android/build.sh` 通过，生成并签名 `android/build/AndroidSync-debug.apk`。
- `./macos/build_and_run.sh verify` 通过，应用包完成构建和签名替换。
- APK 已安装到无线 ADB 设备 `22081212C`。用 ADB 发送与扫码等价的
  `VIEW`/`BROWSABLE` Intent：冷启动显示地址 `http://192.168.1.6:8765/uploads/`；
  前台实例收到 `onNewIntent` 后显示测试端口 8766，随后已恢复为 8765。两次均由
  `uiautomator` 界面层级确认。
- 尚未人工使用系统相机扫描屏幕上的真实二维码，因此相机识别/跳转保留为手工 QA。

## 回滚

移除 Android `AddressConfiguration`、对应 Intent filter/Activity 接入和测试；移除
macOS 二维码 helper、按钮、文案和测试。回滚不修改已经保存的 `target_url`，用户仍可
在设置中手工修改；不涉及媒体文件或 manifest 数据迁移。

## 结果

- 提交：待提交。
- 结果：代码、自动化、双端构建和 Android 深链设备联调已通过；真实相机扫码仍待
  手工 QA。
- 后续：在安装了新 APK 的 Android 真机上扫描实际 macOS 二维码，确认系统相机识别、
  应用冷启动/前台 `onNewIntent` 两条路径和地址可见反馈。
