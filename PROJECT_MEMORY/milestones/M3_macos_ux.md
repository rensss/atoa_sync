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
      空格 Quick Look（已有局部 GUI 证据，完整矩阵仍未执行）。
- [ ] 未观察到布局、本地化或 Quick Look 交互回归。

## 证据

- 目标提交：`8a09aa0`（Phase 3 实现合并到 `main`）；前序候选 `cbf31db`、集成 `23b09d5`。
- 命令与结果：`swift test --package-path macos` 通过（75 个测试）；
  `swift build --package-path macos -c release` 通过；生成签名应用包版本 `0.1.2`、
  构建号 `35`，`codesign --verify --deep --strict` 通过。
- 人工验证：全量矩阵未完成；下列局部 GUI 证据不能替代最终视觉/交互 QA。
- 2026-07-20 B28 局部人工证据：真实窗口已确认重设计标题栏、状态/二维码菜单、单层
  日期/排序菜单与筛选往返，接收服务最终恢复运行；此证据不覆盖双语、Inspector、
  缩略图和 Quick Look 全量矩阵，因此退出标准仍未关闭。
- 2026-07-20 B27 局部人工证据：真实 Quick Look 窗口已确认空格打开/关闭及右方向键
  连续切换；完整 108 个 macOS 测试与应用 verify 通过。为避免破坏真实媒体，GUI
  Delete 未执行，主媒体库方向键仍建议用实体键盘冒烟，因此退出标准仍未关闭。

## 风险

- 无由本阶段引入的开放高危风险。
- R-001、R-002 属 Android 缩略图/队列稳定性，归 M1，不在本里程碑闭合范围。

## 回滚

把 UX 集成整体回滚到 `8a09aa0` 之前，退回 Phase 0 冻结基线。UX 改动不迁移持久数据，
回滚不删除用户媒体或 `uploads.jsonl`。
