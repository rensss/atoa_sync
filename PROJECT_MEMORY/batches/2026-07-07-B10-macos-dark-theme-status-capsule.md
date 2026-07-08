# B10：macOS 深色主题 token 与状态胶囊（UI 重设计批次 1/6）

日期：2026-07-07
分支：`codex/macos-ui-redesign`（基于 `main` 的 `2c9a3cb`）
提交：`83205c2`（Theme token 与强制深色）、`a3acab4`（状态胶囊文案下沉）、
`e6a0f18`（工具栏状态胶囊替代顶部状态条）
依据：`docs/superpowers/specs/2026-07-07-macos-ui-redesign-design.md` 与
`docs/superpowers/plans/2026-07-07-macos-ui-redesign.md`（Task 1–3）

## 改动

- 新增 `Support/Theme.swift`：深色工作台色板、间距、圆角 token；
  App 三个 Scene（WindowGroup、MenuBarExtra、Settings）强制
  `.preferredColorScheme(.dark)`。
- `AppModel` 新增 `statusCapsuleTitle` / `statusCapsuleDetail` 计算属性
  （原 `ReceiverStatusView` 私有文案逻辑下沉，可测试）。
- 新增 `Views/StatusCapsuleView.swift` 挂入 `LibraryToolbar`
  （`ToolbarItem(placement: .status)`）：状态圆点 + 文案 + 菜单
  （暂停/启动、复制地址、端口/URL 详情）。
- `ContentView` 移除顶部状态条；删除 `Views/ReceiverStatusView.swift`。

## 验证

- `swift test --package-path macos`：83 个测试全绿
  （78 基线 + 2 `ThemeTests` + 3 `AppModelStatusCapsuleTests`），
  每个任务提交前各运行一次。
- `./macos/build_and_run.sh verify`：每个任务提交前通过。
- 每任务经独立 subagent 代码审查（spec 符合性 + 质量），无未闭合
  Critical/Important 代码缺陷。

## 未完成 / 过渡态

- 五种 `ReceiverStatus` 的胶囊显示手工 GUI 核对未在自动化会话执行，
  留待分支终验（与 M3 视觉 QA 同口径）。
- `transientUploadMessage` 自本批次起暂无展示位（计划明文过渡态），
  由批次 3（TransferCardRow 横幅）承接；两批次须同一发布列车。

## 风险

- 未新增风险 ID。未触及接收协议、存储、并发模型；R-011 不受影响。

## 不变量

- 接收端 HTTP 协议、`.part` 暂存与尺寸校验、manifest 布局不变。
- `AppModel` 既有公开行为不变（仅新增计算属性与视图层重组）。
- 平台目录边界不变；未新增第三方依赖。
