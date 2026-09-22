# 架构

## 系统上下文

Android Sync 把 Android 设备上的媒体传输到原生 macOS 接收端，或传输到可信局域网
内兼容 HTTP/WebDAV 的目标。

```text
Android MediaStore
        |
        v
MediaStoreScanner -> MainActivity -> SyncDatabase / SyncQueue
                                      ^          |
                                      |          v
                              SyncForegroundService -> HttpFileUploader
                                      |          ^          |
                                      |          |          | HTTP PUT
                                      | RemoteManifestClient v
                                      +------ reconciliation macOS ReceiverService
                                         |
                                         v
                                  LibraryRepository
                                         |
                 +-----------------------+----------------------+
                 v                       v                      v
          media directories       metadata sidecars      uploads.jsonl
```

## Android 边界

Android 应用使用 Java 编写，不引入第三方依赖，通过本地 Android SDK 工具直接构建。

- `MainActivity`：UI 组合、导航、扫描、同步确认、Service 命令和异步缩略图展示；不拥有上传线程。
- `AddressConfiguration`：解析 macOS 地址二维码中的应用深链，并只接受带有效 host
  的 HTTP/HTTPS 上传目标。
- `MediaStoreScanner`：从 Android `MediaStore` 读取照片和视频。
- `SyncDatabase`：使用 `SQLiteOpenHelper` 持久化任务、同步 run 和 run-task 顺序；事务边界覆盖队列写入和 run 创建。
- `SyncQueue`：内存中的任务归属、状态转换、筛选、汇总和有界可见窗口，并通过可选 persistence 同步到 SQLite。
- `SyncForegroundService`：用户主动开始后的唯一上传生命周期所有者，持有单线程 runner、取消信号和进度通知；`START_STICKY` 恢复数据库中的 `RUNNING` run。
- `SyncTransferRunner`：不依赖 Android 生命周期的单线程任务状态机；按远端 manifest 过滤后
  的 `WAITING`/`FAILED` 任务快照计算本次上传文件数与字节总量（求和饱和到 `Long.MAX_VALUE`）；
  普通失败后继续后续任务。只有目标被识别为原生 macOS 接收端，且暂停状态/epoch 明确证明
  当前 PUT 因暂停中断时，才把当前任务恢复为 `WAITING`，等待后从文件开头重传；通用
  WebDAV/HTTP 和普通网络错误仍不自动重试。
- `RemoteManifestClient`：读取接收端历史并识别远端已经存储的媒体。
- `HttpFileUploader`：使用 HTTP `PUT` 和 Android Sync 元数据 header 流式上传媒体。

SQLite 是跨进程重建的持久任务状态来源，Application 在一个进程内创建唯一的
`SyncDatabase` 和 `SyncQueue`。UI 代码必须消费队列快照或有界窗口，不得创建第二套
可独立变更的任务模型。运行时遗留的 `UPLOADING` 任务在 Service 恢复前回到
`WAITING`；恢复会先按 stable ID 查询远端 manifest，再决定是否跳过任务。

相册白名单重新扫描后，`SyncQueue` 必须与最新扫描结果 reconcile：保留仍在范围内的
任务状态，移除已离开白名单的任务。一次上传运行只消费确认页捕获的 stable ID 快照，
不能重新遍历并上传历史队列的其他等待/失败任务。传输详情折叠时不创建逐文件 View，
展开窗口保持有界。

## macOS 边界

macOS 应用是面向 macOS 14+ 的 Swift 6 package，分为：

- `AndroidSyncCore`：协议解析、网络访问策略、上传模型、文件策略、存储、manifest
  历史和接收端。
- `AndroidSyncMac`：SwiftUI/SwiftData 应用状态、视图、设置、目录访问、Quick Look
  和菜单栏生命周期。

`ReceiverService` 拥有 `NWListener` 和串行接收队列，最多接受 4 个并发连接。每个
连接把请求字节流写入由 repository 管理的临时存储。

接收可用性由同一服务实例管理：`running`、`pausing`、`paused`。暂停不关闭 listener，
`GET /health` 始终可用并返回 `status`、`receiver_state` 和单调递增的 `pause_epoch`；根端点
以 `service: Android Sync Receiver` 标识受支持的原生协议。暂停期间的新 PUT 在创建临时文件前
以 HTTP 503 和 `error_code: receiver_paused` 拒绝。暂停会取消仍在接收请求体的上传并清理
`.part`；若请求体已完整接收且存储提交已开始，则允许提交完成并返回成功。Android 只在确认
此原生协议及暂停状态/epoch 后才等待并重传中断文件。

`LibraryRepository` 是 actor，也是持久媒体库变更的唯一所有者。它负责校验尺寸、
选择存储路径、原子移动已完成临时文件、写入 sidecar 元数据，并追加 manifest
历史。

Quick Look 一次持有当前筛选结果的文件 URL 快照和选中索引。左右方向键只更新系统
预览面板索引与 `AppModel.selectedIDs`，不重建面板；Delete 删除仍由 `AppModel`
转交 `LibraryRepository`，成功后才从预览数据源移除项目并选择相邻项。
主媒体库方向键由应用级单一 AppKit 本地事件监听器路由到 `AppModel`：网格上下按
当前可见列数跨行，列表逐项移动；搜索/重命名输入和 Quick Look key window 会跳过
该监听器。AppKit 方向键自带的 `.numericPad`/`.function` 属系统事件标志，不能当作
用户组合键拒绝；Command、Control、Option、Shift 组合继续交给原响应链。

缩略图继续由系统 `QLThumbnailGenerator` 生成，但通过进程级 `ThumbnailLoader`
统一请求。缓存键包含文件路径、显示尺寸和屏幕倍率；内存缓存同时受项目数和估算像素
成本约束，相同在途请求只生成一次。方向键选中项只执行最小距离的 `scrollTo`，避免
每次按键强制居中造成可见网格反复换页和解码任务抖动。

## 协议

受支持的原生接收端端点：

- `GET /`
- `GET /health`
- `GET /manifest.json`
- `PUT /uploads/<filename>`

上传 header 包含稳定 ID、尺寸、MIME 类型、可用的 Android 媒体时间戳，以及可选的
批次序号/批次总数（用于接收端进度显示）。新 Android 客户端另外发送可选的
`X-Android-Sync-Batch-Total-Bytes`，值为 manifest 过滤后的实际待上传任务大小之和；旧客户端
可以省略该 header。macOS 将合法的非负 `Int64` 保存到 `UploadMetadata` 并透传给接收事件；
缺失、负数、非法或溢出值按缺失处理，不拒绝上传。接收端按原始内容存储，不进行转码。

`AppModel` 在一次连续批次内用批次总字节减去已完成文件大小和所有活动上传的已接收字节，
得到整任务剩余量，并将结果限制为非负；ETA 仅在该剩余量可用且三秒速度滑窗给出正速度后
估算。旧单文件上传可回退到当前文件剩余量；旧多文件批次没有总字节 header 时不把当前文件
剩余量冒充整批数据。macOS 主窗口在 detail 外层只创建一个 `TransferCardRow` 顶部 header，
`LibraryView` 填满其下方区域，空分类只在下方区域居中。

地址配置不属于上传 HTTP 协议。macOS 用系统 Core Image 把
`androidsync://configure?url=<percent-encoded-upload-url>` 生成二维码；Android 系统
相机识别后通过 `VIEW`/`BROWSABLE` Intent 打开 `MainActivity`。Android 校验深链
scheme、host 和目标 URL 后写入现有 `target_url` 偏好。二维码不包含凭据，接收端端口、
上传端点和存储行为均不改变。

## 存储模型

```text
<selected-root>/
|-- .incoming/*.part
|-- photos/
|-- videos/
|-- files/
`-- uploads.jsonl
```

新上传按文件类型直接写入对应目录，不再创建 `YYYY-MM` 子目录。文件提交时的文件系统
创建时间和修改时间都按源时间设置，优先级为 `date_modified` → `date_taken` →
`date_added` → 接收时间；旧的按月目录不会自动搬迁，但 manifest 中记录的历史路径仍
保持可读。

Android 本地数据库包括 `sync_tasks`、`sync_runs` 和 `sync_run_tasks` 三张表。
`sync_runs` 冻结确认时的目标 URL，`sync_run_tasks` 冻结任务 ID 和选择顺序；重新扫描
相册或修改目标地址不改变活动 run 快照。每个已存储文件可拥有一个 `.metadata.json` sidecar。
`uploads.jsonl` 是追加式事件
历史，用于构建当前 manifest，包括删除 tombstone。macOS “清空已删除”只在应用侧
隐藏已删除 tombstone，不擦除 `uploads.jsonl` 历史，避免 Android 重新上传已删除媒体。

## 并发模型

- Android 扫描、缩略图解码和上传必须留在主线程之外。UI 更新再回到 Android 主线程；
  Activity 销毁不取消 Service 上传。
- `SyncQueue` 同步任务 map 访问。持有其 monitor 时绝不能执行长网络 I/O 或 bitmap
  解码；状态变更触发的短事务由 persistence 实现负责。
- macOS listener 和连接状态运行在一个串行 dispatch queue 上。
- macOS 存储变更通过 `LibraryRepository` actor 执行。
- SwiftUI 状态通过 `AppModel` 归属 main actor；接收端事件必须显式切换到 UI 状态。
- Android 停止同步通过 Service 取消信号和上传流内取消检查协作完成；当前请求断开后，
  被中断任务恢复为等待态，run 标记为 `STOPPED`，后续计划不再启动。普通单文件失败
  标记为 `FAILED` 后继续后续任务。
- 对已识别的原生 macOS 接收端，Android 暂停等待仍检查用户停止信号；停止会退出等待并
  标记 run 为 `STOPPED`。只有服务端暂停状态/epoch 证据才触发同文件整文件重传；普通错误
  和通用 WebDAV 保持原规则。
- macOS 接收端把对端取消视为上传终止：清理临时文件、关闭 session 并移除对应活动上传；
  用户暂停只取消尚未完整接收的 PUT，保留 listener/控制通道，等活动临时上传清理后再进入
  `paused`。已进入存储提交阶段的上传可完成。

## 所有权规则

- 平台代码留在所属平台目录。
- 核心网络和存储行为留在可测试的 `AndroidSyncCore`。
- SwiftUI 视图不直接变更文件，也不直接解析 HTTP。
- Android UI 代码不直接拥有持久接收端历史。
- 生成产物放在已忽略的构建目录或 `dist/`。
