# B32：Android adaptive icon 与 `SYNC` 字标

日期：2026-08-10

## 目标

将 Android launcher 从传统 `drawable` 图标迁移为 adaptive icon，并使用严格可读的
模块化 `SYNC` 字标，避免启动器兼容缩放造成图标视觉尺寸偏小。

## 范围

- `android/AndroidManifest.xml` 的 launcher icon 资源声明。
- Android adaptive icon 的背景、前景矢量和颜色资源。
- `android/assets/sync-logo-1024.svg` standalone 品牌字标。
- Android README 中的 launcher icon 说明。

## 非目标

- 不改变应用内 UI、上传协议、媒体扫描、存储布局或版本号。
- 不依赖外部图像生成 API，不新增第三方依赖。

## 风险和决策

- 风险：无新增媒体、网络、并发或存储风险。
- 采用 Android API 26 原生 adaptive icon 资源，沿用 ADR-003 的现有 Android SDK
  工具链。

## 不变量

- 应用包名、启动 Activity、label 和 `minSdkVersion=26` 保持不变。
- Android 测试命令和 APK 输出路径保持不变。
- 图标文字固定为 `SYNC`，使用 cyan、coral red、warm yellow 和 deep charcoal，
  不含渐变、阴影、水印或额外文字。

## 验证

```bash
git diff --check
./android/run_tests.sh
./android/build.sh
"/Users/ios_k/Library/Android/sdk/build-tools/35.0.0/aapt2" dump badging android/build/AndroidSync-debug.apk
"/Users/ios_k/Library/Android/sdk/build-tools/35.0.0/aapt2" dump resources android/build/AndroidSync-debug.apk
```

2026-08-10：`git diff --check`、Android JVM 测试和 APK 构建通过；`aapt2 dump`
确认应用图标指向 `res/mipmap-anydpi-v26/ic_launcher.xml`，APK 同时包含
`ic_launcher_foreground.xml` 和 `ic_launcher_background`。

## 回滚

恢复 `AndroidManifest.xml` 对旧 `@drawable/ic_launcher` 的引用，并恢复删除的旧
`drawable/ic_launcher.xml`；移除 adaptive icon、颜色资源及本批次 README 说明。

## 结果

- 提交：随 B32–B35 一并提交为 `2690006`（`feat: harden Android sync and macOS receive flow`），
  2026-09-22 本地提交，未推送。
- 结果：已完成本地 adaptive icon 资源迁移和 `SYNC` 模块化矢量字标。
- 后续：安装到 Android 真机后检查不同 launcher 遮罩下的字标裁切和视觉尺寸。
