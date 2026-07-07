# B14：macOS Onboarding 与设置深色化（UI 重设计批次 5/6）

日期：2026-07-07
分支：`codex/macos-ui-redesign`
提交：`8d06185`（Onboarding 与设置深色化）
依据：`docs/superpowers/plans/2026-07-07-macos-ui-redesign.md`（Task 9）

## 改动

- `OnboardingView` 重做：渐变圆形图标、Theme 文本层级、accent 主按钮、
  `Theme.bg` 背景；`chooseDirectory()` 行为不变。
- `SettingsView`：根部 `.tint(Theme.accent)`；3 处 `.secondary` 前景色
  换 `Theme.textSecondary`；控件绑定不变。
- `MenuBarView` 不改（系统菜单不可主题化，计划明确豁免）。

## 验证

- `swift test --package-path macos`：87 个测试全绿。
- `./macos/build_and_run.sh verify` 通过。
- 审查通过，零缺陷发现。菜单深色显示的 GUI 手工核对留分支终验。

## 风险

- 未新增风险 ID。纯样式。

## 不变量

- 功能、绑定、导航不变；未新增第三方依赖。
