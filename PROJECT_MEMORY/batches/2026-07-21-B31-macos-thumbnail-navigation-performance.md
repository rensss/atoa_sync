# B31：macOS 方向键滚动缩略图性能

日期：2026-07-21

## 目标

改善首页网格连续使用方向键下移时的滚动跟手性和缩略图出现速度。

## 范围

- 选中项自动滚动从强制居中改为最小距离滚动，只在项目离开视口时移动网格。
- 增加进程内有界缩略图缓存，按文件路径、显示尺寸和屏幕倍率区分缓存项。
- 合并同一缩略图的并发 Quick Look 请求；视图离屏后再次进入时复用已经生成的图片。
- 增加缓存复用、尺寸/倍率隔离和并发请求合并测试。

## 非目标

- 不生成或维护磁盘缩略图数据库。
- 不改变网格尺寸、筛选/排序、Quick Look 或媒体文件内容。
- 不对原始媒体进行转码。

## 风险和决策

- R-013：缩略图缓存限制为 256 项和约 96 MiB；重复请求合并，避免连续滚动时无界
  解码和内存增长。控制措施提交为 `aa4cc87`。
- ADR-003：继续使用系统 Quick Look Thumbnailing 和 SwiftUI，不引入第三方依赖。
- ADR-007：作为独立 macOS UX/媒体解码性能批次记录。

## 不变量

- 缓存只保存派生的 `NSImage`，不写入或修改用户媒体。
- 不同文件、显示尺寸和屏幕倍率不能错误复用同一缓存项。
- 缓存被系统回收或未命中时仍回退到系统 `QLThumbnailGenerator`。
- 搜索、排序、选择、删除和 Quick Look 行为保持不变。

## 验证

```bash
swift test --package-path macos --filter ThumbnailLoaderTests
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

结果：

- `ThumbnailLoaderTests` 3 个测试全部通过，覆盖缓存命中、尺寸/倍率隔离和并发请求合并。
- 完整 macOS 套件运行 113 个测试，全部通过。
- `./macos/build_and_run.sh verify` 通过并启动签名应用包。
- 真实首页网格从首项连续按 12 次下方向键，在约 2.3 秒内完成跨行移动；最终可见区域
  仅观察到 1 个未就绪缩略图。向上返回后再次向下移动继续复用缓存。
- `git diff --check` 通过。

## 回滚

移除 `ThumbnailLoader` 和对应测试，让 `ThumbnailView` 恢复逐视图直接请求 Quick
Look 缩略图，并把 `scrollTo` 恢复为居中 anchor。回滚不触及用户媒体或持久数据。

## 结果

- 实现提交：`aa4cc87`。
- 结果：实现、自动化、应用 verify 和真实窗口连续方向键检查已完成。
