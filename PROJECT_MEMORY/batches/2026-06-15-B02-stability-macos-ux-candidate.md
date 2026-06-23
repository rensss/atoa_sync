# B02：稳定性和 macOS UX 候选实现

日期：2026-06-15

## 目标

记录已批准 Android 稳定性和 macOS UX 计划的完成候选实现及自动化验证。

## 范围

- Android 缩略图内存、请求合并、生命周期保护、队列刷新、排序和同步代次。
- macOS 本地化、工具栏位置、缩略图布局、Quick Look、失败上传清理、接收端
  生命周期串行化、设置和版本数据。
- 回归测试、平台文档、打包和 changelog 条目。

## 非目标

- 不把候选分支合并到 `main`。
- 没有真机压力测试前，不关闭 Android 稳定性里程碑。
- 没有交互式 GUI 检查前，不宣称 macOS 最终视觉验收完成。
- 不改变局域网认证或明文传输策略。

## 风险和决策

- 风险：R-001、R-002、R-004、R-005。
- 未改变 `04_DECISION_LOG.md` 中的受保护决策。

## 不变量

- Android 队列锁内仍不执行 bitmap 解码和网络 I/O。
- macOS 上传仍暂存为 `.part` 文件，并在提交前校验。
- 唯一目标命名和容错 manifest 解析保持不变。
- 接收端仍限制在可信本地网络内使用。

## 验证

在候选提交 `cbf31db` 的
`/Users/ios_k/Desktop/PProject/Android_sync/.worktrees/stability-macos-ux`
运行：

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
swift build --package-path macos -c release
bash -n macos/build_and_run.sh
./macos/build_and_run.sh verify
plutil -lint "dist/Android Sync.app/Contents/Info.plist"
codesign --verify --deep --strict "dist/Android Sync.app"
git diff --check
```

所有命令均成功退出。macOS 套件运行 75 个测试。应用包报告版本 `0.1.2`、构建号
`35`，并通过严格 deep code-signature 验证。Android APK 成功生成。

独立最终代码审查发现并推动修复了 Quick Look 键盘事件路由、预览 observer 生命周期
和 Android 首页网格状态刷新问题。最终审查批准 `cbf31db`，没有阻塞问题。

`adb devices -l` 报告没有连接设备。自动化会话也无法捕获 macOS 显示画面，因此真机
压力测试和最终视觉 QA 是明确后续事项。

## 回滚

不要合并 `codex/stability-macos-ux`，或在合并后把其集成提交作为整体回滚。本批次
未引入持久数据迁移。如果单独移植 macOS 提交，应保留失败上传清理行为。

## 结果

- 提交：候选 `cbf31db`；已于 2026-06-22 合并到 `codex/agent-governance` 的
  `23b09d5`，随后合并到 `main` 的 `8a09aa0`。
- 结果：实现、候选自动化验证和合并提交自动化验证已完成；验收仍受设备/GUI 证据阻塞。
- 后续：运行缺失的人工检查并记录最终验收证据。
