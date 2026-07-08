# B12：macOS 传输卡片行与状态机（UI 重设计批次 3/6）

日期：2026-07-07
分支：`codex/macos-ui-redesign`
提交：`d803856`（传输卡片状态机与今日统计）、`f845190`（跨 burst 完成计数
泄漏修复）、`1d5c4a0`（网格上方传输卡片行）
依据：`docs/superpowers/plans/2026-07-07-macos-ui-redesign.md`（Task 5–6）

## 改动

- `AppModel` 新增 `TransferCardState` 状态机（idle/receiving/completed(N)，
  完成后驻留 `transferCompletionLinger`（默认 3 秒）再回 idle）、
  `TodayStats` 今日统计、`activeUploadsExpectedBytes`；由
  `handle(_:generation:)` 上传事件驱动。
- 审查发现计划原文存在跨 burst 计数泄漏（驻留窗口内新 burst 继承旧
  completed 计数）：已修复（`.uploadStarted` 在非 receiving 态清零计数）并
  加反复入场回归测试，偏离计划原文、符合 spec"本轮完成数"语义。
- 新增 `Views/TransferCardRow.swift`：渐变进度卡 + 今日统计卡 + 完成驻留卡
  三态，空闲高度归零；`transientUploadMessage` 红色横幅在此重新获得展示位
  （B10 过渡态闭合）。接入 `ContentView` 网格上方。
- 新增 4 个本地化 key（receivingSummaryFormat/todayReceived/itemsCountFormat/
  completedLingerFormat），中英两表齐全。
- 新增共享测试 fixture `Tests/AndroidSyncMacTests/TestItems.swift`。

## 验证

- `swift test --package-path macos`：88 个测试全绿（新增
  `TransferCardStateTests` 3+1 个；`LocalizationTests` 红→绿）。
- `./macos/build_and_run.sh verify` 通过。
- 空闲态无占位的 GUI 手工核对未在自动化会话执行，留分支终验。

## 风险

- 未新增风险 ID。状态机为 MainActor 内存状态，不触及接收协议/存储。

## 不变量

- 接收端 HTTP 协议、`.part` 暂存与尺寸校验、manifest 布局不变。
- `handle(_:generation:)` 既有事件处理语义不变（仅追加状态机语句，
  `.uploadStored` 的库重载路径原样保留）。
- 未新增第三方依赖。
