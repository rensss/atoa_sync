# B26：macOS 侧边栏媒体库概览

日期：2026-07-14

## 目标

在 macOS 主窗口侧边栏底部增加媒体库脚视图，持续展示照片、视频、其他文件数量和
媒体总占用空间。

## 范围

- `AppModel` 从当前 `items` 单次汇总未删除媒体的分类数量和 `sizeBytes`。
- `SidebarView` 在侧栏底部展示三类数量、格式化总占用和既有接收目录入口。
- 新增简体中文、英文文案和统计回归测试。
- 更新 macOS 使用说明、项目状态和交接记录。

## 非目标

- 不扫描整个接收目录或系统磁盘；“已占用”只表示当前 manifest/媒体库中未删除媒体的
  原始文件字节总数，不包含 sidecar、manifest 和其他应用文件。
- 不改变侧栏分类计数、搜索、日期筛选或排序行为。
- 不改变接收协议、存储布局、上传生命周期或删除 tombstone 语义。
- 本批次的局部窗口检查不替代 M3 全量视觉/交互 QA。

## 风险和决策

- 已复核 `02_RISK_REGISTER.md`；本批次不触及网络、接收生命周期、临时文件、manifest
  解析、删除写入或媒体解码，没有新增风险 ID。
- 遵循 ADR-003（保留 SwiftPM/SwiftUI/SwiftData）和 ADR-007（批次治理式演进）。

## 不变量

- 统计只读消费 `AppModel.items`，不创建第二份可变媒体状态。
- 已删除项目不计入分类数量和占用；负数异常尺寸按 0 字节处理，总和溢出时饱和到
  `Int64.max`。
- 搜索、日期和当前分类不会改变媒体库级概览。
- 接收目录按钮仍打开既有 `receiveDirectory`。

## 验证

```bash
swift test --package-path macos --filter AppModelSidebarCountTests
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

结果：定向 3 个测试通过；完整 103 个测试通过，0 失败；应用打包、签名和启动验证
通过；`git diff --check` 通过。通过真实应用窗口检查确认 185pt 侧栏底部可见照片 606、
视频 18、其他文件 0、已占用 5.8 GB，接收目录入口未被裁切。

## 回滚

移除 `SidebarView` 的概览区域、`AppModel.SidebarLibraryStats`、两项本地化 key 和对应
测试/文档即可。改动不迁移持久数据，回滚不会影响媒体文件或 `uploads.jsonl`。

## 结果

- 提交：未提交；工作基线 `b0092d1`。
- 结果：侧边栏媒体库脚视图已实现并通过自动化与局部 GUI 检查。
- 后续：与既有 M3 清单一起执行全量 macOS 视觉/交互 QA。
