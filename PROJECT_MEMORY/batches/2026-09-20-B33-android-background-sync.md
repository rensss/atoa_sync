# B33：Android 后台可靠传输

日期：2026-09-20

## 目标

将 Android 同步从 Activity 持有的进程内上传循环改为可退后台运行、可任务级恢复的
`ForegroundService + SQLiteOpenHelper` 实现，同时保持现有单线程整文件 HTTP PUT 和
macOS 接收协议不变。

## 范围

- 新增可持久化 `SyncQueue`、`SyncTransferRunner`、`SyncRun` 和 SQLite 三表模型。
- 新增 `AndroidSyncApplication` 共享 database/queue 入口。
- 新增 `SyncForegroundService`、`dataSync` 声明、低优先级进度通知和显式应用内广播。
- Activity 只负责扫描、确认、展示和启动/停止 Service；活动 run 冻结任务 ID 顺序与目标 URL。
- Service 恢复前尽力查询远端 stable ID manifest，将已存在任务标记为 `DONE`，并把遗留
  `UPLOADING` 恢复为 `WAITING`。
- 更新 Android README、架构、风险、决策、状态、交接和 M1 记录。

## 非目标

- 不引入 Gradle、AndroidX、WorkManager、第三方依赖或开机自启。
- 不增加自动重试、通知操作按钮或单文件字节级断点续传。
- 不修改 macOS 接收协议、manifest 格式或接收端存储行为。
- 不自动提交或推送；当前批次实现保留在未提交工作树中。

## 风险和决策

- 相关风险：R-001、R-002、R-003、R-004、R-005、R-006、R-007、R-008、R-009、R-014、R-015。
- 相关决策：ADR-003、ADR-005、ADR-006、ADR-007、ADR-008。
- R-009 更新为“持久化队列已实现，等待完整真机恢复验证”；B33 的受控强制停止后重开
  已验证，但完整系统回收、长时间锁屏和厂商策略仍开放。
- R-014 记录前台服务仍可能受厂商电池策略或用户强制停止影响。
- R-015 记录 manifest 不可用时可能重复整文件上传的已接受限制。

## 不变量

- `minSdkVersion=26`、`targetSdkVersion=35`，继续使用直接 Android SDK 构建。
- 上传保持单线程、`ContentResolver` 流式读取和整文件 HTTP PUT。
- 每个文件在一次 run 中只尝试一次；普通失败标记 `FAILED` 后继续后续任务，手动重试
  才会创建新的 run。
- 用户停止只取消当前连接并把当前任务恢复为 `WAITING`，不把取消误记为 `FAILED`。
- 相册重扫和目标地址修改不改变已确认 run 的任务快照和目标 URL。
- 保留 B32 adaptive icon 及原有未相关文档变更。

## 验证

自动化：

```bash
./android/run_tests.sh
./android/build.sh
git diff --check
```

2026-09-20，在当前工作树执行 `./android/run_tests.sh` 和 `./android/build.sh` 均退出
0，生成 `android/build/AndroidSync-debug.apk`。测试脚本编译并运行
`SyncQueueTest`、`AlbumFilterTest`、`AddressConfigurationTest`、`SyncTransferRunnerTest`
和 `SyncRunTest`；构建使用 SDK 35 直接产出 APK。文档收尾后执行 `git diff --check`
通过。

真机：

- 设备：无线 ADB `10.10.3.28:41871`，型号 `22081212C`。
- 已安装并启动 `android/build/AndroidSync-debug.apk`。
- 界面真实媒体库约 1963 项；一次确认 run 快照包含 445 个待传任务。
- Home 后仍保持 `SyncForegroundService` 前台状态，`dataSync` 类型和 `sync_transfer`
  通知可见；通知进度从 `43/445` 增长到 `65/445`。
- `am force-stop` 后重新打开应用，Service 再次进入前台，通知从恢复后的 `86/445`
  继续增长，证明数据库 run 可由可见 Activity 恢复。
- 接收端连接失败时 UI 显示失败任务，通知/当前任务继续推进；后续任务保持执行，符合
  单个失败继续规则。
- 通过应用内停止链路使 Service 消失；当前连接被取消，后续未启动，未观察到取消被
  标记为失败的 UI 回归。
- 未完成：长时间锁屏、真实系统低内存回收、完整断网后手动重试和完整约 1963 项传输
  落盘核对；因此 M1 的真机压力退出项不关闭。

## 回滚

在未提交工作树中按本批次文件范围回退新增后台同步代码；不要回退或覆盖 B32 adaptive
icon、M2/M3 及其他既有本地变更。数据库版本为 1；若已在测试设备创建数据库，卸载
测试 APK 或清除应用数据后再验证旧版本，生产升级迁移需单独设计。

## 结果

- 提交：未提交；实现基线仍为 `17c7538`，遵循本批“不自动提交或推送”约束。
- 结果：Android 已具备任务级后台传输、SQLite run 快照、前台通知和重开恢复路径；
  不宣称系统永不杀进程，也不宣称字节级断点续传。
- 后续：完成锁屏/厂商策略/系统回收长时验证后，再决定是否关闭 M1 真机退出标准和
  R-009/R-014。
