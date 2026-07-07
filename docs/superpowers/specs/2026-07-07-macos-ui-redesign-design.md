# macOS 端 UI/UX 重设计

日期：2026-07-07
状态：已获用户批准的设计（spec），实施计划另行制定
范围批次：待编号（B10 起，见"批次划分"）

## 背景与动机

用户对现有界面的不满覆盖视觉、交互流程与信息层级，要求全面重做。重设计
覆盖 Android 与 macOS 两端；本 spec 只覆盖 macOS 端，Android 端另出 spec。
macOS 端先行：最近实现工作集中在 macOS，且视觉语言定稿后 Android 端跟随。

## 已确认的设计决策

通过 visual companion mockup 对比确认：

1. **视觉方向**：专业深色媒体工作台（Lightroom/Final Cut 方向）打底，
   融合卡片式传输状态（云盘方向）。
2. **传输卡片位置**：内容区网格上方横排卡片行；接收时出现，空闲自动收起。
3. **深色策略**：强制深色（`.preferredColorScheme(.dark)`），不跟随系统。
4. **功能范围**：现有功能全保留（网格/列表、搜索、Inspector、重命名、
   Quick Look、Finder 显示、删除、设置、菜单栏图标、复制地址、暂停/启动），
   新增侧栏分类计数、传输卡片行（进度/今日统计/速度）、空闲自动收起。
5. **实施路径**：渐进重构 View 层。AppModel 状态结构、数据层、
   ReceiverService 不动（唯一例外：最后一个批次为进度回调扩展
   ReceiverService 上报接口）。

## 非目标

- Android 端界面（另出 spec）。
- 协议变更中需要 Android 配合的部分（设备名 header）只做 macOS 侧的
  读取与回退显示，Android 侧写入归 Android spec。
- 浅色主题。
- 功能增删（上述新增状态展示元素除外）。

## 窗口布局与信息架构

```
┌─ 工具栏（原生，深色）: 布局切换 | 搜索 | Inspector 开关 | 状态胶囊 ─────┐
├─ 侧栏(深) ──────────┬─ 内容区 ─────────────────────────────┤
│ LIBRARY             │ ┌ 传输卡片行（仅接收时出现，动画收起）┐ │
│  全部      1,204    │ │ [接收进度卡]  [今日统计卡]          │ │
│  照片        986    │ └────────────────────────────────────┘ │
│  视频        218    │                                        │
│                     │  缩略图网格（满宽，深底无边框）         │
│ 底部: 接收文件夹     │  （或列表视图）              [Inspector]│
└─────────────────────┴────────────────────────────────────────┘
```

- `NavigationSplitView` 骨架保留。
- 顶部 `ReceiverStatusView` 状态横条删除，职责拆分：
  - 运行状态 → 工具栏 **StatusCapsule**（● 状态点 + 文案；点开菜单含
    暂停/启动、复制地址、端口信息）。
  - 传输进度 → **TransferCardRow** 卡片行。
- 侧栏分类右侧显示计数徽标。
- 卡片行状态机：空闲 = 高度 0；接收中 = 进度卡 + 今日统计卡；
  全部完成后显示"已完成 N 项"停留约 3 秒再动画收起。
- Onboarding、菜单栏图标、设置保留原职责，仅换视觉。

## 传输卡片的数据来源（数据真相）

`ActiveUpload` 现有字段仅 `id`、`filename`、`expectedSize`；接收请求中
没有设备标识；没有字节级进度或速度。因此：

| 展示项 | 数据来源 | 可用时点 |
|---|---|---|
| 接收中文件数、预计总大小 | 现有 `activeUploads` | 立即 |
| 今日统计（N 项 / 字节数） | 库存条目 `receivedAt` 聚合 | 立即 |
| 侧栏分类计数 | 现有条目聚合 | 立即 |
| 字节级进度、速度 | `ReceiverService` 新增进度回调 | 批次 6 |
| 设备名 | 协议新增 header（Android 侧写入） | Android 批次后 |

回退显示：进度回调到位前，进度卡显示"接收中 N 个文件 · 预计 X MB"与
不确定进度条；设备名读不到 header 时显示"Android 设备"，读到后自动升级。

## 主题 token（`Support/Theme.swift`，新建）

全部视图只从 Theme 取值，不散落硬编码：

- **色板**：`bg`（窗口 #1E1E23 系）、`bgRaised`（卡片 #2B2B31）、
  `bgSidebar`（#1C1C21）、`stroke`、`textPrimary` / `textSecondary`、
  `accent`（选中描边琥珀 #E8A33D）、`cardGradient`（进度卡蓝紫渐变）、
  状态色（运行绿 / 暂停灰 / 失败红）。
- **尺寸**：间距 4/8/12/16；圆角 6/10；网格缝隙 3pt；计数用等宽数字字体。
- 强制深色在 App 入口生效，设置窗口、菜单栏 popover、各 sheet 同样生效。
- 现有 `ThumbnailMetrics` 并入或对齐 Theme，不留两套常量。

## 组件改动清单

| 组件 | 动作 |
|---|---|
| StatusCapsule | 新建：状态点 + 文案 + 菜单（暂停/启动、复制地址、端口） |
| TransferCardRow | 新建：进度卡 + 今日统计卡，出现/收起动画，完成停留 3 秒 |
| SidebarView | 深色样式 + 分类计数徽标，底部文件夹按钮保留 |
| LibraryView 网格 | 高密度：缝隙 3pt、缩略图不带文件名标签（悬停 tooltip + Inspector 看详情），选中琥珀描边 |
| LibraryView 列表 | 保留文件名/日期/大小行，深色重排 |
| ThumbnailView | 视频加时长角标，已删除条目变暗保留 |
| InspectorView / RenameSheet / SettingsView / OnboardingView / MenuBarView | 功能不动，深色重样式 |
| ReceiverStatusView | 删除（职责迁移至 StatusCapsule 与 TransferCardRow） |

## 交互与错误处理

- 不变：双击预览、空格 Quick Look、⌘ 多选、右键菜单、搜索、重命名流程。
- `lastError` 的 alert 流程不动。
- `transientUploadMessage` 从状态条副标题改为卡片行内一条红/琥珀色短横幅，
  自动收起。

## 批次划分（每批独立可审查、可回滚）

1. Theme + 强制深色 + StatusCapsule（删除状态条，职责迁移）。
2. 侧栏：深色样式 + 分类计数。
3. TransferCardRow（现有数据版：文件数 + 预计大小 + 今日统计 + 横幅）。
4. 网格 / 列表 / ThumbnailView / Inspector / RenameSheet 重做。
5. 设置 / Onboarding / 菜单栏深色化。
6. ReceiverService 进度回调 → 字节进度条 + 速度（唯一触及 Services 的批次）。

## 测试与验收

- 每批：`swift test --package-path macos`（现有 78 个测试保持绿）+
  `./macos/build_and_run.sh verify`。
- 新增逻辑测试：分类计数、今日统计聚合、卡片行状态机
  （空闲 / 接收中 / 完成停留）。
- 纯样式改动无自动化视觉验证；以桌面截图人工 QA，口径与
  `PROJECT_MEMORY/milestones/M3_macos_ux.md` 一致。

## 风险与依赖

- 批次 1 删除状态条后，若 StatusCapsule 遗漏原状态条的某个状态文案
  （needsDirectory / starting / failed），状态可见性回退——批次 1 验收
  必须逐状态核对五种 `ReceiverStatus`。
- 批次 6 触及 ReceiverService，须复核 `PROJECT_MEMORY/02_RISK_REGISTER.md`
  中并发与生命周期相关风险行，批次记录列出风险 ID。
- 本地存在未提交的 B09 改动（删除标记修复）；本 spec 的实施批次不得
  混入 B09 变更，B09 先行提交。
- M3（macOS UX）里程碑的视觉 QA 口径将因本重设计更新；实施完成前
  不宣称 M3 关闭。
