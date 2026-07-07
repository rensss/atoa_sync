# B11：macOS 侧栏分类计数与深色样式（UI 重设计批次 2/6）

日期：2026-07-07
分支：`codex/macos-ui-redesign`
提交：`45c101c`（侧栏计数与深色样式）、`78a55a4`（计数测试日期判别性补强）
依据：`docs/superpowers/plans/2026-07-07-macos-ui-redesign.md`（Task 4）

## 改动

- `AppModel` 新增 `categoryCount(_:)`：库级分类计数，固定
  `dateFilter: .all`、`searchText: ""`，不受当前搜索与日期过滤影响。
- `SidebarView`：分类行计数徽标（等宽数字、`Theme.textSecondary`），
  `.scrollContentBackground(.hidden)` + `Theme.bgSidebar` 深色背景，
  底部接收文件夹按钮保留并按 Theme token 重排。

## 验证

- `swift test --package-path macos`：84 个测试全绿（新增
  `AppModelSidebarCountTests`；修复提交后复跑通过）。
- `./macos/build_and_run.sh verify` 通过。
- 审查发现计划自带测试 fixture 全部 `receivedAt = now`、日期维度无判别力
  （plan-mandated），已用 60 天前条目补强并复审确认。

## 风险

- 未新增风险 ID。纯视图与只读计算属性。

## 不变量

- 接收协议、存储布局、`AppModel` 既有过滤/排序行为不变。
- 未新增第三方依赖。
