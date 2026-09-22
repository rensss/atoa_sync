# B36：跨端任务级剩余量、ETA 与固定顶部进度卡

日期：2026-09-22

## 目标

让原生 macOS 接收端展示本轮实际上传任务的剩余字节和可用的 ETA，并让唯一同步进度卡
始终固定在媒体库内容区顶部；保留旧 Android 客户端兼容和最后一项完成后立即清理卡片的行为。

## 范围

- Android `SyncTransferRunner` 在远端 manifest 过滤后的 `WAITING`/`FAILED` 任务快照上计算
  本轮文件数和字节总量，使用饱和加法，并经可选
  `X-Android-Sync-Batch-Total-Bytes` header 传递。
- macOS 协议模型和接收事件传递可选批次字节总量；负数、非法和溢出值按缺失处理。
- Android 兼容重载以负值哨兵表达“未知批次总量”并省略新 header；显式零总量仍发送 `0`，用 loopback
  HTTP 请求回归验证。
- `AppModel` 从批次总量扣除已存文件与活动上传接收量，计算非负任务剩余量；具备正速度样本时
  计算向上取整显示的 ETA；每个已存文件都累计实际记录字节，成功/失败都计入已观察到的终态，并在
  未结束 burst 后的新批次首项到达时重置；陈旧上传 ID 不改变进度。
- `ContentView` 在 detail 根部持有唯一 `TransferCardRow`；媒体库占据其下方空间。进度文案以
  任务级剩余字节与 ETA 取代单资源剩余量。
- 更新 Android/macOS README、架构说明、状态、交接和 M3 局部验收记录；新增设计与实施计划。

## 非目标

- 不改变 Android 通知的进度口径、任务重试/取消策略、接收端提交和 `.part` 清理逻辑。
- 不改变 manifest、存储路径、媒体元数据、删除行为，不增加第三方依赖。
- 不把本地局部 UI 探测描述为 Android 真机到 macOS 的成功端到端验收。

## 风险和决策

- 复核风险 R-004、R-007：上传失败清理和完整尺寸校验逻辑未改变；相关接收服务回归测试仍通过。
- 复核风险 R-009、R-015：新增统计基于 manifest 过滤后的本轮任务；恢复期 manifest 不可用的既有
  行为和控制措施未改变。
- 新增开放风险 R-016：跨两个完整 PUT 请求之间取消时 macOS 无法收到 run 结束通知，多个发送方批次
  交错时也缺少 batch ID 隔离。B36 避免下一个首项重用上一轮 burst，但不实现即时取消通知；该能力需要为
  原生接收端增加向后兼容的 batch ID/结束事件，不影响通用 WebDAV 目标。
- 未改变受保护决策，也未新增 ADR；R-004/R-007/R-009/R-015 不关闭。

## 不变量

- `batchTotal` 和 `batchTotalBytes` 只依据本次实际可上传任务；字节求和不溢出为负值。
- 新 HTTP header 可省略；macOS 对无效值容错，不拒绝上传。旧单文件可回退当前文件剩余量，旧多文件
  请求无整批字节总量时不把单文件数据伪报成任务数据。
- ETA 仅在任务剩余量可用且现有速度滑窗提供正速度时显示；否则本地化为“计算中”。
- 进度卡不嵌套在网格、列表、搜索或空状态分支中；单文件/批次最后一项结束后立即回到 idle。
- 本批不触碰接收媒体库中的既有文件或已删除条目。

## 验证

2026-09-22，工作树 `main`，`git rev-parse HEAD` 为
`2690006f17ab97b360507b65b130b7537afb0c18`。B36 未提交、未推送。

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

- `./android/run_tests.sh`：退出码 0；脚本报告 `AlbumFilterTest`、`AddressConfigurationTest`、
  `HttpFileUploaderTest` 通过；loopback 真实 HTTP 请求确认旧重载不发 header，显式零字节值发送 `0`。
- `./android/build.sh`：退出码 0，生成忽略的 `android/build/AndroidSync-debug.apk`。
- `swift test --package-path macos`：退出码 0，132 tests、0 failures；审查修复后的
  `TransferProgressTests|TransferCardStateTests` 定向 24 tests、0 failures。
- `./macos/build_and_run.sh verify`：退出码 0，AppModel 修复后的应用构建、签名并启动验证完成。
- `git diff --check`：退出码 0。
- 原生 macOS 窗口局部检查：有内容网格、列表、空“其他文件”、有内容“已删除”和非空搜索下，进度卡
  均位于内容区顶部。对 loopback 接收端使用唯一探测名发送不完整 PUT；观察到批次剩余字节与速度样本
  可用后的 ETA 更新，关闭请求后进度卡消失，仅留短暂失败提示。检查未提交媒体文件。
- 局部 UI 证据的限制：当时“已删除”分类有 1,984 项，未清空用户数据以制造空分类；空“已删除”未检查。
  没有 Android 真机参与，没有成功完整上传，也没有实测成功最后一项完成后的卡片收起。上述真实端到端
  和成功完成状态仍待验收，M3 退出标准保持开放。
- 独立只读审查第一轮发现：未知字节总量重载误发 `0`、缺头请求的完成量未累计、乱序失败不清卡。
  B36 已分别补 loopback HTTP/状态回归测试并修正；修复后的完整 Android/macOS 自动化与 app verify 均通过。
- 独立只读复审未发现 Critical/Important；确认两个 PUT 之间取消/并发批次隔离属于需扩展协议的 R-016，
  并指出 loopback 测试监听地址可能是 IPv6 而客户端固定连接 IPv4。测试现已显式绑定 `127.0.0.1`，
  修复后 `./android/run_tests.sh` 再次通过。
- 取消/并发批次隔离建议需要新的跨端 batch ID 与结束/取消事件。B36 不静默增加此协议扩展，按范围保留为
  R-016；M3 的全量 UI 与成功端到端验收继续开放。
- 最终范围核对：变更只涉及本批 Android/macOS 实现、测试和说明，以及将 B32–B35 状态更正为
  已在 `2690006` 提交的项目记忆；无暂存文件、无生成物或密钥文件进入变更。

## 回滚

本批独立提交为 `6ca48f63fe14a97fe157d35793fa7506edb4c1b3`。若需回滚，只撤销该提交中 B36 的
Android runner/header、macOS 协议/AppModel/视图/测试和文档改动，不回退基线提交 `2690006`；可选 HTTP
header 删除后，旧客户端接收行为仍兼容。验证未在媒体库中留下探测文件，回滚不需要迁移或删除用户媒体。

## 结果

- 提交：`6ca48f63fe14a97fe157d35793fa7506edb4c1b3`（`feat: show cross-platform task progress`），基线为 `2690006f17ab97b360507b65b130b7537afb0c18`；本地提交，未推送。
- 结果：主体实现完成；两轮审查发现的问题均已修正或明确记入 R-016。Android/macOS 全量测试、Android build、macOS app verify 和 diff check 均通过。以上命令在提交前的 B36 工作树快照执行，随后用户要求将其作为先行本地提交；当前提交事实经 `git rev-parse` 核实。
- 后续：由用户在 Android 真机完成成功批次传输验收；M3 GUI/交互退出标准保持开放。
