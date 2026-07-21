# B29：macOS 标题栏移除分类胶囊

日期：2026-07-20
分支：`main`
工作基线：`9269afc`
提交：待提交

## 目标

处理 B28 后续 GUI 反馈：macOS 26 会自动给标题栏 `.navigation` 项套用 Liquid Glass
胶囊，导致“全部项目 624”即使改成纯文本仍有假按钮感。移除这份与侧栏重复的信息，
让标题栏只承担状态与操作。

## 范围

- 移除标题栏中的当前分类/数量 `.navigation` 项；分类和数量继续由侧栏选中行显示。
- 把原状态菜单收进右侧统一控制条，并用状态色圆点作为紧凑入口。
- 保留状态菜单中的暂停/开始、复制地址和端口/URL 详情。
- 更新 macOS README、项目状态、交接和 M3 局部 GUI 证据。

## 非目标

- 不改变侧栏分类、筛选后项目数量、筛选/排序或布局逻辑。
- 不改变 `AppModel`、接收器生命周期、二维码、删除、存储或 manifest。
- 不关闭 M3 全量视觉/交互 QA。

## 风险和决策

- 未新增风险 ID；本批只调整 SwiftUI 标题栏视图层级。
- ADR-003、ADR-007 保持不变；未引入依赖或替换工具链。
- macOS 26 的系统 Liquid Glass 外观不通过私有 API规避；删除冗余工具栏项，使用现有
  侧栏作为分类信息的唯一可见位置。

## 不变量

- 侧栏继续显示当前分类与库级分类数量。
- 五种接收状态和活动上传文案继续由既有 `AppModel` 计算属性提供。
- 状态菜单继续调用既有 `toggleReceiver()` 和剪贴板复制逻辑。
- 暂停/开始、二维码、上下文删除、筛选/排序、布局、设置、Inspector 和搜索不变。

## 验证

```bash
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

当前结果：

- `swift test --package-path macos` 运行 108 个测试，0 失败。
- `./macos/build_and_run.sh verify` 通过。
- 真实窗口确认标题栏不再出现“全部项目 624”胶囊；侧栏选中行仍显示“全部项目 624”。
- 状态圆点菜单可打开，包含“暂停”“复制地址”和当前上传 URL；未执行暂停或删除操作。
- `git diff --check`、Info.plist lint 和应用深度签名检查通过。

## 回滚

恢复 `LibraryToolbar` 的分类 `.navigation` 项，并把 `StatusCapsuleView` 移回该项。
回滚不修改数据库、媒体、接收目录或 manifest。

## 结果

- 提交：工作区未提交。
- 结果：分类胶囊已移除，状态逻辑迁移完成，108 个测试、应用 verify、diff/签名检查
  和局部 GUI 检查通过。
- 后续：完成 M3 剩余全量 GUI 矩阵。
