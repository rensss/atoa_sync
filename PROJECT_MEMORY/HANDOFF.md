# 交接

最后更新：2026-11-09

## 当前修复（2026-11-09 B40）

- 手机实际安装版本来自本工作树 `feat/android-ui-refresh`（基线 `6cf7b44`），不是 `main`。
  当前 `main` / `origin/main` 均为 `1749eb4`；下方旧分支指针仅供历史参考。
- 已复现并修复设置页深链冷启动时，传输卡未 build 就被 `onStart` 刷新导致的空指针。
  三个展示方法增加 build 前保护，媒体库创建后的队列刷新保持不变。
- Android 全套测试、APK 构建、真机冷启动与两条前台深链路径通过；已用匹配签名覆盖安装，
  保留手机数据。回归命令与证据见 `batches/2026-11-09-B40-qr-launch-crash.md`。
- 修复随本分支交付，未合入 main；提交与远端状态以 Git 为准。
  物理相机扫码、完整 B39 及 M1/M2/M3 验收仍待执行。

## 从这里开始

项目主分支 `main` 当前位于 Android UI 重设计规格提交 `1749eb4`，`origin/main` 当前为
`17c7538`，产品版本仍为 `0.1.3`。B39 Android UI 实现位于本地分支
`feat/android-ui-refresh`，代码验证提交为 `923c61d`（基于 `1749eb4`）；实现和文档提交均未推送。
工作树、分支 tip 和远端跟踪指针请以 `git status --short --branch` 与 `git rev-parse` 实时确认。

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

2026-09-22 提交前复验：Android JVM 测试、APK 构建、macOS 118 个测试、
`./macos/build_and_run.sh verify` 和 `git diff --check` 均通过。B37 最新全量检查记录见下方；仍需执行
`batches/2026-07-08-B21-android-device-header-qa.md` 中记录的 Android 真机清单
和 macOS GUI 手工 QA。验收 Android 稳定性里程碑前，先复核风险 R-001 和 R-002。

B34 的 macOS 同步进度修正已在本地提交 `2690006`：`TransferCardRow` 通过
`LibraryView.safeAreaInset(edge: .top)` 作为唯一内容区顶部 header；中间批次文件完成时
保持卡片，最后一个文件完成后立即清空完成数、总数、字节进度和速度样本，不再显示完成
驻留卡。完整 macOS 套件运行 114 个测试，应用 verify 和 `git diff --check` 通过；完整
macOS GUI/交互 QA 仍待执行。批次记录见
`PROJECT_MEMORY/batches/2026-09-20-B34-macos-transfer-header-state.md`。

B35 的 macOS 接收存储修正已在本地提交 `2690006`：新上传直接平铺到
`photos/`、`videos/`、`files/`，文件创建/修改时间按 `dateModified` → `dateTaken` →
`dateAdded` → 接收时间设置；旧 `YYYY-MM` 文件不自动搬迁。定向存储测试 7 个、完整
macOS 套件 118 个、应用 verify 和 `git diff --check` 均通过。批次记录见
`PROJECT_MEMORY/batches/2026-09-21-B35-flat-receive-storage.md`，架构决策为 ADR-009。

## 最新工作

2026-09-23 B39 Android UI 重设计已实现，代码验证提交 `923c61d`：统一深色 token 和控件，
首页使用可回收媒体网格，传输摘要打开最多 40 项的底部详情抽屉；相册选择、确认固定汇总、
设置、预览和底部导航已统一样式。沿用既有 `ThumbnailLoader`、`SyncQueue`、Service、数据库、
媒体扫描/过滤、地址深链和通知行为，没有重构核心传输/数据管理。后续复核修复了抽屉复用位移、
长任务列表测量、停止状态跨 run 残留、媒体库位置覆盖和本地媒体等待远端 manifest 的问题。`./android/run_tests.sh`、
`./android/build.sh`、`git diff --check` 均通过；测试增加 `SelectionSummaryTest`、
`TransferSheetStateTest`、`TransferSheetLayoutTest`、`LibraryViewportPolicyTest`、
`MediaScanPresentationTest`。无线 ADB 重连后设备 `2410DPN6CC` 已检测到，APK 已安装并启动；
Task 1–4 的真机交互、系统栏/字体、通知返回和 R-001/R-002 压力验收仍待执行。两个风险保持开放。批次记录：
`batches/2026-09-23-B39-android-ui-refresh.md`。

2026-09-22 B38 Android 相册目录层级与通知点击已实现：相册页根据 MediaStore 目录路径构建树，
勾选文件夹会级联选择子目录；进入后可单独调整直接相册，父目录展示部分选择状态。无路径记录仍
平铺显示，持久化的 `bucket_id` 白名单不变。点击同步通知会把 MainActivity 带到前台，前台服务
继续传输；未改通知长按/渠道行为。`./android/run_tests.sh`、`./android/build.sh` 和
`git diff --check` 通过；新 APK 已构建但未安装，待用户真机验证通知点击、目录导航和级联选择。
详见 `batches/2026-09-22-B38-android-album-tree-notification.md`。

2026-09-22 B37 原生接收端暂停/恢复已完成实现。Mac 暂停保留 listener/health 控制通道，
取消未完整 PUT 并清理暂存文件；提交阶段文件正常完成。Android 识别原生接收端后，只有
暂停状态或 epoch 变化的明确证据才会将当前文件恢复为 `WAITING`，等待 Mac 恢复后从头重传；
普通错误和通用 WebDAV 仍保持原单次失败语义。等待期间 Android“停止”可终止当前 run。
Mac 所有暂停入口共享同一状态，传输卡从批次计数/字节数中扣除被丢弃文件的部分进度。
实现提交依次为 `4c97b26`、`9faf4b4`、`3ff1338`、`8cd83ee`；独立审查修复为
`5864a95`、`c2b1aaa`、`492a4ed`；协议决策为 ADR-010。
项目决策/批次首个文档提交为 `4cc3130a866c23dafc43bd4fe884cd48e0a2ebd7`；全量构建/测试结果见
`batches/2026-09-22-B37-native-pause-resume.md`。
Android 与 Mac 真机暂停、恢复、停止和文件完整性尚未验收，不要据此关闭 M1/M2/M3 里程碑
或 R-004/R-007/R-009/R-015/R-016。

2026-09-22 B36 跨端任务进度功能已基于 `2690006` 实现并提交为 `6ca48f6`，尚未推送。
Android 在 manifest 过滤后计算本次 `WAITING`/`FAILED` 批次字节总量并经可选 header 传给 macOS；
macOS 显示整批剩余量与 ETA，并把唯一进度卡放在 detail 内容区固定顶部。Android 测试、APK
构建、macOS 全量 132 个测试、应用 verify 和 `git diff --check` 均于 2026-09-22 通过；
审查后新增的 macOS 定向 24 项、Android loopback HTTP header 回归也通过。
原生窗口局部检查覆盖网格、列表、空“其他文件”、有内容“已删除”、搜索以及本地不完整 PUT
进度探测；未进行 Android→macOS 真机成功传输，空“已删除”和成功完成瞬间也未验收。不得据此
关闭 M3 GUI/交互退出标准。取消发生在两个完整 PUT 之间时 macOS 无法收到结束通知、多个发送方批次也没有
隔离 ID，列为开放风险 R-016；本批不新增结束/取消协议。两轮独立审查和最终范围核对已完成；复审指出的
loopback 测试地址族不一致已修正，`./android/run_tests.sh` 再次通过。Android 真机成功批次传输验收
仍待完成。
批次记录：`batches/2026-09-22-B36-cross-platform-task-progress.md`。

2026-09-22 按用户要求先将既有 B32–B35 改动（46 个已跟踪文件）提交为
`2690006 feat: harden Android sync and macOS receive flow`，未推送。提交前 Android
测试与构建、macOS 118 个测试与应用 verify、`git diff --check` 均通过；本次证据不覆盖
新增跨平台任务进度功能、Android 新一轮真机验收或完整 macOS GUI QA。

2026-09-21 B35 修正 macOS 接收目录布局和源文件时间戳：`LibraryRepository` 将新文件
直接提交到类型目录，并在原子移动后把源时间写入文件系统创建时间和修改时间；源时间
按 `dateModified`、`dateTaken`、`dateAdded` 依次回退，缺失时使用实际接收时间。旧按月
路径由 manifest 继续加载，不执行隐式迁移。本批未修改 Android、HTTP header 或删除
历史；于 2026-09-22 随 B32–B35 提交为 `2690006`。

2026-09-20 B34 修正 macOS 同步进度展示：进度卡不再跟随网格/列表/筛选/搜索分支布局，
而是固定在 `LibraryView` 顶部 inset；移除 `completed` 三秒驻留态及完成文案。AppModel
按批次头判断中间文件与最后文件，避免连续接收时闪烁；最后文件完成后立即回到 `idle`。
本批未修改 Android、ReceiverService、协议或存储布局；于 2026-09-22 随 B32–B35 提交为
`2690006`，且没有把 GUI 手工 QA 标记为通过。

2026-09-20 B33 已把 Android 上传生命周期移入 `SyncForegroundService`，并用
`SQLiteOpenHelper` 持久化 `sync_tasks`、`sync_runs` 和 `sync_run_tasks`。Activity 只负责
扫描、确认、展示和 Service 命令；目标 URL 与确认任务顺序在 run 创建时冻结。服务使用
`dataSync` 前台类型、低优先级 `sync_transfer` 通知和显式应用内广播，恢复前尽力查询
远端 stable ID manifest，遗留 `UPLOADING` 回到 `WAITING`。不引入 Gradle、AndroidX、
WorkManager、开机自启、自动重试或字节级续传。

B33 已于 2026-09-22 随 B32–B35 提交为 `2690006`。`./android/run_tests.sh` 与
`./android/build.sh` 通过并生成 `android/build/AndroidSync-debug.apk`；提交前再次复验通过。
无线 ADB 设备
`22081212C` 上已验证约 1963 项媒体库：Home 后通知进度持续增长，force-stop 后重开
Service 继续运行，连接失败不阻塞后续任务，应用内停止后 Service 消失。完整锁屏、低
内存回收、厂商电池策略和全量落盘仍待验证；不要据此关闭 M1 真机退出标准。
详见 `batches/2026-09-20-B33-android-background-sync.md`、风险 R-009/R-014/R-015
和架构决策 ADR-008。

2026-08-10 接手复核已完成：`main` 与 `origin/main` 一致；`v0.1.3` 指向 `17c7538`。
接手复核文档和 B32 Android adaptive icon 当前未提交。Android 测试/构建、macOS 113 个
测试、应用 verify、plist 和 codesign 校验均通过，生成的应用包版本为 `0.1.3`、构建号
`106`。本次没有 Android 真机或完整 macOS GUI 证据，因此真机压力、端到端传输和完整
视觉/交互 QA 仍是下一步。

B32 Android launcher 图标已迁移为 API 26 adaptive icon：Manifest 改用
`@mipmap/ic_launcher`，前景为 deep charcoal 背景上的 cyan/coral/yellow 模块化
`SYNC` 字标。`./android/run_tests.sh`、`./android/build.sh`、`git diff --check` 和
APK `aapt2 dump` 校验通过；真机遮罩和实际视觉尺寸待设备确认。批次记录见
`batches/2026-08-10-B32-android-adaptive-icon.md`。

B31 macOS 首页方向键滚动缩略图性能优化已在 `main` 的 `8761ecf` 基线上完成并提交为
`aa4cc87`。方向键选中项不再每次强制滚到屏幕中央，而是只做保持可见所需的最小距离滚动；
新增进程级 `ThumbnailLoader`，以文件路径、显示尺寸和屏幕倍率为键，使用 256 项/
约 96 MiB 有界缓存并合并相同在途 Quick Look 请求。定向 3 个和完整 113 个测试、
应用 verify 均通过；真实首页连续向下 12 次约 2.3 秒完成，最终可见区域仅观察到
1 个未就绪缩略图。详见
`batches/2026-07-21-B31-macos-thumbnail-navigation-performance.md` 和风险 R-013。

B30 macOS 标题栏搜索交互已在 B29 工作区上完成并提交为 `067a501`。`ContentView`
显式持有搜索展示状态：初始状态为标题栏最右侧放大镜按钮，激活后由独立工具栏项原位
展开搜索框；继续绑定既有 `AppModel.searchText`，实时文件名筛选、清除/取消、Command-F
和文本焦点行为保持；展开输入使用原生 `NSSearchField`，确保鼠标或快捷键激活后立即
成为 first responder。用户截图反馈搜索仍与主操作组熔成超长玻璃胶囊后，macOS 26
路径增加弹性 `ToolbarSpacer`，并只在收起状态隐藏独立搜索项的系统共享背景；现在
窗口顶部最右侧默认是裸放大镜，展开后恢复正常输入边界。完整 110 个测试和应用 verify
通过；搜索框失去焦点时会自动收起并保留查询；真实窗口已验证两种视觉状态、点击与
Command-F 入口、直接输入、实时筛选、失焦收起及 Escape 清空/收起。详见
`batches/2026-07-21-B30-macos-collapsible-toolbar-search.md`。

B29 macOS 标题栏分类胶囊移除已在 `main` 的 `9269afc` 基线上完成并提交为 `067a501`。
macOS 26 会自动给 `.navigation` 工具栏项套用 Liquid Glass，纯文本仍呈胶囊；
当前已删除这份与侧栏重复的“全部项目 624”，侧栏选中行继续显示分类与数量。接收状态
菜单移入统一控制条并使用状态圆点入口，暂停/开始、复制地址和 URL 详情保持不变。
完整 108 个测试、应用 verify 和真实窗口检查通过。详见
`batches/2026-07-20-B29-macos-titlebar-remove-category-capsule.md`。

B28 macOS 标题栏重设计已在 `main` 的 `b0092d1` 工作基线上完成并提交为 `54ff01b`。
主窗口隐藏重复应用标题；左侧状态菜单合并当前分类、筛选后数量和接收状态；右侧统一
控制条保留暂停/开始接收、地址二维码、上下文删除、筛选/排序、网格/列表、设置和
Inspector。日期与排序位于同一个单层分区菜单，非默认条件以强调色提示。完整 macOS
108 个测试通过；真实窗口确认标题栏布局、状态/二维码菜单及日期筛选往返，接收服务
最终恢复“可以接收文件”；应用 verify 与 `git diff --check` 通过。详见
`batches/2026-07-20-B28-macos-titlebar-redesign.md`。

B27 macOS Quick Look 连续预览与键盘删除已在 `main` 的 `b0092d1` 工作基线上完成
并提交为 `54ff01b`。空格预览现在持有当前筛选结果的稳定 URL 快照，左右方向键直接
更新系统面板索引和媒体库选中项，不重复 present/reload；Quick Look 与获得焦点的
媒体库均支持 Delete，并继续走 `LibraryRepository`/tombstone 删除路径。定向 11 个
测试的初始实现已提交；用户回归后又修复物理方向键的 `.numericPad`/`.function`
系统 modifier 被误过滤，以及网格宽度未稳定更新导致上下键不能按列跨行的问题。
定向 Quick Look 12 个、AppModelQuery 9 个和完整 110 个测试通过，应用 verify 通过；
真实窗口已确认 Quick Look 连续切换及主网格四方向移动/跨行。为避免破坏真实媒体，
Delete 使用临时仓库/tombstone 集成测试验证。本轮修复提交为 `067a501`。详见
`batches/2026-07-20-B27-macos-quick-look-navigation-delete.md`。

B26 macOS 侧边栏媒体库概览已在 `main` 的 `b0092d1` 工作基线上完成并提交为
`54ff01b`。侧边栏底部新增媒体库脚视图，展示未删除照片、视频、其他文件数量及其
总占用；搜索、日期和分类筛选不会改变这组库级统计，原接收目录入口继续保留。
定向 3 个测试、
完整 macOS 103 个测试、应用 verify 和 `git diff --check` 均通过；真实窗口已确认
185pt 侧栏中统计和目录入口完整可见。详见
`batches/2026-07-14-B26-macos-sidebar-library-summary.md`。这次局部视觉检查不关闭 M3
仍待执行的全量 GUI QA。

B25 同步范围与双端停止控制已在 `main` 的 `b0092d1` 工作基线上完成并提交为
`54ff01b`。
Android 队列现在与最新相册白名单 reconcile，并按确认页 stable ID 快照上传，修复
重选相册后旧任务仍上传；传输详情折叠时不再重建全部任务行，错误横幅 5 秒收起，
传输卡新增可中断当前请求的“停止”。macOS 工具栏/传输卡新增“暂停接收”，接收端
处理 peer `.cancelled` 并清理活动项和 `.part`。Android 测试/构建、macOS 101 个
测试、应用 verify、最终 APK 安装/启动和无线真机双端停止链路已通过。
真机联调期间有 6 个已开始的小文件完成落盘。详见
`batches/2026-07-14-B25-sync-scope-stop-controls.md`。
本轮最终已确认手机目标为 `http://192.168.1.23:8765/uploads/`；不要沿用 B22/B23
记录中的历史 `192.168.1.6` 地址。

B24 地址二维码配置已在 `main` 的 `b0092d1` 工作基线上完成并提交为 `54ff01b`。
macOS 工具栏新增二维码入口，二维码承载 `androidsync://configure?url=...`；
Android 注册对应
`VIEW`/`BROWSABLE` 深链，扫码打开后只接受有效 HTTP/HTTPS 目标并写入既有
`target_url`。Android 测试/APK 构建、macOS 组合套件最终 101 个测试和应用 verify
已通过；APK 已安装到无线 ADB 设备 `22081212C`，冷启动与前台 `onNewIntent` 两条
深链路径均已从界面
层级确认，测试后地址恢复到 `http://192.168.1.6:8765/uploads/`。仍需人工使用系统相机
扫描真实二维码。详见
`batches/2026-07-14-B24-address-qr-configuration.md` 和风险 R-012。

B23 QA 修复已完成（提交 `7c2c0c6`）：针对 2026-07-08 真机/GUI 反馈，Android
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
（含 880pt 最小宽度）。用户报告的"传输时胶囊不可见"在新构建上未复现，历史上曾疑为
旧安装包（v0.1.2 无胶囊）；仍由最终 GUI QA 覆盖，不把该局部证据当作全量验收。

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
