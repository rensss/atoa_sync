# 项目状态

最后复核：2026-07-07

## 基线

- 产品版本：`0.1.2`
- 主分支：`main`
- 远端：`origin`，地址为 `git@github.com:rensss/atoa_sync.git`
- `main` 最近治理批次提交：`49ffee0`（B08 里程碑）
- 主线集成合并提交：`8a09aa0`（B03 集成合并）
- `main` 上 B04 实现提交：`fee8063`
- `main` 上 B05 文档治理提交：`a24a442`
- `main` 上 B06 文档订正提交：`88c0150`
- `main` 上 B07 AGENTS.md 结构优化提交：`3a1acd0`
- `main` 上 B08 macOS 里程碑补建提交：`49ffee0`
- 治理分支：`codex/agent-governance`，tip 位于 `a07593a`；其上的集成合并提交为 `23b09d5`
- 候选实现分支：`codex/stability-macos-ux`，位于 `cbf31db`
- 最新发布标签：`v0.1.2`
- macOS UI 重设计分支：`codex/macos-ui-redesign`（tip `0296cf6`，B10–B15 全部
  完成并经全分支终审，待 GUI 手工 QA 后合回 `main`）
- 仓库布局：Android 代码在 `android/`，macOS 代码在 `macos/`
- 受支持接收端：原生 macOS `ReceiverService`

## 已验证当前状态

- `main` 包含已发布的 Android `0.1.2` 实现、原生 macOS 接收端/媒体库、仓库治理
  文档，以及已批准的 Android 稳定性和 macOS UX 实现。
- 平台目录重组和废弃 Python 接收端移除已完成。
- 稳定性与 macOS UX 的设计和实施计划位于 `docs/superpowers/`。
- `codex/stability-macos-ux` 分支实现了已批准的 Android 稳定性和 macOS UX 计划。
  该分支已于 2026-06-22 合并到 `codex/agent-governance` 的 `23b09d5`，随后合并
  到 `main` 的 `8a09aa0`。Android 侧包括有界/合并缩略图请求、生命周期保护、
  队列原地更新和同步代次隔离。macOS 侧包括默认中文本地化、原生工具栏、稳定
  缩略图尺寸、空格 Quick Look、失败上传清理、串行接收器生命周期、设置和版本信息。
- 候选分支通过了 Android 测试/构建和 75 个 macOS 测试，构建了 macOS release
  目标，并生成签名应用包，版本 `0.1.2`、构建号 `35`。独立最终代码审查未发现
  阻塞问题。集成提交 `23b09d5` 于 2026-06-22 通过 Android 测试/构建、Swift
  测试和 macOS 应用验证。
- 未连接 Android 真机，因此必需的压力测试尚未完成。当前自动化会话也无法捕获
  macOS 显示画面进行最终视觉 QA，所以两个平台里程碑都不能视为完全验收。
- `main` 上的 B04 改动让 macOS 删除处理在接收文件已经不存在或记录已标记删除时
  具备幂等性。实现提交为 `fee8063`。构建验证已通过；XCTest 执行目前被本地
  runner/系统策略问题阻塞，详见
  `PROJECT_MEMORY/batches/2026-06-22-B04-macos-idempotent-delete.md`。
- B05 文档治理改动已将仓库级文档、平台 README、发布说明、历史计划/设计文档和
  `PROJECT_MEMORY/` 统一整理为中文，并在 `AGENTS.md` 明确项目记忆结构和更新规则。
  根目录冗余的 `CHANGELOG.md` 和 `CONTRIBUTING.md` 已移除。本批次只修改 Markdown
  文档。
- B06 文档订正修正了本文件的主线提交与分支指针：补记 `main` 最近提交
  `5f6fd33`，并消除同名治理分支 `codex/agent-governance` 两处 SHA 的歧义（tip 为
  `a07593a`，其上集成合并提交为 `23b09d5`）。同时为 B01、B03、B04 批次记录补齐
  `PROJECT_MEMORY/batches/TEMPLATE.md` 要求的“不变量”段。本批次只修改
  `PROJECT_MEMORY/` 内的 Markdown 文档。
- B07 AGENTS.md 结构优化在 `AGENTS.md` 中新增事实来源分层段，把 PROJECT_MEMORY
  逐文件清单收敛为指向 `PROJECT_MEMORY/README.md`（消除重复），并将提交/分支引用
  规范与文档语言约定升为明文规则。本批次只修改 `AGENTS.md` 与两份记录文档。
- B08 macOS 里程碑补建新增 `milestones/M2_macos_receiver_correctness.md` 与
  `milestones/M3_macos_ux.md`，承接 Phase 2/Phase 3 的进入/退出标准，并在路线图
  互链。未完成的设备/视觉 QA 与 B04 测试执行保持为未闭合退出标准，未宣称阶段完成。
- B09（提交 `039af65`）修复 macOS 已删除条目在列表中复活的缺陷：`MediaItemEntity`
  的 `deleted` 属性与 NSManagedObject 保留名冲突，`ModelContext.save()` 静默丢弃
  写入值；已改名为 `removed` 并新增回归测试。完整 macOS 测试套件（78 个）通过，
  真实 store 副本轻量迁移验证通过。详见
  `PROJECT_MEMORY/batches/2026-07-07-B09-macos-swiftdata-deleted-flag.md`
  和风险 R-011。
- B16（提交 `fbec5bc`）修复 Android 大文件上传 OOM 崩溃：`HttpFileUploader` 的
  `setDoOutput(true)` 未配流式模式导致整个请求体缓冲进内存，GB 级视频必崩；
  已加 `setFixedLengthStreamingMode(long)`。Android 测试与 APK 构建通过；
  接收端定长流式兼容性经 curl 实测；真机大文件回归未执行。详见
  `PROJECT_MEMORY/batches/2026-07-08-B16-android-large-file-oom.md`。

## 开放工作

1. 完成 Android 真机压力测试，覆盖大型媒体库、导航、生命周期切换和重复开始同步
   （退出标准见 `milestones/M1_android_stability.md`）。
2. 完成 macOS 最终视觉与交互 QA，覆盖工具栏位置、本地化菜单、Inspector/搜索布局、
   缩略图和 Quick Look（退出标准见 `milestones/M3_macos_ux.md`；接收端正确性收尾见
   `milestones/M2_macos_receiver_correctness.md`）。
3. 在可信私有网络之外使用前，重新评估局域网认证和传输安全。
4. macOS UI 重设计分支 `codex/macos-ui-redesign` 的 GUI 手工 QA（五状态胶囊、
   空闲无卡片占位、真机进度/速度、并发上传进度观感）与合并决策。
5. Android 端需求（用户 2026-07-08 提出，进 Android 端重设计 spec）：支持
   文件/目录选择，避免把下载目录里的电影等非目标媒体纳入同步；同 spec 一并
   覆盖 B16 遗留的真机大文件回归。

## 当前验证记录

候选提交 `cbf31db` 于 2026-06-15 使用以下命令验证：

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
swift build --package-path macos -c release
bash -n macos/build_and_run.sh
./macos/build_and_run.sh verify
plutil -lint "dist/Android Sync.app/Contents/Info.plist"
codesign --verify --deep --strict "dist/Android Sync.app"
```

全部通过。macOS 套件运行 75 个测试。生成的 plist 报告
`CFBundleShortVersionString=0.1.2` 和 `CFBundleVersion=35`。ADB 未发现已连接
设备，自动化会话无法进行显示捕获。

集成提交 `23b09d5` 于 2026-06-22 通过把 `codex/stability-macos-ux` 合并到
`codex/agent-governance` 创建。该集成提交使用以下命令验证：

```bash
git diff --check
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
```

全部通过。Swift 运行 75 个测试。Android 真机压力测试和 macOS 最终视觉/交互 QA
仍未完成。

主线合并提交 `8a09aa0` 于 2026-06-22 通过把 `codex/agent-governance` 合并到
`main` 创建，合并无冲突。

B04 本地 macOS 幂等删除改动于 2026-06-22 使用以下命令验证：

```bash
swift build --package-path macos
```

构建通过。以下命令构建成功，但在当前自动化环境中启动 XCTest 时挂起：

```bash
swift test --package-path macos --filter LibraryRepositoryTests
```

直接运行 `xcrun xctest` 被 macOS 系统策略拒绝，因为 SwiftPM 测试包未签名。

B05 中文文档和项目记忆治理改动于 2026-06-23 使用以下命令验证：

```bash
git diff --check
rg -n "AGENT\\.md|AGENTS\\.md|CLAUDE\\.md|PROJECT_MEMORY|Documentation|Update Rules|Reading Order" -g '*.md'
```

`git diff --check` 通过。引用扫描确认活跃文档指向 `AGENTS.md` 和 `PROJECT_MEMORY/`；
单数 `AGENT.md` 只出现在扫描命令和 B01 历史批次描述中。未运行平台测试，因为本批次只修改
Markdown 文档。

B06 项目记忆文档订正于 2026-07-04 使用以下命令验证：

```bash
git diff --check
for r in main codex/agent-governance codex/stability-macos-ux; do git rev-parse --short "$r"; done
for f in PROJECT_MEMORY/batches/2026-*.md; do grep -q "^## 不变量" "$f" || echo "缺: $f"; done
```

`git diff --check` 通过。分支/HEAD 解析确认 `main` 位于 `5f6fd33`、
`codex/agent-governance` 位于 `a07593a`、`codex/stability-macos-ux` 位于 `cbf31db`，
与订正后的指针一致。不变量段扫描无输出，确认全部批次记录均含“不变量”段。未运行
平台测试，因为本批次只修改 `PROJECT_MEMORY/` 内的 Markdown 文档。

B07 AGENTS.md 结构优化于 2026-07-04 使用以下命令验证：

```bash
git diff --check
rg -n "PROJECT_MEMORY 文档结构" AGENTS.md
rg -n "PROJECT_MEMORY/README.md" AGENTS.md
rg -n "git rev-parse|默认使用中文|事实来源分层" AGENTS.md
```

`git diff --check` 通过。对“PROJECT_MEMORY 文档结构”的扫描无输出，确认重复清单已
移除；`PROJECT_MEMORY/README.md` 与三条新增规则的扫描均命中。未运行平台测试，因为
本批次只修改 Markdown 文档。

B08 macOS 里程碑补建于 2026-07-04 使用以下命令验证：

```bash
git diff --check
ls PROJECT_MEMORY/milestones/M2_macos_receiver_correctness.md PROJECT_MEMORY/milestones/M3_macos_ux.md
rg -n "milestones/M2_macos_receiver_correctness.md|milestones/M3_macos_ux.md" PROJECT_MEMORY/03_REFACTOR_ROADMAP.md
```

`git diff --check` 通过。两个里程碑文件存在；路线图 Phase 2、Phase 3 均已引用对应
里程碑。未运行平台测试，因为本批次只修改 Markdown 文档。

B09 macOS 删除标记修复于 2026-07-07 使用以下命令验证：

```bash
swift test --package-path macos
./macos/build_and_run.sh verify
```

全部通过；macOS 套件运行 78 个测试（含新增 `AppModelDeleteTests` 回归）。另用
独立最小复现确认 SwiftData 保留名冲突（`deleted` 回滚、`removed` 正常），并用
真实 `default.store` 与 `uploads.jsonl` 副本验证轻量迁移和 tombstone 解析。未运行
Android 测试，因为本批次只修改 macOS 代码。

## 状态维护

当主分支、发布版本、活跃阶段、开放事项或已验证状态变化时，必须更新本文件。
不要仅因计划或分支存在就把计划工作标记为完成。
