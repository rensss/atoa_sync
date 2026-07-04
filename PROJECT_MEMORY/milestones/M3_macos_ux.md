# M3：macOS UX 和应用测试

状态：进行中（实现已合并到 `main`，自动化测试已通过；最终视觉/交互 QA 未完成，
为退出阻塞项）

对应路线图阶段：Phase 3（macOS UX 和应用测试）。

## 进入标准

- [x] macOS UX 设计与实施计划存在（`docs/superpowers/`）。
- [x] `AndroidSyncMacTests` target 已建立。
- [x] macOS 测试与构建命令已记录。

## 退出标准

- [x] 采用原生工具栏结构与稳定缩略图布局。
- [x] 运行时中英文本地化已实现（默认中文）。
- [x] 搜索、排序、Inspector、Quick Look 与设置行为已实现。
- [x] `AndroidSyncMacTests` 覆盖应用状态与本地化逻辑。
- [x] `swift test --package-path macos` 在目标提交通过（75 个测试）。
- [ ] 最终视觉/交互 QA 覆盖工具栏位置、本地化菜单、Inspector/搜索布局、缩略图与
      空格 Quick Look（当前自动化会话无法捕获 macOS 显示画面）。
- [ ] 未观察到布局、本地化或 Quick Look 交互回归。

## 证据

- 目标提交：`8a09aa0`（Phase 3 实现合并到 `main`）；前序候选 `cbf31db`、集成 `23b09d5`。
- 命令与结果：`swift test --package-path macos` 通过（75 个测试）；
  `swift build --package-path macos -c release` 通过；生成签名应用包版本 `0.1.2`、
  构建号 `35`，`codesign --verify --deep --strict` 通过。
- 人工验证：未完成。当前自动化会话无法捕获 macOS 显示画面进行最终视觉/交互 QA。

## 风险

- 无由本阶段引入的开放高危风险。
- R-001、R-002 属 Android 缩略图/队列稳定性，归 M1，不在本里程碑闭合范围。

## 回滚

把 UX 集成整体回滚到 `8a09aa0` 之前，退回 Phase 0 冻结基线。UX 改动不迁移持久数据，
回滚不删除用户媒体或 `uploads.jsonl`。
