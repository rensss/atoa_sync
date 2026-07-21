# B30：macOS 标题栏折叠搜索

日期：2026-07-21
分支：`main`
工作基线：B29 未提交工作区（Git `HEAD` 为 `9269afc`）
提交：待提交

## 目标

处理标题栏搜索的后续交互反馈：默认只显示位于标题栏最右侧的搜索按钮，用户激活后
再展开为搜索框，同时保留既有搜索逻辑。

## 范围

- 用 `ContentView` 的显式展示状态替代系统自行展开的 `.searchable`。
- 在统一控制条之后增加独立搜索工具栏项，使收起按钮保持在标题栏最右侧。
- macOS 26 在主操作组与搜索之间插入弹性 `ToolbarSpacer`，把搜索推到窗口最右侧并
  阻止相邻项目共享一整块 Liquid Glass；旧系统不启用该新 API。
- macOS 26 动态控制搜索工具栏项的共享背景：收起状态只显示裸放大镜，展开后的原生
  `NSSearchField` 恢复输入边界。
- 激活后展开原生 `NSSearchField`，并绑定既有 `AppModel.searchText` 实时筛选文件名。
- Escape 先清空查询，再关闭空搜索框；原生清除按钮只清空查询并保持输入焦点。
- 搜索框失去焦点时自动退出激活态并收回按钮；已有查询继续保留并维持筛选结果。
- 为收起按钮保留 Command-F 快捷键；展开后由 AppKit 明确设置 first responder，保证
  鼠标和快捷键两条入口都能直接输入。
- 更新 macOS README、项目状态、交接和 M3 局部 GUI 证据。

## 非目标

- 不改变搜索匹配规则、分类、日期筛选、排序或空结果文案。
- 不改变 B29 统一控制条、接收状态、二维码、删除、布局、设置或 Inspector。
- 不关闭 M3 全量视觉/交互 QA。

## 风险和决策

- 未新增风险 ID；本批只调整 SwiftUI 搜索界面的展示状态。
- ADR-003、ADR-007 保持不变；未引入依赖或替换工具链。

## 不变量

- 搜索文本继续由 `AppModel.searchText` 持有，并通过既有 `filteredItems` 查询实时生效。
- 搜索框激活后立即获得文本焦点；Escape 可清空并收起。
- 点击媒体区、侧栏或其他控件导致搜索框失焦时，搜索框自动收起且不清空查询。
- 有搜索文本时继续显示搜索结果或“没有搜索结果”空状态。
- 其他标题栏操作及媒体库键盘导航逻辑不变。

## 验证

```bash
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

当前结果：

- `swift test --package-path macos` 运行 110 个测试，0 失败。
- `./macos/build_and_run.sh verify` 通过。
- 真实窗口初始只显示标题栏最右侧放大镜；点击后展开 `NSSearchField` 并成为 first
  responder，可直接输入。
- 用户截图反馈主操作组和搜索仍被 macOS 26 合并成超长玻璃胶囊后，增加弹性工具栏
  间隔并隐藏搜索项共享背景；真实窗口复核确认收起状态成为最右侧裸放大镜，展开
  搜索框也在最右侧与主操作组分离。
- 使用真实文件名 `MVIMG_20260708_125055` 验证结果实时收敛为唯一项目；清空后恢复
  624 个项目。
- Command-F 可展开并直接输入；查询非空时第一次 Escape 清空，第二次 Escape 收起。
- 搜索框失去焦点后会自动收起；已有查询文本与筛选结果保持不变。
- `git diff --check`、Info.plist lint 和应用深度签名检查通过。

## 回滚

恢复 `ContentView` 的 `.searchable`，移除 `LibraryToolbar` 的搜索工具栏项和
`ContentView.searchPresented` 状态即可恢复系统自行决定搜索框展示方式。回滚不修改
数据库、媒体、接收目录或 manifest。

## 结果

- 提交：工作区未提交。
- 结果：折叠搜索、焦点和查询链路实现完成，自动化、打包校验和局部 GUI 检查通过。
- 后续：完成 M3 剩余全量 GUI 矩阵。
