# B09：macOS 已删除条目在列表中复活的修复

日期：2026-07-07

## 目标

修复用户报告的缺陷：在 macOS app 中删除媒体条目后，该条目仍显示在主列表
（“全部”等分类）中；重启应用后同样复活。用户在真实媒体库中对同一条目
（`stable_id` 为 `image:1000103172`）连续执行了 5 次删除，`uploads.jsonl`
中留下 5 条重复 tombstone。

## 根因

`MediaItemEntity`（SwiftData `@Model`）的删除标记属性命名为 `deleted`。该名字
与 Core Data `NSManagedObject` 的保留属性 `deleted`/`isDeleted`（KVC key
`deleted`）冲突，导致 `ModelContext.save()` 静默丢弃写入的值：

- 无论 update 还是 insert 路径，`deleted = true` 在 save 后都会回滚为 `false`，
  且不会持久化到 store。
- repository 层（tombstone 写入、`manifest()` 合并、`libraryRecords()`）行为
  全部正确；缺陷仅在 SwiftData 实体层。
- 已用独立最小复现确认：同一属性改名为 `removed` 后行为完全正常。

## 范围

- `macos/Sources/AndroidSyncMac/Models/MediaItemEntity.swift`：属性 `deleted`
  改名为 `removed`（带默认值 `false` 以支持旧 store 轻量迁移），并注释禁用
  保留名的原因。
- `macos/Sources/AndroidSyncMac/Stores/AppModel.swift`、
  `Views/LibraryView.swift`、`Views/InspectorView.swift`、
  `Views/ThumbnailView.swift`：实体用法同步改名。
- 新增回归测试 `Tests/AndroidSyncMacTests/AppModelDeleteTests.swift`：覆盖
  `configureDirectory → deleteSelected → 过滤/持久化 → 重复删除 no-op` 全流程。

## 非目标

- 不改变 `UploadRecord.deleted`（纯 Swift struct，无冲突）及协议/manifest 语义。
- 不改变 `LibraryRepository` 的删除、tombstone 或幂等语义（B04 行为保持）。
- 不处理 `manifest()` 对无 `stable_id` 记录的 tombstone 回退合并问题（见
  “后续”）。

## 风险和决策

- 相关风险：R-011（本批次新增并缓解）；R-008（触及 manifest 消费方，未改语义）。
- 删除/tombstone 语义受 ADR-005 约束，本批次未改变。
- 未改变 `04_DECISION_LOG.md` 中的受保护决策。

## 不变量

- `uploads.jsonl` 格式、tombstone 语义与 Android reconciliation 不变。
- `LibraryRepository.delete` 的幂等行为（B04）不变。
- “已删除”分类继续显示 tombstone 条目；其余分类排除已删除条目。
- 旧 `default.store` 可无损打开（轻量迁移新增 `removed` 列，默认 `false`；
  启动时 `syncDatabase` 会从 manifest 重建正确标记）。

## 验证

在 `/Users/ios_k/Desktop/PProject/Android_sync` 运行：

```bash
swift test --package-path macos        # 78 个测试全部通过
./macos/build_and_run.sh verify        # 打包与签名成功
```

- 新增回归测试在修复前失败（实体在 `deleteSelected` 后仍为未删除），修复后
  通过。
- 独立最小复现（临时 SwiftPM 包）确认：`var deleted: Bool` 在 save 后回滚且
  不持久化；`var removed: Bool` 正常。insert 与 update 路径均已验证。
- 用真实 `~/Library/Application Support/default.store` 的副本验证轻量迁移：
  新 schema 打开成功（78 个实体），`removed` 写入后在新 `ModelContext` 中
  可读回 `true`。
- 用真实 `uploads.jsonl` 副本验证 `libraryRecords()` 对 tombstone 条目返回
  `deleted=true`（repository 层本就正确）。

## 回滚

回滚上述源码文件与测试新增内容即可恢复先前行为（缺陷随之恢复）。旧 store 中
新增的 `removed` 列对回滚后的旧 schema 无影响（Core Data 忽略未知列需重新
迁移；如有异常可删除 `default.store*`，实体会在启动时从 `uploads.jsonl`
重建）。

## 结果

- 提交：待回填
- 结果：实现与回归测试完成；完整 macOS 测试套件（78 个）通过；打包验证通过。
- 后续：`LibraryRepository.manifest()` 对无 `stable_id` 的记录会丢弃其
  tombstone（`fallback` 只收集未删除记录），此类条目依赖文件缺失推断删除；
  当前 Android 上传均带 `stable_id`，暂不构成用户可见缺陷。
