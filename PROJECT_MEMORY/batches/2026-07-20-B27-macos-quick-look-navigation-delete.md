# B27：macOS Quick Look 连续预览与键盘删除

日期：2026-07-20

## 目标

修复空格 Quick Look 切换反应慢、不跟手的问题，并增加左右方向键连续预览与 Delete
删除。

## 范围

- Quick Look 数据源从单个 URL 改为当前筛选结果的稳定 URL 快照。
- 左右方向键直接更新 `QLPreviewPanel.currentPreviewItemIndex` 和媒体库选中项，不重复
  present 或 reload 面板。
- Quick Look 内按 Delete 复用 `AppModel`/`LibraryRepository` 删除路径；成功后才从
  预览数据源移除当前项目并选择相邻项目。
- 媒体库获得键盘焦点时，网格左右逐项、上下按列数跨行，列表方向键逐项移动并滚动到
  新选中项；Delete 删除当前未删除选中项。
- 增加 Quick Look 索引切换、删除后就地刷新及 repository/tombstone 集成回归测试。

## 非目标

- 不替换系统 Quick Look 面板或缩略图生成器。
- 不改变筛选、排序、多选、重命名或 Inspector 行为。
- 不改变文件存储布局、manifest 格式或删除 tombstone 语义。

## 风险和决策

- R-008：删除继续追加 tombstone，不擦除或压缩 `uploads.jsonl`。
- R-011：删除继续写入 `MediaItemEntity.removed`，未引入新的 SwiftData 删除属性。
- ADR-005：继续保留追加式 manifest 与 tombstone。
- ADR-007：作为可独立验证的 macOS UX 批次记录。

## 不变量

- 只有未删除项目进入 Quick Look 连续预览数据源。
- 文本输入框或重命名弹窗获得焦点时，媒体库空格/Delete 快捷键不触发。
- 主媒体库方向键在文本输入或 Quick Look key window 中不触发。
- repository 删除成功前不从 Quick Look 数据源移除项目；失败时保留当前预览并显示
  既有错误。
- 删除仍移到系统废纸篓并保留 manifest tombstone，避免 Android 重传。
- 接收协议、上传生命周期和 Android 行为不变。

## 验证

```bash
swift test --package-path macos --filter QuickLookPreviewTests
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

结果：

- 定向 `QuickLookPreviewTests` 运行 11 个测试并全部通过，包括方向键切换不重复
  present/reload、Delete 删除后选择相邻项，以及真实 `LibraryRepository` tombstone
  删除集成。
- 完整 `swift test --package-path macos` 运行 108 个测试，全部通过。
- `./macos/build_and_run.sh verify` 通过，应用包完成构建和签名替换。
- `git diff --check` 通过。
- 审查修复了 Backspace key code 未正确受 `isARepeat` 约束的问题；修复后编译警告消失。
- 真实窗口已确认空格打开/关闭 Quick Look，右方向键从
  `MVIMG_20260708_125055.jpg` 连续切换到 `wx_camera_1783417673985.jpg`。
- 未在真实媒体上执行 Delete；Quick Look Delete、repository 移除和 manifest
  tombstone 由临时目录集成测试验证。主媒体库方向键由注入的 AppKit 事件监听器回归
  测试覆盖，仍建议用实体键盘补做一次交互冒烟。

## 回滚

回滚 `QuickLookPreview` 的多 URL 数据源/键盘事件、`AppModel` 预览删除桥接、
`LibraryView` Delete 快捷键、相关测试与文档。回滚不会恢复已经由用户移到废纸篓的
媒体，也不会移除已写入的 tombstone。

## 结果

- 提交：`54ff01b`。
- 结果：实现、定向/完整自动化、应用 verify 和 Quick Look 真实窗口交互检查已完成。
- 后续：用实体键盘补做主媒体库方向键和 Delete 冒烟；为避免破坏真实媒体，本批没有
  在 GUI 中执行 Delete。
