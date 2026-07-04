# B04：macOS 幂等删除处理

日期：2026-06-22

## 目标

避免对已移除接收文件重复执行删除操作时，向用户显示 “The received file no longer
exists.” 错误。

## 范围

- 让 `LibraryRepository.delete` 容忍缺失媒体文件：活动文件缺失时视为删除请求完成，
  并写入 tombstone。
- 删除已经标记为 deleted 的 `UploadRecord` 时执行 no-op。
- 为缺失文件删除和重复删除已删除记录增加 repository 回归覆盖。

## 非目标

- 不改变缺失文件的重命名行为。
- 不改变 manifest tombstone 语义或 Android reconciliation。
- 不改变仍存在文件的废纸篓处理。

## 风险和决策

- 风险：R-008；删除/tombstone 行为受 ADR-005 约束。
- 未改变 `04_DECISION_LOG.md` 中的受保护决策。

## 不变量

- 缺失文件的重命名行为不变。
- manifest tombstone 语义与 Android reconciliation 不变。
- 仍存在文件的废纸篓（trash）处理不变。
- `LibraryRepository` 的唯一目标命名保持。

## 验证

在 `/Users/ios_k/Desktop/PProject/Android_sync` 运行：

```bash
swift build --package-path macos
```

构建成功完成。

`swift test --package-path macos` 最初编译并运行 macOS 测试套件到足以暴露新增回归
测试在旧删除实现上失败。修复后，多次运行
`swift test --package-path macos --filter LibraryRepositoryTests` 均构建成功，但在
启动 XCTest runner 时挂起，包括在 sandbox 内和提升权限后。无法用直接
`xcrun xctest` 替代，因为 macOS 以 `library load denied by system policy` 拒绝未
签名的 SwiftPM 测试包。

## 回滚

回滚 `LibraryRepository.delete` 改动及相关测试新增内容。这会恢复先前行为：缺失
文件导致 `LibraryRepositoryError.missingFile`。

## 结果

- 提交：`fee8063`
- 结果：实现和回归测试已存在；构建验证通过。XCTest 执行仍受上述本地 runner/
  系统策略问题阻塞。
