# 跨端同步任务进度、剩余时间与固定头部设计

## 目标

让 macOS 接收端展示当前整批实际传输任务的进度，而不是只展示当前资源的
剩余字节；在有足够速度样本后给出剩余时间估算；无论选择网格、列表、搜索、
其他文件或已删除分类，进度卡始终位于内容区顶部。

## 当前问题与根因

- macOS 当前能从 `Content-Length` 得到单个上传的总字节数，也能从
  `X-Android-Sync-Batch-Index/Total` 得到批次文件数量，但没有整批字节总量。
  因此当前“剩余”只能由 `activeUploadsRemainingBytes` 得到，不能代表整个任务，
  也无法准确计算 ETA。
- Android 的批次总数在跳过远端已存在任务后仍可能包含不可上传项。批次摘要应在
  manifest 过滤完成后，以实际待传任务为准。
- `TransferCardRow` 当前挂在 `LibraryView` 的 `safeAreaInset` 上。空分类使用
  `ContentUnavailableView`，其理想尺寸布局会把这组内容居中，导致进度卡在“其他
  文件”和“已删除”等空分类中出现在中间。

## 设计

### 1. Android 批次摘要

`SyncTransferRunner` 在开始上传前从 manifest 过滤后的 `WAITING`/`FAILED` 任务中
计算：

- `batchTotal`：本次实际待传文件数；
- `batchTotalBytes`：这些文件 `sizeBytes` 的饱和值求和。

每个上传请求继续发送现有批次索引和总数，并新增可选请求头：

```text
X-Android-Sync-Batch-Total-Bytes: <非负 Int64>
```

旧 Android uploader 重载没有整批字节参数时不发送该头；已知为零的批次总量仍发送 `0`。
不发送该头的旧 Android 客户端仍可被 macOS 接收；macOS 不会对缺少整批字节总量
的多文件批次显示伪造的整批剩余量或 ETA。

### 2. macOS 任务级剩余量与 ETA

协议层把 `batchTotalBytes` 从 `UploadMetadata` 传递到
`ReceiverServiceEvent.uploadStarted`、`ActiveUpload` 和 `AppModel`。

`AppModel` 在一个批次内维护：

- 整批总字节数；
- 已完成上传的字节数；
- 所有活动上传已接收的字节数；
- 现有三秒滑窗速度。

每个成功存储文件的实际大小都会累计到当前 burst 完成量，即使某个请求缺少可选批次总量头；
因此后续请求首次带来有效批次总量时也能扣除之前完成的文件。存储和失败事件都计入 terminal
计数，避免并发上传以乱序结束时漏清已经结束的 burst。任务剩余字节按下式计算，并始终钳制为不小于零：

```text
remaining = max(0, batchTotalBytes - completedBytes - activeReceivedBytes)
```

当剩余字节和正速度都可用时：

```text
etaSeconds = remaining / bytesPerSecond
```

没有速度样本时显示“计算中”，不显示旧资源的剩余量作为替代。无批次头的单文件
上传仍可使用当前文件剩余量，因为此时当前文件就是整个任务；无整批字节头的旧
多文件批次只保留数量进度，剩余字节与 ETA 显示为待计算。

进度文案统一为任务级信息，例如：

```text
同步进度 3/12 · 剩余 1.8 GB · 预计 2:10
```

### 3. 固定顶部布局

`ContentView` 在 detail 内容区使用单一的垂直容器：

```text
VStack(spacing: 0)
├── TransferCardRow        // 唯一、固定顶部
└── LibraryView             // 填满剩余空间
```

`TransferCardRow` 不再作为 `LibraryView` 的 `safeAreaInset`。`LibraryView` 设置
最大宽高填充并保持顶部对齐；空分类的 `ContentUnavailableView` 只在进度卡下面的
内容区域居中。进度卡空闲时保持零高度，不留下完成驻留内容。

## 错误处理与兼容性

- 非法、负数或溢出的批次字节头按缺失处理，不阻塞上传。
- 单个上传失败仍显示现有短暂失败提示；所有已观察到的批次上传均成功或失败后清理进度和 ETA 状态。
- Android 若在两个完整 PUT 请求之间取消/中断，当前 macOS 协议不会收到 run 结束事件，非末项进度卡可能
  保留到下一批开始或接收器停止。即时识别取消以及隔离多个并发批次需要可选 batch ID 与结束/取消事件；
  本设计暂不扩展该协议，记录为风险 R-016。
- 新增 HTTP 头为可选字段，不改变旧客户端和旧存储数据的读取方式。
- 本次不改变 ReceiverService 的上传提交、临时文件、manifest、存储路径或删除
  行为。

## 测试与验收

- Android：批次过滤后总数量/总字节计算、零任务、远端已存在任务和饱和求和测试。
- macOS Core：HTTP 头解析、路由元数据传递和非法值兼容测试。
- macOS AppModel：整批剩余字节、并发上传聚合、ETA 无速度/有速度、上一批清理、
  旧客户端回退测试。
- macOS UI：运行窗口中验证网格、列表、空的“其他文件”、空的“已删除”和搜索
  结果下进度卡都位于内容区顶部；完成后立即消失。
- 完成前运行 `./android/run_tests.sh`、`swift test --package-path macos`、
  `./macos/build_and_run.sh verify` 和 `git diff --check`。

## 非目标

- 不做断点续传、不改变任务重试策略、不引入第三方依赖。
- 不改变 Android 通知的既有进度口径；本设计只为 macOS 接收端补充精确的批次
  传输摘要。
