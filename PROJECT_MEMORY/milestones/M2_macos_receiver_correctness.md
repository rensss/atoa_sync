# M2：macOS 接收端正确性

状态：进行中（实现已合并到 `main`，自动化回归已满足；等待端到端真机→Mac 联调确认，
后者并入 M3 的 QA）

对应路线图阶段：Phase 2（macOS 接收端正确性）。

## 进入标准

- [x] 原生 macOS `ReceiverService` 是受支持接收端（ADR-002）。
- [x] 相关风险 R-004、R-005、R-006、R-007 已登记。
- [x] macOS 测试与构建命令已记录。

## 退出标准

- [x] 区分 listener 生命周期失败与单次上传失败（R-005）。
- [x] 中断和失败路径清理 `.incoming/*.part` 临时文件（R-004）。
- [x] 保留原子提交、sidecar 元数据、唯一目标命名与 tombstone（R-006、R-007、ADR-004、ADR-005）。
- [x] 接收端生命周期与中断上传具备回归覆盖。
- [x] `swift test --package-path macos` 在当前 HEAD 通过（113 个测试）。
- [x] B04 幂等删除回归测试在当前可执行 XCTest 环境实际运行通过。
- [ ] 端到端接收端行为在真机→Mac 联调下确认（并入 M3 QA）。

## 证据

- 目标提交：`8a09aa0`（Phase 2 实现合并到 `main`）；当前复核 HEAD 为 `17c7538`；前序
  候选 `cbf31db`、集成 `23b09d5`。
- 命令与结果：`swift test --package-path macos` 于 2026-06-15（`cbf31db`）与 2026-06-22
  （`23b09d5`）通过，运行 75 个测试。
- 2026-08-10，`swift test --package-path macos` 在 `17c7538` 运行 113 个测试并全部
  通过，其中包含 B04 的幂等删除回归；`./macos/build_and_run.sh verify`、plist 和
  ad-hoc codesign 校验也通过。端到端真机→Mac 联调仍未完成。

## 风险

- R-004（High，已在 `8a09aa0` 缓解；闭合需端到端清理证据）。
- R-005（Medium，已在 `8a09aa0` 缓解）。
- R-006、R-007（Medium，已缓解，保留其测试）。
- R-008（Medium，开放；manifest 增长/compaction，与删除/tombstone 相关）。

## 回滚

把接收端正确性相关集成整体回滚到 `8a09aa0` 之前，退回 Phase 0 冻结基线的接收端
行为。`uploads.jsonl` 与媒体目录为追加/落地数据，回滚不删除用户数据。
