# B15：macOS 上传进度事件与速度显示（UI 重设计批次 6/6）

日期：2026-07-07
分支：`codex/macos-ui-redesign`
提交：`ffbfacf`（上传进度事件与传输卡片速度显示）
依据：`docs/superpowers/plans/2026-07-07-macos-ui-redesign.md`（Task 10）

## 改动

- `ReceiverServiceEvent` 新增 `uploadProgress(id:bytesReceived:expectedSize:)`；
  `consumeBody` 写入后按 512 KB 步长节流发射，`remainingBytes == 0` 时保证
  末次发射。发射与既有 eventHandler 同连接队列同步调用，无新线程跳跃。
- `ActiveUpload` 新增 `bytesReceived`（默认 0，既有调用点不变）。
- `AppModel`：`transferProgress`（本轮无进度事件前为 nil，UI 退不确定条）、
  `TransferSample` + 纯静态 `transferSpeed(samples:)`（3 秒滑窗）、
  `burstSawProgress`/`burstBytesReceived` 于 `resetTransferCard()` 与驻留
  完成两处清零；`.uploadProgress` 分支带 missing-upload 与非正 delta 守卫，
  受既有 generation guard 保护。
- 新增本地化 key `speedFormat`（"%@/秒" / "%@/s"）。
- `TransferCardRow`：确定/不确定进度条切换 + 速度标签。

## 验证

- `swift test --package-path macos`：90 个测试全绿（新增
  `TransferProgressTests` 3 个）。
- `./macos/build_and_run.sh verify` 通过。
- opus 级审查确认三项并发风险（无 consumeBody 重入、fail 后无发射、
  单连接串行队列 + AsyncStream FIFO 保证单上传字节单调）。

## 已知限制（计划权衡，未修）

- 512 KB 节流 × 3 秒滑窗：传输速率低于约 170 KB/s 时相邻进度事件间隔
  超窗口，样本不足 2 个，速度标签不显示（进度条仍工作）。局域网主场景
  （MB/s 级）不受影响。
- 核心层节流无独立单测（`AndroidSyncCore` 无测试 target，计划预期）；
  真机大文件手工 QA 未执行，留分支终验。

## 风险

- 复核 `02_RISK_REGISTER.md` 并发/生命周期相关行：R-004、R-005、R-007
  不受影响（发射点位于既有写入路径内、同队列，无生命周期语义变化）。
  未新增风险 ID。

## 终审修复（提交 `9884b01`）

全分支终审发现跨 burst 进度/速度状态泄漏（与 B12 计数泄漏同类：驻留任务被
新 burst 取消时 `burstSawProgress`/`burstBytesReceived`/`transferSamples`
未清零，新 burst 显示确定 0% 条与陈旧速度）。已在 `.uploadStarted` 的
非 receiving 复位块统一清零四个 burst 字段，三处复位点语义一致；
`.uploadProgress` 改为先查 `delta > 0` 再落 `bytesReceived`；新增驻留反复
入场进度回归测试（RED 证据：`XCTAssertNil failed: "0.0"`）与多上传聚合
测试。修复后 92 个测试全绿，verify 通过，独立复审确认。

## 不变量

- 接收端 HTTP 协议、`.part` 暂存与尺寸校验、manifest 布局不变（事件为
  进程内新增枚举 case，非协议变更）。
- 上传失败/停止路径语义不变。
- 未新增第三方依赖。
