# 交接

最后更新：2026-07-08

## 从这里开始

主分支是 `main`，B04 实现提交为 `fee8063`。产品版本为 `0.1.2`。治理文档、已
批准的稳定性/macOS UX 实现、Android UI 重设计和 macOS UI 重设计已经合并到
`main`。Android UI 快进合入点为 `2eb0889`；macOS UI 合并提交为 `784139a`。

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

以上自动化检查最近于 2026-07-08 的 UI 集成后通过：Android JVM 测试、APK 构建、
macOS 92 个测试和 `./macos/build_and_run.sh verify` 均通过。仍需执行
`batches/2026-07-08-B21-android-device-header-qa.md` 中记录的 Android 真机清单
和 macOS GUI 手工 QA。验收 Android 稳定性里程碑前，先复核风险 R-001 和 R-002。

## 最新本地工作

B23 QA 修复已完成（提交 `755360b`）：针对 2026-07-08 真机/GUI 反馈，Android
修复深色文字/状态栏、缩略图首进不显示、预览加载卡住、确认页贴边、网格同步状态、
横竖屏触发重扫（固定竖屏）和 batch 进度 header；macOS 新增已删除清空、固定传输
卡高度、显示 batch 总数/进度、按媒体原始时间排序/显示并补 sidecar 时间 fallback。
验证：`./android/run_tests.sh`、`./android/build.sh`、`swift test --package-path macos`
（96 tests）、`./macos/build_and_run.sh verify`、ADB 安装/启动与截图检查均通过。
Mac 局域网测试 URL 仍为 `http://192.168.1.6:8765/uploads/`。真实端到端大文件传输
仍待用户真机验证。

B22 UI 分支集成已完成（`main`）：Android UI 重设计快进到 `2eb0889`，macOS UI
重设计合并提交 `784139a`。2026-07-08 已构建并安装 Android APK 到无线 ADB 设备
`22081212C`，启动到 `com.androidsync.app/.MainActivity`；macOS 接收端已用
`./macos/build_and_run.sh verify` 打开，`curl http://127.0.0.1:8765/health`
返回 ok。Mac 局域网测试 URL：`http://192.168.1.6:8765/uploads/`。这只证明安装、
启动和自动化通过，不证明真机传输 QA 已完成。

B16 Android 大文件上传 OOM 修复已完成（`main`，提交 `fbec5bc`）：根因为
`HttpFileUploader` 未设流式模式、请求体整体缓冲内存；已加
`setFixedLengthStreamingMode(long)`。Android 测试/构建通过，真机大文件回归
未执行。详见 `batches/2026-07-08-B16-android-large-file-oom.md`。

macOS UI 重设计历史 tip `0296cf6`：B10–B15 六批次完成、全分支终审通过（92 个
macOS 测试），已合入 `main`，仍待 GUI 手工 QA。
2026-07-08 已用限速 curl 实测传输态：状态胶囊、卡片行进度/速度、今日统计正常
（含 880pt 最小宽度）。用户报告的"传输时胶囊不可见"在新构建上未复现，疑为
旧安装包（v0.1.2 无胶囊），待用户确认。

Android 端重设计已在 `codex/android-ui-redesign` 全部实现并快进合入 `main`
（2026-07-08，B17–B21，tip `2eb0889`）：依 spec `12090ab` + 计划 `804c732`
逐任务执行。
每批 `./android/run_tests.sh`（含新增 `AlbumFilterTest`）+ `./android/build.sh`
通过。新增 `ui/` 包：`Theme`（深色 token）、`Widgets`（14 View 工厂 +
`formatBytes`）、`ThumbnailLoader`（缩略图/预览管线）、`AlbumPickerView`、
`SettingsPageView`、`ConfirmSelectionView`、`TransferCardView`、`LibraryPageView`；
`core/AlbumFilter`（+JVM 测试）；`android/AlbumPrefs`（相册白名单持久化）；
`MediaStoreScanner` 加 bucket 过滤/`listAlbums`；`MediaItem` 加 bucket 字段；
`HttpFileUploader` 加 `X-Android-Sync-Device` 头。MainActivity 由 1914 行降至
815 行，收敛为 library/settings/albumPicker/confirm 四屏。批次记录见
`batches/2026-07-08-B17..B21`。**待办**：真机 QA（B21 的 8 项验收清单均未执行——
无设备，含 B16 GB 级视频回归）。合入 `main` 不等于已验收。

B09 macOS 删除标记修复已完成（提交 `039af65`）：用户报告“删除的 item 还在列表
显示”。根因是 `MediaItemEntity` 的 SwiftData 属性名 `deleted` 与 NSManagedObject
保留名冲突，`ModelContext.save()` 静默丢弃写入值，导致已删除条目在会话内和每次
启动后都复活（真实库中同一条目累积了 5 条重复 tombstone）。属性已改名为
`removed`（带默认值支持旧 store 轻量迁移），实体用法同步更新，并新增回归测试
`AppModelDeleteTests`。验证：`swift test --package-path macos`（78 个测试）与
`./macos/build_and_run.sh verify` 通过；真实 store 副本迁移验证通过。提交后需把
SHA 回填进 `00_PROJECT_STATUS.md` 与 B09 批次记录、R-011 风险行。

B08 macOS 里程碑补建已完成：新增 `milestones/M2_macos_receiver_correctness.md`
与 `milestones/M3_macos_ux.md`，承接 Phase 2/Phase 3 退出标准并与路线图互链；未完成
的设备/视觉 QA 与 B04 测试执行保持为未闭合项。B06–B08 已合并到 `main`，提交分别为
`88c0150`、`3a1acd0`、`49ffee0`。

B07 AGENTS.md 结构优化已完成：`AGENTS.md` 新增事实来源分层段，PROJECT_MEMORY
逐文件清单收敛为指向 `PROJECT_MEMORY/README.md`（消除重复），并将提交/分支引用
规范与文档语言约定升为明文规则。只改 `AGENTS.md` 与记录文档。B06 与 B07 均为本地
未提交批次，提交后需把各自 SHA 回填进 `00_PROJECT_STATUS.md` 的“待回填”行。

B06 项目记忆文档订正已完成：修正 `00_PROJECT_STATUS.md` 的主线提交与分支指针
（补记 `main` 最近提交 `5f6fd33`；治理分支 `codex/agent-governance` tip 为
`a07593a`，其上集成合并提交为 `23b09d5`），并为 B01、B03、B04 批次记录补齐模板要求
的“不变量”段。只改 `PROJECT_MEMORY/` 内的 Markdown 文档，未触及源码或运行时行为。

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
