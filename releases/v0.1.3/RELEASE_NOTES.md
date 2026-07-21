# Android Sync v0.1.3

这是一次覆盖 Android 传输端和原生 macOS 接收端的大版本工作流更新。

## Android

- 重做深色媒体库首页、相册选择、同步前确认和传输卡片，可临时排除媒体并随时停止
  当前同步。
- 相册白名单会成为本次同步的明确范围；重新选择相册后，不再继续上传已经移出范围的
  历史队列任务。
- 支持扫描 macOS 应用显示的地址二维码，自动校验并保存 HTTP/HTTPS 接收地址。
- 大文件上传改用定长流式请求，避免 GB 级视频因请求体整体缓冲而触发 OOM。
- 缩略图加载、预览和大型队列渲染改为有界后台工作，降低滚动卡顿、ANR 和过期图片
  回写风险。
- 上传请求会携带设备名称、批次序号和总数，接收端可显示更完整的进度信息。

## macOS

- 原生 macOS 14+ 接收端和媒体库成为受支持的电脑端，提供深色界面、中文/英文切换、
  搜索、筛选、排序、Inspector、重命名和 Finder 定位。
- 新增接收地址二维码、暂停/开始接收、批次进度、传输速度、今日统计和媒体库容量概览。
- Quick Look 支持左右连续预览和 Delete 删除；主网格/列表支持方向键导航和自动滚动。
- 缩略图使用有界内存缓存并合并重复请求，改善连续键盘导航时的加载速度。
- 上传继续先写入 `.incoming/*.part`，完成尺寸校验后原子提交；取消、失败和对端断开会
  清理临时文件。
- 删除会保留 manifest tombstone，避免 Android 再次上传同一媒体。

## 发布产物

- `AndroidSync-v0.1.3-debug.apk`：使用项目调试密钥签名的 Android 测试版 APK。
- macOS 应用目前从源码运行：`./macos/build_and_run.sh`。本版本尚未提供 Developer ID
  签名和 notarization 的可分发 `.app`。

## 验证

- `./android/run_tests.sh`
- `./android/build.sh`
- `swift test --package-path macos`
- `./macos/build_and_run.sh verify`
- APK 签名、manifest 版本、macOS bundle 版本和 ad-hoc codesign 校验

## 已知限制

- 接收端没有认证，Android 允许明文 HTTP；只应在可信私有局域网内使用。
- Android 大型媒体库/GB 级视频的完整真机压力矩阵，以及 macOS 最终双语视觉/交互
  矩阵仍未全部闭合；已完成的自动化和局部真机/GUI 验证记录见 `PROJECT_MEMORY/`。
