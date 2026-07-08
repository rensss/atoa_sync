# Android 端 UI/UX 重设计与文件选择

日期：2026-07-08
状态：已获用户批准的设计（spec），实施计划另行制定
范围批次：B17–B21（见"批次划分"）

## 背景与动机

用户对两端界面要求全面重做；macOS 端已完成（spec
`2026-07-07-macos-ui-redesign-design.md`，分支 `codex/macos-ui-redesign`）。
本 spec 覆盖 Android 端，并纳入两项新需求/遗留项：

1. 文件/目录选择（2026-07-08 用户提出）：现 `MediaStoreScanner.scanAll()`
   无条件扫描全部外部图片+视频（selection 为 null），下载目录中的电影等
   非目标媒体会被同步。
2. B16 大文件上传 OOM 修复（`main` 提交 `fbec5bc`）的真机回归验收。

## 已确认的设计决策

通过 visual companion 线框对比与逐项确认：

1. **结构**：媒体库首页（macOS 镜像）。底部导航缩为两 tab：媒体库 / 设置。
   队列页与详情页删除，职责收编（见下）。
2. **视觉**：与 macOS 端统一——强制深色、同色板 token（底 #1E1E23 系、
   卡片 #2B2B31、描边 #38383F、琥珀 accent #E8A33D、蓝紫渐变
   #4F7CF0→#6A5CD8、间距 4/8/12/16）。
3. **文件选择两层**：
   - 持久层：相册（bucket）白名单，chips 快速过滤 + 全量勾选管理页。
   - 临时层：点"同步"先进确认态，勾选网格默认全选未同步项，点缩略图
     排除，仅本次生效。
4. **实施路径**：渐进重构。MainActivity 的权限、生命周期、SyncQueue 驱动
   逻辑不动（B02 稳定性成果），UI 拆为独立 view 类；不引入第三方依赖。

## 非目标

- macOS 端改动（设备名的 macOS 侧读取已在 macOS spec 预留回退，无需改）。
- 后台自动同步、浅色主题、上传协议变更（仅新增一个请求头）。
- UI 层自动化测试基建（现 JVM harness 只编译 core，维持现状）。

## 页面结构与交互

```
┌─ 媒体库 tab ─────────────────┐  ┌─ 确认态（点⇪后）──────────┐
│ [Camera✓][Screenshots✓][管理] │  │ 待传 11 项 · 点击排除       │
│ ┌ 传输卡片行(空闲收起) ─────┐ │  │ ▦▦▦ 网格勾选模式           │
│ │ 渐变进度卡 | 今日统计     │ │  │ （默认全选未同步项）        │
│ └─(点开→逐文件进度/重试)──┘ │  │                            │
│  三列网格（缩略图）           │  │ [取消] [开始同步 9项·86MB] │
│                    (⇪同步FAB) │  └────────────────────────────┘
├──────────────────────────────┤
│    ▦ 媒体库    |    ⚙ 设置    │
└──────────────────────────────┘
```

- 媒体库页：相册 chips 行（白名单相册 + "管理"入口；点击 chip 只切换
  网格的显示过滤，不改白名单——白名单增删仅在管理页/设置页）→ 传输卡片行
  （空闲高度收起；接收中显示进度/速度/今日统计；失败横幅）→ 三列缩略图
  网格 → 悬浮同步按钮。
- 卡片行展开态承接原队列页：逐文件进度、失败项重试。
- 缩略图点击弹层预览承接原详情页。
- 确认态：底部确认条显示"开始同步（N 项 · X MB）"与取消；排除项变暗
  带 ✕ 角标。
- 设置页：相册白名单管理、目标地址、语言、关于。
- 首次启动：引导页选相册，默认预勾 Camera（DCIM）；未配置白名单前
  不扫描全库。

## 数据与行为

- **白名单**：`Set<bucket ID>` 存 SharedPreferences。
  `MediaStoreScanner` 投影新增 `BUCKET_ID`、`BUCKET_DISPLAY_NAME`，
  新增 `scanAll(Set<String> bucketIds)` 按白名单过滤查询。空白名单 =
  未配置态（触发引导），不回退为全量扫描。
- **临时排除**：确认态排除集合仅存内存，本次同步有效。
- **待传集合计算**：`core/AlbumFilter`（纯逻辑，JVM 可测）——输入扫描
  结果、已同步 stableId 集合、排除集合，输出待传清单与统计。
- **设备名**：`HttpFileUploader` 新增请求头
  `X-Android-Sync-Device: Build.MODEL`。macOS 端读到后把传输卡片的
  "Android 设备"升级为真实型号（macOS spec 已预留，读取实现归 macOS
  后续批次）。

## 代码结构（拆巨石）

MainActivity（1914 行）瘦身为组装器：保留权限、生命周期、SyncQueue
驱动、页面切换；UI 拆出：

| 单元 | 职责 |
|---|---|
| `android/ui/Theme.java` | 色板/尺寸 token，对齐 macOS `Theme.swift` |
| `android/ui/LibraryPageView.java` | chips 行 + 卡片行 + 网格 + FAB |
| `android/ui/ConfirmSelectionView.java` | 勾选网格 + 底部确认条 |
| `android/ui/TransferCardView.java` | 进度卡/统计卡/横幅 + 展开逐文件列表 |
| `android/ui/SettingsPageView.java` | 白名单管理、目标地址、语言、关于 |
| `android/ui/AlbumPickerView.java` | 相册勾选列表（引导与设置共用） |
| `core/AlbumFilter.java` | 白名单判断、待传集合计算（JVM 测试覆盖） |

## 批次划分（编号顺延，每批可回滚）

1. **B17**：Theme token + MainActivity 拆壳——纯搬移不改逻辑，行为不变。
2. **B18**：scanner bucket 过滤 + 白名单持久化 + AlbumPicker/设置页 +
   首启引导。
3. **B19**：确认态勾选 + `AlbumFilter` 逻辑与 JVM 测试。
4. **B20**：传输卡片行（进度/统计/展开/横幅）+ 预览弹层，删队列/详情页。
5. **B21**：设备名 header + 真机 QA（含 B16 大文件回归）。

## 测试与验收

- 每批：`./android/run_tests.sh` + `./android/build.sh` 通过；
  `core/AlbumFilter` 新增 JVM 测试。
- UI 无自动化：每批真机人工 QA 清单收尾；无设备的批次如实记录未验证项，
  不表述为已通过。
- 最终验收（B21）：真机 GB 级视频传输不崩溃、内存平稳（B16 回归）；
  白名单外媒体（如 Download 目录电影）不出现在网格与待传集合；
  确认态排除项不被上传；macOS 端收到 `X-Android-Sync-Device` 头。

## 风险与依赖

- B17 拆壳最易引入行为回归：约束"纯搬移不改逻辑"，审查按此口径；
  B17/B19 批次记录复核 R-001/R-002（Android 稳定性）。
- 队列页/详情页删除属用户可见行为变化，发布说明需记录。
- Android 大文件回归依赖真机；无设备时 B21 不能宣称关闭。
- 与 macOS UI 重设计分支（`codex/macos-ui-redesign`，待合并）无代码
  交集，可并行推进；设备名显示端到端验证需两者都落地。
