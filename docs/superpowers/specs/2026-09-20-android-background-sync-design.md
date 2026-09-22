# Android 后台可靠传输设计

## 目标

Android 同步在用户主动开始后，使用前台服务继续执行，不依赖 `Activity` 存活；任务状态写入 SQLite，Activity 重建或进程重启后可以恢复未完成任务。

## 已确认的边界

- 使用原生 `ForegroundService`、`Notification` 和 `SQLiteOpenHelper`。
- 保持 Java 8、Android SDK 35、`minSdkVersion=26`、`targetSdkVersion=35`。
- 不引入 Gradle、AndroidX 或第三方依赖。
- 保持现有单线程、`ContentResolver` 流式读取和整文件 HTTP PUT。
- 不修改 macOS 接收协议，不实现单文件字节级断点续传。
- 用户每个文件只尝试一次；失败后继续后续文件，用户通过现有重试入口再次发起。
- 通知只显示进度，不增加暂停、继续或停止动作。
- 不增加开机自启。系统允许时使用 `START_STICKY` 恢复；用户强制停止应用后，等下次打开应用恢复。

## 架构

`AndroidSyncApplication` 创建共享的 `SyncDatabase` 与持久化 `SyncQueue`。`MainActivity` 只负责媒体扫描、确认页、状态展示和发送 Service 命令；`SyncForegroundService` 独占上传线程、取消信号、run 生命周期和前台通知。

一次同步由 `sync_runs` 记录目标 URL 和确认页选中的任务快照，由 `sync_run_tasks` 保存任务顺序。目标 URL 在 run 创建时冻结，避免同步期间修改设置影响活动任务。Service 恢复时先查询远端 manifest，按 stable ID 跳过已经收到的任务，再把遗留 `UPLOADING` 任务恢复为 `WAITING`。

## 数据模型与状态

`sync_tasks` 保存 stable ID、MediaStore URI、文件元数据、状态、尝试次数、错误和已发送字节。状态流转为：

```text
WAITING -> UPLOADING -> DONE
                    -> FAILED
UPLOADING --用户停止/服务异常--> WAITING
```

用户停止将 run 标记为 `STOPPED`；所有选中任务进入终态后 run 标记为 `FINISHED`。服务异常退出不主动写 `STOPPED`，让下一次服务启动恢复 `RUNNING` run。

## Android 生命周期

用户在可见 Activity 点击开始后启动 `SyncForegroundService`。Service 立即调用 `startForeground()`，使用低优先级常驻通知显示已完成数、总数和当前文件。Activity 通过显式应用内广播接收状态变化，离开前台时注销广播但不影响 Service。

Android 13+ 请求 `POST_NOTIFICATIONS`；即使通知权限被拒绝，也不阻塞用户主动发起的上传。Android 12+ 从可见 Activity 启动前台服务；Android 14+ 声明 `dataSync` 类型和 `FOREGROUND_SERVICE_DATA_SYNC` 权限。

## 已接受限制

- 系统或厂商电池策略仍可能终止前台服务。
- 进程在文件上传完成但客户端尚未收到响应时被杀，恢复依赖 manifest 查询；manifest 不可用时沿用现有整文件上传行为，理论上可能产生唯一文件名副本。
- 进程被用户强制停止后不自动重启。

## 验收

自动化覆盖队列 hydrate、持久化写入、run 快照、停止恢复和单次失败继续后续任务。真机覆盖 Home、锁屏、Activity 重建、进程回收、断网、手动重试和约 1963 个媒体任务。
