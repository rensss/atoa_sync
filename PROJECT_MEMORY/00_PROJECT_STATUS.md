# 项目状态

最后复核：2026-07-21

## 基线

- 产品版本：`0.1.2`
- 主分支：`main`
- B24–B28 实现提交：`54ff01b`。
- B27 后续键盘导航修复及 B29–B30 实现提交：`067a501`。
- 远端：`origin`，地址为 `git@github.com:rensss/atoa_sync.git`
- `main` 最近治理批次提交：`49ffee0`（B08 里程碑）
- 主线集成合并提交：`8a09aa0`（B03 集成合并）
- `main` 上 B04 实现提交：`fee8063`
- `main` 上 B05 文档治理提交：`a24a442`
- `main` 上 B06 文档订正提交：`88c0150`
- `main` 上 B07 AGENTS.md 结构优化提交：`3a1acd0`
- `main` 上 B08 macOS 里程碑补建提交：`49ffee0`
- `main` 上 Android UI 重设计合入提交：`2eb0889`（B17-B21 快进）
- `main` 上 macOS UI 重设计合并提交：`784139a`
- 治理分支：`codex/agent-governance`，tip 位于 `a07593a`；其上的集成合并提交为 `23b09d5`
- 候选实现分支：`codex/stability-macos-ux`，位于 `cbf31db`
- 最新发布标签：`v0.1.2`
- macOS UI 重设计历史 tip：`codex/macos-ui-redesign` 的 `0296cf6`（B10-B15 全部
  完成并经全分支终审；已合入 `main`，仍需 GUI 手工 QA）
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
- B10（分支 `codex/macos-ui-redesign`，提交 `83205c2`/`a3acab4`/`e6a0f18`）为
  macOS UI 重设计批次 1/6：深色主题 token、三 Scene 强制深色、工具栏状态胶囊
  替代顶部状态条。83 个测试全绿；GUI 手工核对留分支终验。spec 与实施计划见
  `docs/superpowers/specs/2026-07-07-macos-ui-redesign-design.md`、
  `docs/superpowers/plans/2026-07-07-macos-ui-redesign.md`，批次详情见
  `PROJECT_MEMORY/batches/2026-07-07-B10-macos-dark-theme-status-capsule.md`。
- B11（同分支，提交 `45c101c`/`78a55a4`）为 UI 重设计批次 2/6：侧栏分类计数
  （不受搜索/日期过滤影响）与深色侧栏样式。84 个测试全绿。详见
  `PROJECT_MEMORY/batches/2026-07-07-B11-macos-sidebar-counts.md`。
- B12（同分支，提交 `d803856`/`f845190`/`1d5c4a0`）为 UI 重设计批次 3/6：
  传输卡片状态机（含跨 burst 计数泄漏修复）、今日统计、网格上方传输卡片行，
  `transientUploadMessage` 横幅展示位在此闭合。88 个测试全绿。详见
  `PROJECT_MEMORY/batches/2026-07-07-B12-macos-transfer-card-row.md`。
- B13（同分支，提交 `9f92e4a`/`aef49e6`）为 UI 重设计批次 4/6：ThumbnailMetrics
  并入 `Theme.Thumb`、高密度网格（150pt/3pt/无标签/时长角标）、列表与
  Inspector/RenameSheet 深色化。87 个测试全绿（度量测试 2 合 1）。详见
  `PROJECT_MEMORY/batches/2026-07-07-B13-macos-dense-grid-inspector.md`。
- B14（同分支，提交 `8d06185`）为 UI 重设计批次 5/6：Onboarding 重做与
  设置深色化，MenuBarView 按计划豁免。87 个测试全绿。详见
  `PROJECT_MEMORY/batches/2026-07-07-B14-macos-onboarding-settings-dark.md`。
- B15（同分支，提交 `ffbfacf`）为 UI 重设计批次 6/6：ReceiverService 上传进度
  事件（512 KB 节流）、传输卡片确定进度条与速度显示。90 个测试全绿。已知限制
  与风险复核（R-004/R-005/R-007 不受影响）见
  `PROJECT_MEMORY/batches/2026-07-07-B15-macos-upload-progress-events.md`。
- 全分支终审（fable 级审查）判定 With fixes，唯一 Important（跨 burst 进度/
  速度状态泄漏）已修复于 `9884b01` 并经独立复审确认；92 个测试全绿。分支已合入
  `main`，GUI 手工 QA 仍为 M3 口径未闭合项。
- B17-B21 Android UI 重设计已在 `codex/android-ui-redesign` 完成并快进合入
  `main`（tip `2eb0889`）。范围包括深色媒体库首页、相册白名单、同步前确认态、
  临时排除、传输卡片、设备名上传头、MainActivity 拆分和缩略图管线搬移。
  每批 `./android/run_tests.sh` 与 `./android/build.sh` 通过；真机 QA 未执行。
- B22 本地集成把 Android UI 重设计和 macOS UI 重设计合入 `main`。Android 侧为
  快进到 `2eb0889`；macOS 侧合并提交为 `784139a`。本轮验证通过 Android JVM 测试、
  APK 构建、无线 ADB 安装/启动、macOS 92 个测试、macOS 应用 verify 和接收端
  `/health` 检查；真机传输 QA 与 macOS GUI 人工 QA 仍未闭合。
- B23（提交 `7c2c0c6`）处理 2026-07-08 真机/GUI QA 反馈：Android 侧修复深色文字
  与系统栏、缩略图首进不显示、预览卡在加载、确认页贴边、网格同步状态显示、横竖屏
  重建重扫（固定竖屏）、batch 总数 header；macOS 侧新增已删除清空、稳定传输卡高度、
  batch 总数进度、媒体原始时间排序/显示和 sidecar 时间 fallback。Android 测试/构建、
  macOS 96 个测试、macOS verify、ADB 安装启动和截图检查通过；真实端到端大文件传输
  仍待用户真机验证。
- B24 地址二维码配置已在 `main` 的 `b0092d1` 工作基线上完成本地代码与单元测试：
  macOS 工具栏可用 Core Image 显示当前上传地址二维码；Android 注册
  `androidsync://configure` 深链，用系统相机扫码打开后校验并保存 HTTP/HTTPS 目标。
  Android JVM 测试、APK 构建、macOS 组合套件最终 101 个测试和应用 verify 通过；
  无线 ADB 真机上的冷启动与前台 `onNewIntent` 深链路径均通过并已恢复原地址。实现
  已提交为 `54ff01b`；系统相机扫描真实二维码仍待手工确认，详见
  `PROJECT_MEMORY/batches/2026-07-14-B24-address-qr-configuration.md`。
- B25 同步范围与双端停止控制已在同一工作基线上完成并提交为 `54ff01b`：Android 队列随最新
  相册白名单 reconcile，一次同步只上传确认页 stable ID；传输卡折叠更新保持有界，
  错误提示自动收起并新增可取消上传。macOS 主窗口新增暂停接收入口，接收端补齐对端
  `.cancelled` 清理，避免 Android 停止后活动项和 `.part` 残留。Android 测试/构建、
  macOS 101 个测试、应用 verify、最终 APK 安装/启动和双端真机停止链路已通过，
  详见 `PROJECT_MEMORY/batches/2026-07-14-B25-sync-scope-stop-controls.md`。
- B26 macOS 侧边栏媒体库概览已在同一工作基线上完成本地实现：底部脚视图展示未删除
  照片、视频、其他文件数量和媒体总占用，并保留接收目录入口；统计不受搜索、日期和
  当前分类影响。macOS 103 个测试与应用 verify 通过，真实窗口已确认 185pt 侧栏内
  统计和目录入口完整可见。实现已提交为 `54ff01b`，详见
  `PROJECT_MEMORY/batches/2026-07-14-B26-macos-sidebar-library-summary.md`。
- B27 macOS Quick Look 连续预览与键盘删除已在同一工作基线上完成本地实现：预览
  一次持有当前筛选结果，左右方向键只更新系统面板索引而不重复 present/reload；
  Quick Look 与媒体库均支持 Delete，继续复用 repository/tombstone 删除路径。用户
  回归后修复了物理方向键自带系统 modifier 被误过滤及网格列数未更新的问题。定向
  Quick Look 12 个、AppModelQuery 9 个和完整 110 个测试通过，应用 verify 通过；
  真实窗口已确认 Quick Look 连续切换和主网格四方向移动/跨行。Delete 由临时仓库/
  tombstone 集成测试覆盖，未删除真实媒体。初始实现已提交为 `54ff01b`，本轮修复尚未
  提交，详见
  `PROJECT_MEMORY/batches/2026-07-20-B27-macos-quick-look-navigation-delete.md`。
- B28 macOS 标题栏重设计已在同一工作基线上完成本地实现：隐藏重复窗口标题，把分类、
  数量和接收状态合成左侧状态菜单，把接收、二维码、上下文删除、筛选/排序、布局、
  设置和 Inspector 收进统一控制条；日期与排序改为同一个单层分区菜单。macOS 108 个
  测试、应用 verify 和 diff 检查通过；真实窗口已检查标题栏、状态/二维码菜单和日期
  筛选往返，接收服务最终恢复运行。实现已提交为 `54ff01b`，详见
  `PROJECT_MEMORY/batches/2026-07-20-B28-macos-titlebar-redesign.md`。
- B29 macOS 标题栏后续修正已在 `9269afc` 基线上完成本地实现：移除系统自动套用
  Liquid Glass 的“全部项目 624”分类胶囊，分类与数量只在侧栏选中行显示；接收状态
  菜单收进统一控制条并改为状态圆点入口。macOS 108 个测试和应用 verify 通过，真实
  窗口确认胶囊已消失且状态菜单仍含暂停、复制地址和当前 URL。实现提交为 `067a501`，详见
  `PROJECT_MEMORY/batches/2026-07-20-B29-macos-titlebar-remove-category-capsule.md`。
- B30 macOS 标题栏搜索交互已在 B29 工作区上完成本地实现：搜索默认明确保持为最右侧
  独立放大镜按钮；macOS 26 使用弹性 `ToolbarSpacer` 把它推到窗口最右侧，并避免与
  主操作组共用一整块 Liquid Glass；独立搜索项在收起时隐藏系统共享背景，只显示裸
  放大镜，展开后恢复输入框边界。搜索文本继续绑定既有查询逻辑。
  搜索框失焦会自动收起并保留已有查询。Command-F、直接输入、实时筛选及两段式
  Escape 清空/收起均经真实窗口验证；macOS 110 个测试和应用 verify 通过。实现提交为
  `067a501`，详见
  `PROJECT_MEMORY/batches/2026-07-21-B30-macos-collapsible-toolbar-search.md`。

## 开放工作

1. 完成 Android 真机压力测试，覆盖大型媒体库、导航、生命周期切换和重复开始同步
   （退出标准见 `milestones/M1_android_stability.md`）。
2. 完成 macOS 最终视觉与交互 QA，覆盖工具栏位置、本地化菜单、Inspector/搜索布局、
   缩略图和 Quick Look（退出标准见 `milestones/M3_macos_ux.md`；接收端正确性收尾见
   `milestones/M2_macos_receiver_correctness.md`）。
3. 在可信私有网络之外使用前，重新评估局域网认证和传输安全。
4. 完成 Android UI 重设计真机 QA（B21 记录的 8 项验收清单均未执行，含 B16
   GB 级视频回归）。
5. 完成 macOS UI 重设计 GUI 手工 QA（五状态胶囊、空闲无卡片占位、真机进度/速度、
   并发上传进度观感）。
6. 完成 B24 真机扫码 QA：覆盖 Android 冷启动和前台 `onNewIntent` 两条路径，并确认
   地址更新后从设置页可见且实际上传仍指向扫码得到的 Mac。
7. 对 B25 执行大型媒体库持续滚动、GB 级视频中途停止和重复开始/停止压力测试；当前
   只完成 269 项 `WeiXin` 相册下的受控真机冒烟，不关闭 M1 压力退出标准。

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

B22 UI 分支本地集成于 2026-07-08 在 `main` 验证：

```bash
./android/run_tests.sh
./android/build.sh
adb devices -l
adb install -r android/build/AndroidSync-debug.apk
adb shell monkey -p com.androidsync.app -c android.intent.category.LAUNCHER 1
./macos/build_and_run.sh verify
curl -fsS http://127.0.0.1:8765/health
swift test --package-path macos
```

结果：Android JVM 测试通过（`AlbumFilterTest passed`）；APK 构建通过并输出
`android/build/AndroidSync-debug.apk`；无线设备 `22081212C` 在线，APK 安装成功并
启动到 `com.androidsync.app/.MainActivity`；macOS 应用启动成功，接收端 health
返回 `{"status":"ok"}`；`swift test --package-path macos` 运行 92 个测试且全部通过。
Mac 局域网测试 URL 为 `http://192.168.1.6:8765/uploads/`。本轮只完成安装和自动化
验证，不把 Android 真机传输或 macOS GUI 手工检查标记为通过。

B23 QA 修复于 2026-07-08 在 `main` 验证：

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
adb devices -l
adb install -r android/build/AndroidSync-debug.apk
adb shell am start -n com.androidsync.app/.MainActivity
adb exec-out screencap -p > /tmp/android-sync-current.png
curl -fsS http://127.0.0.1:8765/health
git diff --check
```

结果：Android JVM 测试通过（`AlbumFilterTest passed`），APK 构建通过；macOS 96 个
测试全部通过，`./macos/build_and_run.sh verify` 通过；无线设备 `22081212C` 安装并
启动到 `com.androidsync.app/.MainActivity`；截图人工检查确认状态栏为亮色文字且缩略图
首屏显示；接收端 health 返回 `{"status":"ok"}`。未把真实 Android 到 Mac 的大文件
传输验收标记为完成。

B24 地址二维码配置于 2026-07-14 在 `main` 的 `b0092d1` 工作基线上进行首轮验证：

```bash
./android/run_tests.sh
swift test --package-path macos
```

结果：Android JVM 测试通过并输出 `AddressConfigurationTest passed`，APK 构建/签名
通过；macOS 组合套件最终运行 101 个测试且全部通过，其中 `AddressQRCodeTests` 4 个
新增测试通过，应用 verify 通过。APK 已安装到无线 ADB 设备 `22081212C`；冷启动深链显示 8765 地址，
前台 `onNewIntent` 显示临时 8766 地址后已恢复到 8765。真实系统相机扫码仍待手工确认。

B25 同步范围与双端停止控制于 2026-07-14 在同一组合工作区验证：

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
adb install -r android/build/AndroidSync-debug.apk
adb shell am start -n com.androidsync.app/.MainActivity
curl -fsS http://127.0.0.1:8765/health
git diff --check
```

结果：Android JVM 测试和 APK 构建通过；macOS 101 个测试全部通过；最终 APK 已安装并
启动到无线设备 `22081212C`，macOS 应用 verify 和 `/health` 通过。真机确认页显示
当前 `WeiXin` 白名单的 244 个待传项目；Android 停止后无活跃 TCP 连接，后段任务保持
未同步，macOS 活动上传清零并回到可接收状态。受控验证有 6 个小文件完成落盘。
最终从 Android 设置页确认目标已恢复为当前 Mac 的
`http://192.168.1.23:8765/uploads/`。

B26 macOS 侧边栏媒体库概览于 2026-07-14 在同一组合工作区验证：

```bash
swift test --package-path macos --filter AppModelSidebarCountTests
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

结果：定向 3 个测试和完整 103 个测试均通过，应用打包、签名、启动验证通过，
`git diff --check` 通过。通过真实应用窗口检查确认 185pt 侧栏底部显示照片 606、视频
18、其他文件 0、已占用 5.8 GB，且接收目录入口未被裁切。此检查只验收 B26 新增区域，
不替代 M3 尚未完成的全量视觉/交互 QA。

## 状态维护

当主分支、发布版本、活跃阶段、开放事项或已验证状态变化时，必须更新本文件。
不要仅因计划或分支存在就把计划工作标记为完成。
