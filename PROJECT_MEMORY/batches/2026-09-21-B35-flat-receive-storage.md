# B35：macOS 接收目录平铺与源时间戳

日期：2026-09-21

## 目标

让 macOS 新接收文件直接平铺在 `photos/`、`videos/`、`files/` 下，并保留源文件时间
信息，不把文件系统创建时间默认留为传输完成时间。

## 范围

- `macos/Sources/AndroidSyncCore/LibraryRepository.swift`：新上传目标路径和文件时间属性。
- `macos/Tests/AndroidSyncCoreTests/LibraryRepositoryTests.swift`：平铺路径、时间优先级和
  冲突 sidecar 回归覆盖。
- `macos/README.md`、`PROJECT_MEMORY/01_ARCHITECTURE.md`、`PROJECT_MEMORY/04_DECISION_LOG.md`：
  存储契约和 ADR 记录。

## 非目标

- 不自动搬迁已有 `YYYY-MM` 目录中的文件。
- 不修改 Android 上传协议、媒体扫描、manifest 结构或 B33/B34 未提交改动。
- 不改变媒体字节、临时 `.part` 校验、JSONL 历史和删除 tombstone 语义。

## 风险和决策

- R-004：保留 `.incoming/*.part` 清理路径，只有完整上传才进入平铺目录。
- R-006：平铺后同类目录内仍使用唯一文件名，避免覆盖已有文件或 sidecar。
- R-007：仍先比较实际尺寸和 `Content-Length`，尺寸不符不提交。
- ADR-004 的按月最终目录决策由 ADR-009 supersede；ADR-005 的追加式 manifest 决策保持不变。

## 不变量

- 接收端仍只允许通过 `LibraryRepository` actor 提交持久文件。
- `uploads.jsonl` 仍保存实际文件路径，旧按月路径可以继续加载。
- 文件名安全校验、重名后缀、sidecar 和 manifest 历史保持不变。
- 源时间优先级固定为 `dateModified` → `dateTaken` → `dateAdded` → 接收时间，并同时
  写入文件系统创建时间和修改时间。

## 验证

```bash
swift test --package-path macos --filter LibraryRepositoryTests.testStore
swift test --package-path macos
git diff --check
```

定向测试覆盖 7 个 `LibraryRepositoryTests.testStore*` 用例并通过；完整
`swift test --package-path macos` 运行 118 个测试并通过；
`./macos/build_and_run.sh verify` 和 `git diff --check` 均通过。

## 回滚

回滚本批次的 `LibraryRepository` 和文档变更即可恢复按月目录；已经按平铺布局写入的
新文件不会被自动删除，旧实现仍可通过 `uploads.jsonl` 中记录的路径读取它们。若需要
统一布局，另行执行有明确清单和备份的迁移。

## 结果

- 提交：随 B32–B35 一并提交为 `2690006`，2026-09-22 本地提交，未推送。
- 结果：已完成新上传平铺和源时间戳落盘实现，定向/全量 macOS 验证通过。
- 后续：既有改动已按用户要求提交；后续新增改动另行审查和验收。
