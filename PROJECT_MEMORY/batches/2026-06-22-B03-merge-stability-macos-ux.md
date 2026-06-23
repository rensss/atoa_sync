# B03：合并稳定性和 macOS UX 候选实现

日期：2026-06-22

## 目标

把已批准的 `codex/stability-macos-ux` 候选分支合并到当前治理分支，再合并到
`main`，同时保留项目记忆和代理说明。

## 范围

- 将 `codex/stability-macos-ux` 合并到 `codex/agent-governance`。
- 将 `codex/agent-governance` 合并到 `main`。
- 保留候选分支从 `main` 分叉后新增的治理文件。
- 更新项目记忆，记录集成提交和剩余验证缺口。

## 非目标

- 不发布新版本，也不改变版本号。
- 不宣称 Android 真机压力测试或 macOS 视觉 QA 已完成。

## 风险和决策

- 风险：R-001、R-002、R-004、R-005。
- 未改变 `04_DECISION_LOG.md` 中的受保护决策。

## 验证

合并命令：

```bash
git merge --no-ff codex/stability-macos-ux
```

合并无冲突完成，并创建集成提交 `23b09d5`。集成提交使用以下命令验证：

```bash
git diff --check
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
```

全部通过。Swift 运行 75 个测试。Android 真机压力测试和 macOS 视觉/交互 QA 仍未完成。

`main` 合并也无冲突完成，并创建合并提交 `8a09aa0`。

## 回滚

如果 `main` 必须回到集成前基线，把主线合并提交 `8a09aa0` 作为整体回滚。

## 结果

- 提交：`8a09aa0`。
- 结果：候选实现已集成到 `main`；最终 `main` 合并前，集成内容的自动化检查已通过。
- 后续：完成 Android 真机压力测试和 macOS 视觉/交互 QA。
