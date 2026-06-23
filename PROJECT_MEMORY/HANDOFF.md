# 交接

最后更新：2026-06-23

## 从这里开始

主分支是 `main`，B04 实现提交为 `fee8063`。产品版本为 `0.1.2`。治理文档和已
批准的稳定性/macOS UX 实现已经合并到 `main`。

候选实现分支 `codex/stability-macos-ux` 位于 `cbf31db`。它包含完整的已批准
Android 稳定性和 macOS UX 工作，以及自动化回归覆盖。独立最终代码审查未发现
阻塞问题。该分支于 2026-06-22 合并到 `codex/agent-governance` 的 `23b09d5`，
随后合并到 `main` 的 `8a09aa0`。集成提交通过了 Android/macOS 自动化验证，但
仍需要 Android 真机压力测试和 macOS 最终视觉/交互 QA。

## 立即执行流程

```bash
git status --short --branch
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
```

以上自动化检查已于 2026-06-22 在集成提交 `23b09d5` 通过。仍需执行
`batches/2026-06-15-B02-stability-macos-ux-candidate.md` 中记录的设备和 GUI
检查。验收 Android 稳定性里程碑前，先复核风险 R-001 和 R-002。

## 最新本地工作

B05 中文文档和项目记忆治理已完成，提交为 `a24a442`：仓库级文档、平台 README、发布说明、历史计划/
设计文档和 `PROJECT_MEMORY/` 已统一整理为中文；冗余根目录 `CHANGELOG.md` 和
`CONTRIBUTING.md` 已移除；`AGENTS.md` 已明确 `PROJECT_MEMORY/` 文档结构和更新规则。
验证：`git diff --check` 通过；引用扫描确认活跃代理入口仍指向 `AGENTS.md`。未运行
平台测试，因为只改 Markdown 文档。

B04 macOS 幂等删除处理已在 `main` 的 `fee8063` 实现。`LibraryRepository.delete`
在活动记录的文件已经不存在时不再报告 `missingFile`，对已经删除的记录再次删除
也会成为 no-op。`LibraryRepositoryTests` 已添加回归测试。

B04 验证：`swift build --package-path macos` 于 2026-06-22 通过。以下命令构建
成功，但在当前自动化环境中启动 XCTest 时挂起：

```bash
swift test --package-path macos --filter LibraryRepositoryTests
```

直接运行 `xcrun xctest` 被 macOS 系统策略阻止，因为 SwiftPM 测试包未签名。

## 重要约束

- 不要把设计计划合并当作实现证明。
- 不要把接收端暴露到可信局域网之外。
- 保留 `.part` 上传暂存和尺寸校验。
- Android 队列锁内不得进行 I/O 或 bitmap 解码。
- 即使 Android 和 macOS 实现目前共享候选分支，也要把最终 Android 集成证据与
  macOS 验收证据分开记录。

## 完成后的文档

完成设备/GUI QA 后，更新 `00_PROJECT_STATUS.md`、本文件、相关风险行、适用
里程碑和批次记录，并写入证据。
