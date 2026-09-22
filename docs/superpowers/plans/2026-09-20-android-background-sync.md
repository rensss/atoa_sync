# Android 后台可靠传输 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** 将 Android 同步改为可后台运行、可进程重启恢复的可靠传输。

**Architecture:** 使用原生 `ForegroundService + SQLiteOpenHelper`。Activity 只负责扫描、确认和展示；Service 独占上传生命周期；SQLite 保存任务和同步 run。保持现有单线程、整文件 HTTP PUT 和 Mac 协议不变。

**Tech Stack:** Java 8、Android SDK 35、原生 `Service`、`Notification`、`SQLiteOpenHelper`；不引入 Gradle、AndroidX 或第三方依赖。

**Spec:** `docs/superpowers/specs/2026-09-20-android-background-sync-design.md`

## Global Constraints

- `minSdkVersion=26`、`targetSdkVersion=35`。
- 只支持用户主动开始的同步，不增加开机自启。
- 通知只显示进度，不增加暂停、继续或停止操作。
- 单个文件只尝试一次；失败后继续后续文件，由用户手动重试。
- 本批不实现单文件字节级断点续传，不修改 macOS 接收协议。
- 保留当前 B32 adaptive icon 和未提交文档变更，不覆盖或混入无关修改。
- 不自动提交或推送，除非用户后续明确要求。

## Review Focus

- Activity 销毁或重建时，Service 继续上传。
- 系统回收进程后，`UPLOADING` 任务恢复为 `WAITING`，不丢任务。
- 用户停止时只取消当前连接，任务不会错误标记为失败。
- 单个文件失败后，后续文件仍继续上传。
- 重新扫描相册或修改目标地址时，不影响已经确认的 run 快照。
- 服务恢复前通过 stable ID 查询远端 manifest，降低重复文件风险。

### Task 0: 写入设计规格

- 将已确认的架构、数据模型、状态流转、通知行为和限制写入 spec。
- 自检 spec，确认没有 WorkManager、自动重试、开机自启或字节级续传。

### Task 1: 抽离可持久化的核心队列和传输 runner

**Files:**

- Create: `android/src/main/java/com/androidsync/app/core/SyncQueuePersistence.java`
- Create: `android/src/main/java/com/androidsync/app/core/SyncTransferRunner.java`
- Modify: `android/src/main/java/com/androidsync/app/core/SyncQueue.java`
- Modify: `android/src/main/java/com/androidsync/app/core/SyncTask.java`
- Test: `android/tests/SyncQueueTest.java`
- Test: `android/tests/SyncTransferRunnerTest.java`

**Interfaces:**

- `SyncQueuePersistence.load() -> List<SyncTask>`
- `SyncQueuePersistence.save(SyncTask task)`
- `SyncQueuePersistence.replaceAll(List<SyncTask> tasks)`
- `SyncTask.restore(...)`
- `SyncTransferRunner.run(...)` 接收任务 ID 顺序、目标 URL、可注入 uploader、取消信号和状态监听器。

**Steps:**

- 先添加失败测试：队列 hydrate 后保留状态、状态变化调用 persistence、取消时当前任务回到 `WAITING`、单个失败后继续后续任务。
- 运行 `./android/run_tests.sh` 确认测试按预期失败。
- 为 `SyncQueue` 增加可选 persistence，保留无参构造。
- 为 `SyncTask` 增加持久化恢复工厂。
- 将 `MainActivity` 上传循环抽成纯 Java `SyncTransferRunner`。
- 保持 `WAITING -> UPLOADING -> DONE/FAILED`、取消回 `WAITING`、失败继续后续任务。
- 运行 `./android/run_tests.sh`。

### Task 2: 建立 SQLite 数据库和进程级共享入口

**Files:**

- Create: `android/src/main/java/com/androidsync/app/android/SyncDatabase.java`
- Create: `android/src/main/java/com/androidsync/app/AndroidSyncApplication.java`
- Create: `android/src/main/java/com/androidsync/app/core/SyncRun.java`
- Create: `android/src/main/java/com/androidsync/app/core/SyncRunStatus.java`
- Modify: `android/AndroidManifest.xml`

**Schema:** `sync_tasks` 保存媒体和任务状态；`sync_runs` 保存 run、目标 URL、状态和时间；`sync_run_tasks` 保存 run-task 关联和选择顺序。

**Steps:**

- 使用版本 1 SQLite schema，开启外键约束。
- 队列写入、run 创建和关联使用事务。
- 提供 `createRun`、`findRunningRun`、`taskIdsForRun`、`markRunStopped`、`markRunFinished`。
- Application 创建唯一 database 和共享 `SyncQueue`。
- 执行 `./android/build.sh`。

### Task 3: 实现 `SyncForegroundService` 和进度通知

**Files:**

- Create: `android/src/main/java/com/androidsync/app/SyncForegroundService.java`
- Create: `android/src/main/res/drawable/ic_stat_sync.xml`
- Modify: `android/AndroidManifest.xml`

**Steps:**

- 声明 `FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_DATA_SYNC`、`POST_NOTIFICATIONS`。
- 注册 `dataSync` 类型的非 exported Service。
- 创建低优先级 `sync_transfer` 通知渠道并立即调用 `startForeground()`。
- 实现 `ACTION_START + EXTRA_RUN_ID`、`ACTION_STOP`、`ACTION_STATE_CHANGED`。
- `START` 幂等；无参数启动时恢复数据库中的 `RUNNING` run。
- 返回 `START_STICKY`，不增加 `BOOT_COMPLETED`。
- 恢复前查询远端 manifest，遗留 `UPLOADING` 改回 `WAITING`。
- 用户停止时关闭当前连接、保留任务为 `WAITING`、标记 run 为 `STOPPED`。
- 全部任务完成后标记 `FINISHED` 并移除前台服务。

### Task 4: 改造 Activity 与现有 UI

**Files:**

- Modify: `android/src/main/java/com/androidsync/app/MainActivity.java`
- Modify: `android/README.md`

**Steps:**

- 删除 Activity 的上传循环、`HttpFileUploader` 和 `SyncRunGate`；保留扫描线程池。
- `startSync()` 创建 run 并从可见 Activity 启动 Service。
- `stopSync()` 发送 `ACTION_STOP`。
- `onDestroy()` 不再取消后台同步。
- `onStart/onStop` 注册和注销显式应用内进度广播。
- Activity 重建时从共享队列刷新，并确保 `RUNNING` run 的 Service 启动。
- 活跃 run 期间不执行会删除活动任务的 reconcile。
- Android 13+ 首次开始同步前请求通知权限，拒绝不阻塞上传。
- README 记录后台、恢复、失败重试和系统限制。
- 执行 `./android/run_tests.sh` 和 `./android/build.sh`。

### Task 5: 文档、风险和真机验收

**Files:**

- Create: `PROJECT_MEMORY/batches/2026-09-20-B33-android-background-sync.md`
- Modify: `PROJECT_MEMORY/02_RISK_REGISTER.md`
- Modify: `PROJECT_MEMORY/00_PROJECT_STATUS.md`
- Modify: `PROJECT_MEMORY/HANDOFF.md`
- Modify: `PROJECT_MEMORY/milestones/M1_android_stability.md`

**Steps:**

- 记录实现范围、测试输出和真机证据。
- 更新 R-009，新增厂商电池策略和 manifest 不可用导致重复整传风险。
- 只有取得真实证据后更新 M1 状态。
- 真机验证 Home、锁屏、Activity 重建、进程回收、断网、手动重试、停止和约 1963 项大队列。
