# B25：同步范围、交互与双端停止控制

日期：2026-07-14
分支：`main`
工作基线：`b0092d1`
提交：待提交

## 目标

修复真机 QA 发现的四类问题：同步期间 Android 页面卡顿、上传错误提示不消失、重选
相册后仍上传旧队列媒体，以及 Android/macOS 主界面缺少可见且有效的停止入口。

## 范围

- Android `SyncQueue` 用最新白名单扫描结果 reconcile 队列，删除已移出白名单的旧任务，
  并让一次同步只消费确认页明确选中的 stable ID。
- Android 上传循环支持合作式取消；停止后关闭当前 `HttpURLConnection`，把被中断任务
  恢复为等待态，不继续后续任务。
- Android 传输卡新增停止按钮；折叠时不再为全部未完成任务创建行，展开列表限制为
  40 项；失败提示 5 秒后自动收起，并在新同步或修改地址时清除。
- macOS 主窗口工具栏和接收进度卡新增“暂停接收”入口，复用既有串行接收器生命周期。
- macOS `ReceiverConnection` 处理对端 `.cancelled`，清理 `.part` 并发送单次
  `uploadFailed`，避免 Android 停止后活动上传残留在 UI。

## 非目标

- 不改变上传端点、header、Content-Length、文件命名、存储布局或 manifest 语义。
- 不增加跨进程队列持久化、后台服务、认证或 TLS。
- 不把本批真机冒烟验证等同于 GB 级视频和大型媒体库压力测试完成。
- 不包含同一工作区并行存在的 B24 地址二维码配置实现。

## 风险和决策

- R-001/R-002：同步卡不再在每次进度变化时重建全部未完成任务行；展开行保持有界，
  真机大型媒体库压力退出标准仍开放。
- R-003：停止控制和队列范围修复不改变可信局域网边界。
- R-004/R-007：Android 取消会断开当前请求；macOS 对端取消路径清理 `.part`，尺寸校验
  与原子提交保持不变。
- R-009：停止后的等待任务仍只存在进程内；本批不声明可恢复同步。
- ADR-003、ADR-004、ADR-005、ADR-006、ADR-007 保持不变。

## 不变量

- Android 仍使用本地 SDK 脚本、单工作线程上传且无第三方依赖。
- 队列 monitor 内不执行网络 I/O、文件读取或 bitmap 解码。
- 已完成任务状态在同一相册范围内 reconcile 时保留；移出白名单的任务不进入下一轮。
- macOS 接收端暂停仍通过 `ReceiverService.stop/stopAndWait` 串行完成。
- 中断上传不能产生最终媒体文件、manifest stored 记录或残留 `.part`。

## 验证

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
adb install -r android/build/AndroidSync-debug.apk
adb shell am start -n com.androidsync.app/.MainActivity
curl -fsS http://127.0.0.1:8765/health
git diff --check
```

当前结果：

- Android JVM 测试和 APK 构建通过；新增队列 reconcile 与有界 active window 回归。
- 组合工作区 `swift test --package-path macos` 运行 101 个测试并全部通过；定向
  `ReceiverServiceTests` 运行 11 个测试并全部通过，新增对端取消清理回归。
- 修复 APK 已安装到无线 ADB 设备 `22081212C`。真机确认页只显示当前白名单相册
  `WeiXin` 的 244 个待传项目；同步卡显示停止按钮。
- 真机点击停止后无活跃 TCP 上传连接，后段媒体保持“未同步”；重启新 macOS 构建后
  主窗口工具栏显示“暂停接收”，停止后状态回到“可以接收文件”且无活动项。
- 受控联调期间有 6 个已开始的小文件完成落盘；未删除用户媒体或 manifest 记录。
- `./macos/build_and_run.sh verify`、最终 APK 安装/启动、`/health` 和
  `git diff --check` 均通过。
- 并行 B24 深链测试曾把手机目标恢复到旧地址；最终已通过前台 deep link 更正并从
  设置页确认 `http://192.168.1.23:8765/uploads/`。

## 回滚

回滚 Android `MainActivity`、`HttpFileUploader`、`SyncQueue`、`TransferCardView` 与队列
测试；回滚 macOS `ReceiverService`、两个主窗口 View 和接收器测试。回滚不删除已经
完成的媒体或 manifest；被停止且仍为等待态的 Android 任务会随进程内队列消失。

## 结果

- 提交：待提交。
- 结果：代码、组合全套自动化、应用构建和双端真机停止链路已验证。
- 后续：执行大型媒体库持续滚动、GB 级视频中途停止和重复开始/停止压力测试。
