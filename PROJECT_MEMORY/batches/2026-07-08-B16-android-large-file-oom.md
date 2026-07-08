# B16：Android 大文件上传 OOM 崩溃修复

日期：2026-07-08
分支：`main`
提交：待回填
依据：用户报告"安卓 app 传输大文件时崩溃"

## 根因

`HttpFileUploader.upload` 设置 `setDoOutput(true)` 但未设置任何流式模式。
`HttpURLConnection` 默认把整个请求体缓冲在内存中以计算 Content-Length，
电影级视频（GB 级）必然触发 `OutOfMemoryError`；上传线程只捕获
`IOException`（`MainActivity` 的两处 `OutOfMemoryError` 捕获在缩略图路径，
不覆盖上传），Error 逃逸导致进程崩溃。

## 修复

`item.sizeBytes() > 0` 时调用 `setFixedLengthStreamingMode(long)`
（minSdk 26，API 19+ 可用）：请求体直接流式写出，内存占用固定为 64 KB
缓冲；Content-Length 自动等于 `sizeBytes`，满足 macOS 接收端的
411（Length Required）检查。`sizeBytes` 不可用（≤0）的罕见条目保留
旧缓冲路径。上传方法签名与 HTTP 头不变。

## 验证

- `./android/run_tests.sh` 通过；`./android/build.sh` 生成
  `AndroidSync-debug.apk`。
- macOS 接收端对定长流式 PUT 的兼容性已在 2026-07-08 用 `curl -T`
  （100 MB、限速 2 MB/s）实测：接收、进度、入库全程正常。
- 真机大文件回归（GB 级视频不崩溃、内存平稳）未执行——无已连接设备；
  留待设备 QA，不得视为已验证。
- 现有 JVM 测试 harness 只编译 `core` 包，`HttpFileUploader` 依赖
  Android framework 无法纳入单测；如后续抽取纯逻辑再补测试。

## 风险

- 关联复核：R-001/R-002（Android 稳定性）——本修复缩小其中"大文件上传
  内存峰值"面；R-009（队列进程内状态）不受影响。未新增风险 ID。
- 行为变化边界：声明长度与实际流长不一致时（媒体在传输中被修改），
  定长模式会抛 `IOException`，表现为该文件上传失败并走既有失败路径，
  不再是静默截断/缓冲，属可接受收紧。

## 不变量

- 上传协议（PUT `/uploads/<name>`、X-Android-Sync-* 头）不变。
- `.part` 暂存与尺寸校验（接收端）不变。
- 队列锁内无 I/O 约束不受影响（改动在上传执行路径内部）。
