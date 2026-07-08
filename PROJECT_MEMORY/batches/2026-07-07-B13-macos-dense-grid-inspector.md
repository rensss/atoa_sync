# B13：macOS 高密度网格与 Inspector 深色化（UI 重设计批次 4/6）

日期：2026-07-07
分支：`codex/macos-ui-redesign`
提交：`9f92e4a`（高密度深色网格与视频时长角标）、`aef49e6`（Inspector 与
重命名弹窗深色化）
依据：`docs/superpowers/plans/2026-07-07-macos-ui-redesign.md`（Task 7–8）

## 改动

- `ThumbnailMetrics` 枚举删除，尺寸常量并入 `Theme.Thumb`
  （gridCell 150、gridGap 3、listSize 56×42、inspectorSize 240×166）。
- 网格高密度化：150pt 方格、3pt 缝隙、去文件名标签（`.help` tooltip 替代）、
  选中琥珀描边 2pt；缩略图 `scaledToFill` + `Theme.bgRaised` 背景。
- 新增视频时长角标 `DurationBadge`（`AVURLAsset.load(.duration)`，
  仅 video 且非 removed；`m:ss` 格式）。
- 列表深色：选中 `Theme.accent.opacity(0.15)`、隐藏系统滚动背景。
- Inspector 与 RenameSheet 纯样式深色化（Theme token 化，按钮 `.bordered`，
  功能与 disabled 条件不变）。

## 验证

- `swift test --package-path macos`：87 个测试全绿（`ThumbnailMetricsTests`
  由 2 个改写为 1 个 `Theme.Thumb` token 断言，故总数 88→87）。
- `./macos/build_and_run.sh verify` 通过（两个任务各一次）。
- 两任务审查通过，无 Critical/Important 代码缺陷。

## 风险

- 未新增风险 ID。AVFoundation 为系统框架；时长读取按需异步、
  滚动重入会重取（与既有缩略图加载同模式），媒体解码风险面未扩大。

## 不变量

- 接收协议、存储布局、`AppModel` 行为不变（`formatDateOnly` 失去调用点
  成为死代码，留后续清理批次处理）。
- 双击预览、右键菜单、⌘ 多选、空格 Quick Look 交互不变。
- 未新增第三方依赖。
