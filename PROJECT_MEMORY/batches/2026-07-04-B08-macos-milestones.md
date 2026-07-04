# B08：macOS 里程碑补建（M2、M3）

日期：2026-07-04

## 目标

为路线图 Phase 2（macOS 接收端正确性）和 Phase 3（macOS UX 和应用测试）补建
里程碑文件，承接其进入/退出标准与验收证据，并把路线图与里程碑互链，消除
“阶段已实现但无里程碑承接退出标准”的结构缺口。

## 范围

- 新建 `milestones/M2_macos_receiver_correctness.md`：记录 Phase 2 的进入/退出标准、
  已通过的自动化证据（`8a09aa0`，75 个 macOS 测试）与未闭合项（B04 幂等删除测试
  执行、端到端联调）。
- 新建 `milestones/M3_macos_ux.md`：记录 Phase 3 的进入/退出标准、已通过的自动化
  证据与未完成的最终视觉/交互 QA。
- `03_REFACTOR_ROADMAP.md`：为 Phase 2、Phase 3 各补一行退出标准引用，与 Phase 1
  引用 M1 的格式一致。
- `00_PROJECT_STATUS.md` 与 `HANDOFF.md`：记录本批次。

## 非目标

- 不宣称 M2 或 M3 已完成；未完成的退出标准保持未勾选。
- 不修改应用源码、构建脚本或运行时行为。
- 不新增或关闭产品风险，也不改变受保护 ADR。
- 不改写 M1、既有批次或冻结记录的历史事实。

## 风险和决策

- 相关决策：ADR-007（批次治理式演进）。
- 相关风险（仅引用既有状态，不改变其结果）：R-004、R-005、R-006、R-007、R-008。
- 本批次只修改文档，不触及运行时行为。

## 不变量

- M2、M3 的证据仅引用 `00_PROJECT_STATUS.md` 已记录的可验证事实（目标提交、测试
  数量、构建/签名结果），不新增未经验证的结论。
- 未完成的设备/视觉 QA 与 B04 测试执行仍保持为未闭合退出标准。
- 既有风险状态、版本号、提交号与 ADR 语义保持不变。
- M1 与其他历史记录不被改写。

## 验证

```bash
git diff --check
ls PROJECT_MEMORY/milestones/M2_macos_receiver_correctness.md PROJECT_MEMORY/milestones/M3_macos_ux.md
rg -n "milestones/M2_macos_receiver_correctness.md|milestones/M3_macos_ux.md" PROJECT_MEMORY/03_REFACTOR_ROADMAP.md
```

`git diff --check` 通过。里程碑文件存在；路线图 Phase 2、Phase 3 均已引用对应里程碑。
未运行平台测试，因为本批次只修改 Markdown 文档。

## 回滚

删除新建的两个里程碑文件并回滚路线图与两份记录文档的引用即可。不影响应用源码、
构建产物或用户数据。

## 结果

- 提交：待本批次落盘后回填。
- 结果：Phase 2/Phase 3 均有里程碑文件承接退出标准，路线图与里程碑互链；此前评估
  中的结构缺口已闭合。
- 后续：M2 需要 B04 幂等删除测试在可执行 XCTest 的环境运行并补端到端联调证据；
  M3 需要完成 macOS 最终视觉/交互 QA。两项完成后按里程碑与 `00_PROJECT_STATUS.md`
  记录证据并勾选剩余退出标准。
