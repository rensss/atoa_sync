# 重构路线图

## 执行规则

工作以可独立验证的批次推进。不要把 Android 稳定性、macOS UX、协议变化和存储
迁移混进同一个批次。

## Phase 0：仓库和接收端收敛

状态：完成并冻结。

- 将 Android 和 macOS 所有权拆分到平台目录。
- 移除废弃 Python 接收端。
- 将原生 macOS 接收端设为受支持的电脑端实现。
- 验证两个平台的构建和测试命令。

冻结记录：`freezes/phase0_freeze.md`

## Phase 1：Android 运行时稳定性

状态：已在 `8a09aa0` 实现并合并到 `main`；真机压力测试仍未完成。

- 限制网格和预览解码尺寸。
- 增加有界缩略图缓存和请求合并。
- 避免视图复用或生命周期变化后交付过期缩略图。
- 原地更新队列行和汇总。
- 隔离过期同步代次。
- 使用单元测试、APK 构建和真机压力测试验证。

退出标准定义在 `milestones/M1_android_stability.md`。

## Phase 2：macOS 接收端正确性

状态：已在 `8a09aa0` 实现到 `main`；最终 QA 期间继续观察。

- 区分 listener 失败和单个上传失败。
- 保证中断和失败时清理临时文件。
- 增加接收端生命周期和中断上传回归覆盖。
- 保留原子提交、元数据、唯一命名和 tombstone。

## Phase 3：macOS UX 和应用测试

状态：已在 `8a09aa0` 实现到 `main`；最终视觉/交互 QA 仍未完成。

- 采用原生工具栏结构和稳定缩略图布局。
- 增加运行时中英文本地化。
- 完成搜索、排序、Inspector、Quick Look 和设置行为。
- 增加 `AndroidSyncMacTests` target，覆盖应用状态和本地化逻辑。

## Phase 4：安全和运维加固

状态：未来工作。

- 决定认证和传输安全要求。
- 增加 Android 测试/构建和 Swift 测试/构建的 CI。
- 定义 manifest compaction 和恢复机制。
- 定义队列持久化和可恢复同步要求。
- 建立签名发布和 checksum 发布流程。

## 范围边界

- 没有批准 ADR 时，不要替换无第三方依赖的 Android 构建方式。
- 没有批准 ADR 时，不要替换 SwiftPM/SwiftUI/SwiftData。
- UI 工作期间不要顺手更改上传协议或存储布局。
- 阶段里程碑文件没有目标提交的通过证据前，不要宣称阶段完成。
