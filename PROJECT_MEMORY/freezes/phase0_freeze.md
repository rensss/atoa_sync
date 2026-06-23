# Phase 0 冻结：仓库和接收端收敛

冻结日期：2026-06-08

## 包含的基线

- 提交：`0621390`（`Reorganize Android and macOS projects`）
- Android 实现和原型归属 `android/`
- 原生 Swift package 和接收端归属 `macos/`
- 废弃独立 Python 接收端已移除
- 根目录保留共享项目元数据、发布产物和文档

## 冻结合约

- 原生 macOS `ReceiverService` 是受支持的本地接收端。
- Android 浏览器原型保留在 `android/prototype/`。
- macOS 打包输出保留在根目录 `dist/`。
- 平台构建和测试命令从仓库根目录调用。

## 记录的验证

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
swift build --package-path macos
```

此阶段只能通过新的路线图阶段和 ADR supersede。本文件是历史快照，不得编辑为后续
行为的描述。
