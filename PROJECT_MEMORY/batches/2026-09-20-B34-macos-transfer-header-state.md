# B34：macOS 同步进度固定头部与完成态收起

日期：2026-09-20

## 目标

让 macOS 主窗口的同步进度在网格、列表、筛选和搜索之间保持同一个内容区顶部
header，并在接收完成后清除本轮进度状态，避免完成卡片继续显示陈旧内容。

## 范围

- `ContentView` 用 `safeAreaInset(edge: .top)` 承载唯一的 `TransferCardRow`，使其
  不属于网格或列表分支。
- `AppModel` 移除完成态 3 秒驻留；单文件或无批次头上传完成后立即回到 `idle`。
- 有 `batchIndex/batchTotal` 时，中间文件完成后保持 `receiving`，最后一个批次文件
  完成后才清空本轮计数、字节进度和速度样本。
- `TransferCardRow` 删除完成驻留卡和对应中英文文案，保留接收中进度卡、今日统计和
  失败短提示。
- 为完成态、跨批次连续接收和上一轮状态清理补充回归测试；更新 macOS README。

## 非目标

- 不修改 Android 上传协议、ReceiverService HTTP 端点、manifest、存储布局或媒体库
  数据。
- 不改变暂停/启动接收、失败提示、今日统计的既有数据口径。
- 不把本批次 GUI 视觉检查记录为已完成；自动化窗口环境未执行完整手工 QA。

## 风险和决策

- 相关风险：R-004、R-005、R-007 的接收端清理、生命周期和原子提交控制不受影响；
  未新增风险。
- 相关决策：ADR-003、ADR-007；不改变既有平台工具链或协议/存储边界。

## 不变量

- 上传事件仍在 `AppModel` 的 `MainActor` 状态机内按 generation 处理。
- 批次中间文件完成时进度卡不因 `activeUploads` 短暂为空而清除。
- 最后一个成功文件完成后，`transferCardState`、完成数、总数、字节进度和速度样本
  均回到空闲初始状态。
- Android、ReceiverService、`.part` 暂存、尺寸校验、manifest 和用户媒体不变。

## 验证

```bash
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

2026-09-20：完整 macOS 套件运行 114 个测试，0 failures；新增/调整的
`TransferCardStateTests` 与 `TransferProgressTests` 通过。`./macos/build_and_run.sh verify`
退出 0，应用成功构建、签名并启动。`git diff --check` 通过。

## 回滚

只回退本批次在 `macos/`、`macos/README.md` 和本批次记录中的改动；不要覆盖同一工作树
里 B32/B33 Android 资源、代码和项目记忆变更。回滚不需要迁移 SwiftData、删除用户媒体
或修改 `uploads.jsonl`。

## 结果

- 提交：随 B32–B35 一并提交为 `2690006`，2026-09-22 本地提交，未推送。
- 结果：同步进度统一固定在内容区顶部；接收完成后不再展示完成驻留卡，也不会沿用上一轮
  的完成数、总数、字节进度或速度。
- 后续：完成 macOS 全量 GUI/交互 QA 后，再更新 M3 退出标准；本批次不提前关闭该标准。
