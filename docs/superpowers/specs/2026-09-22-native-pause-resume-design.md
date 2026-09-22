# 原生 macOS 接收端与 Android 同步暂停/恢复设计

## 目标

Mac 点击暂停后，Android 同步任务进入暂停等待；当前正在传输的文件立即中断并从头重传，
Mac 恢复接收后 Android 自动继续原任务。暂停不得被当成普通上传失败，Android 的停止命令
在暂停等待期间仍须生效。

## 当前问题

- macOS 的暂停目前走完整 `stop/stopAndWait` 生命周期：关闭 `NWListener` 并取消活动连接，
  Android 的流式 PUT 因而得到 `Broken pipe`。
- Android 把普通上传异常记为 `FAILED` 并继续后续文件；它没有接收端暂停状态，也不能从
  该失败中恢复原任务。
- macOS 对暂停没有独立状态；工具栏和传输卡片不能一致地表达暂停/恢复。
- macOS 已将未完成 PUT 写入 `.incoming/*.part`，连接取消路径会清理临时文件；完整文件只在
  收到预期字节数后提交。该 staging 机制应继续作为中断重传的安全边界。

## 设计

### 1. macOS 接收状态与协议

- `ReceiverService` 保持 listener 在线，拥有 `running`、`pausing`、`paused` 三态；暂停/恢复
  不销毁并重建 listener，也不改变端口。
- 用户发起暂停时立即转为 `pausing`，单调递增本次服务生命周期内的 `pause_epoch`，取消正在
  接收请求体的 PUT，并清理对应 `.part`。清理后进入 `paused`。
- 暂停期间 `/`、`/health` 与只读 manifest 仍可用。`/health` 返回既有 `status`，并增加：

  ```json
  {
    "status": "ok",
    "receiver_state": "running | pausing | paused",
    "pause_epoch": 3
  }
  ```

- `pausing` 或 `paused` 时的新 PUT 在创建临时文件前以 HTTP 503 和稳定错误码
  `receiver_paused` 拒绝。恢复只把状态改回 `running`，保留当前 `pause_epoch`。
- `pausing` 期间 UI 显示过渡状态并禁用再次切换，待临时请求清理完进入 `paused` 后才允许恢复，
  避免快速暂停/恢复与旧连接清理交错。
- 若暂停到达时 PUT 请求体已完整接收、存储提交已经开始，则允许该提交完成并返回成功；Android
  在下一文件开始前检查状态，不会因此启动新 PUT。这样避免 Mac 已落盘而 Android 又重传成重复
  文件。请求体尚未完整时则丢弃并重传。
- 暂停中断产生独立的 `uploadInterrupted`/等效事件，而非普通失败事件；macOS 传输卡清除此文件
  的部分字节进度并展示暂停态。工具栏、菜单和传输卡片都从同一个接收状态派生按钮标题与可用性。

### 2. Android 暂停识别与重传

- 仅对能通过根端点识别为原生 Android Sync Receiver 的目标启用暂停控制；通用 WebDAV/HTTP
  目标保持现有行为。
- 对已识别的原生接收端，Android 在每个文件开始前读取 `/health`。若状态为 `pausing`/`paused`，
  不发 PUT，等待状态恢复为 `running`。
- 单次健康检查暂时不可用不构成“已暂停”的证据；不得据此自动重传。传输前仍按原流程发起 PUT，
  传输异常后也只有观察到暂停状态或 epoch 变化，才走暂停恢复路径。
- 若在 PUT 中遇到传输异常，Android 再读 `/health`。满足下列任一条件时，把异常分类为接收端暂停：
  当前状态为 `pausing`/`paused`，或 `pause_epoch` 与该文件开始上传前记录的值不同。后者覆盖
  Mac 在 Android 处理 `Broken pipe` 前已经恢复的竞态。
- 暂停导致的中断将当前任务从 `UPLOADING` 还原为 `WAITING`，不标记 `FAILED`、不计作完成，且
  不推进批次索引；等待接收端恢复后从头重传同一文件。多次暂停可以多次中断同一文件。
- 普通网络错误仍按现有规则标记 `FAILED` 并继续后续任务；不引入通用自动重试、字节级续传或
  修改其他错误策略。
- 暂停等待必须定期检查 Android 用户停止信号。用户停止后将 run 标记为 `STOPPED`，退出等待且
  不再重传；停止信号与接收端暂停信号分别处理。
- 暂停和等待状态应在 Android 前台通知/现有同步状态中可辨认；不要求新增持久化 run 状态，
  服务重启后可通过接收端状态预检重新进入等待。

### 3. 兼容性与决策范围

- 对缺少原生服务标识或不支持新字段的接收端，Android 不启用暂停自动恢复，沿用原有单次 PUT
  失败语义。
- Android 对暂停的专用重传是 ADR-008“每文件一次尝试”约束的窄范围例外：仅当本机原生接收端
  的 `pause_epoch` 证明该上传被用户暂停打断时，允许同一文件重新发送。普通错误仍一次尝试。
- 本设计不改变稳定 ID、manifest 去重、最终文件命名、持久化布局和一般性错误重试策略。

## 测试与验收

- macOS Core：健康检查状态/epoch、暂停时拒绝新 PUT、活动请求中断后 `.part` 清理、请求体完整
  后进入提交阶段的暂停竞态、恢复沿用端口。
- macOS AppModel/UI：running → pausing → paused → running 状态流；按钮标题随状态变化；中断文件
  不显示普通失败；暂停与完成后的卡片状态清理。
- Android：原生接收端识别、暂停前置等待、PUT 中断后 epoch 判定、恢复后同任务从头重传且不记
  失败、快速暂停/恢复竞态、普通网络错误仍标记失败、等待时停止退出、通用 WebDAV 不受影响。
- 运行 `./android/run_tests.sh`、`swift test --package-path macos`、`./android/build.sh`、
  `./macos/build_and_run.sh verify` 与 `git diff --check`。设备端暂停/恢复与停止仍需真机验收。

## 风险

- R-004/R-007：并发取消必须始终删除 `.part`，不得把短文件提交为有效媒体。
- R-009：暂停等待须服从前台服务生命周期，Android 停止必须可取消等待。
- R-015：仅在服务端确认 pause epoch 变化时重传；提交阶段完成的文件必须向 Android 返回成功，
  避免暂停制造重复文件。
- R-016：暂停中断事件必须终结 macOS 当前活动上传进度，但不能把被中断文件算作批次完成。

## 非目标

- 通用网络自动重试、断点续传、WorkManager、后台自启动或更改通用 WebDAV 语义。
- 暂停服务监听端口或关闭 `/health`；Mac 暂停期间需保留控制通道。
