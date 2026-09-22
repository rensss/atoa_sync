# B37：原生接收端暂停与恢复

日期：2026-09-22

## 目标

Mac 暂停接收时让 Android 当前 run 进入可取消的等待；Mac 恢复后从头重传被中断的同一文件，
继续后续任务。暂停不能被误判为普通网络失败，也不能因部分 PUT 产生有效短文件或遗留暂存文件。

## 范围

- macOS `ReceiverService` 增加原生暂停状态与 pause epoch；暂停保留 `NWListener`、根端点和
  `/health` 控制通道；暂停期间的新 PUT 返回 503 `receiver_paused`。
- macOS 只取消尚未收完整请求体的上传并清理 `.part`；完整请求体已进入 repository 提交阶段时，
  允许存储完成并返回成功。恢复复用同一服务和端口。
- Android 精确识别 `service: Android Sync Receiver` 后使用 `/health` 进行预检和中断分类。
  只有 `pausing`/`paused` 或 pause epoch 变化证实暂停时，当前任务才回到 `WAITING`；恢复后从
  文件开头重传同一任务，不推进批次索引、不计失败。等待过程响应用户 Stop。
- Android 通用 WebDAV/HTTP 和普通网络错误维持原有单次尝试/失败后继续策略；不增加持久化状态、
  通用重试、字节级续传、WorkManager 或第三方依赖。
- macOS AppModel、菜单栏、状态胶囊、工具栏和传输卡统一映射暂停/恢复状态；被丢弃文件的部分
  字节从批次剩余量扣回，不算完成或失败。
- 更新 ADR、项目状态、交接、架构、风险登记及 Android/macOS README；保留 spec 和执行计划。

## 非目标

- 不改变稳定 ID、manifest、HTTP 上传元数据、存储布局、命名、删除历史或批次总量协议。
- 不为一般 HTTP/WebDAV 错误自动重试，不做断点续传或任意目标的接收控制。
- 不把源代码测试或应用构建称为 Android/Mac 真机端到端验收；本批不关闭 M1、M2、M3 里程碑。

## 风险和决策

- R-004：暂停中断必须清理 `.incoming/*.part`，接收请求体不完整时绝不提交短文件。
- R-007：完整尺寸校验和原子提交继续作为文件有效性边界；提交已开始时要完成并向 Android 返回成功。
- R-009：Android 前台服务在暂停等待中仍须响应用户 Stop；真机生命周期行为仍需验证。
- R-015：只有原生服务标识及健康状态/pause epoch 正向证据允许暂停重传，普通错误保持原始失败路径。
- R-016：中断文件从 macOS 活动进度移除，但没有增加通用 batch ID 或 run 结束事件；两 PUT 间取消和
  并发发送方隔离仍是开放问题。
- ADR-010 仅 supersede ADR-008 中对“明确由原生 macOS 暂停导致的同文件重传”的每文件一次尝试约束；
  ADR-008 的前台服务/SQLite 所有权、整文件 PUT 及其他后果保持不变。

## 不变量

- 暂停不销毁 listener 或更换端口；`/health` 包含 `status`、`receiver_state`、`pause_epoch`。
- 只有已确认的原生 Android Sync Receiver 支持 pause-aware waiting；健康查询故障本身不是暂停或恢复证据。
- `pause_epoch` 必须从 JSON 数值精确解析为非负 `long`；小数、负数和溢出值都按无效健康响应处理，
  不能用截断值制造伪 epoch 变化。
- 被暂停中断的 Android 当前任务回到 `WAITING`，不推进 batch index；恢复后从文件开头重传。
- 普通网络失败继续标记失败；通用 WebDAV 不获取暂停自动恢复语义。
- Android Stop 可取消暂停等待并结束 run；后续 Mac 恢复不能重启该 run。
- 完整进入 repository 提交阶段的文件完成存储；不完整 PUT 清理 `.part` 且不产生完成记录。
- 被丢弃上传的部分字节从 macOS 任务进度中回退，其他活动上传和已完成计数不被改写。

## 验证

验证日期：2026-09-22。平台自动化在 `main` 上的 B37 实现检查点
`492a4edddadc62f2daa9afc1493bcef55739cb2e` 执行；文档正在同批写入，未推送。

```bash
./android/run_tests.sh
./android/build.sh
swift test --package-path macos
./macos/build_and_run.sh verify
git diff --check
```

- `./android/run_tests.sh`：退出码 0；`AlbumFilterTest`、`AddressConfigurationTest`、
  `HttpFileUploaderTest`、`ReceiverControlClientTest` 均通过。
- `./android/build.sh`：退出码 0；生成忽略的 `android/build/AndroidSync-debug.apk`。
- `swift test --package-path macos`：退出码 0，143 tests、0 failures；包括 17 个
  `ReceiverServiceTests`、19 个 `AppModelReceiverTests`、10 个 `TransferCardStateTests`。
- `./macos/build_and_run.sh verify`：退出码 0；debug 应用构建、签名并完成 verify 启动流程。
- 独立只读审查第一轮发现两项问题并已修复：pause cleanup 延迟到 listener failure 后不得广播旧
  `.paused`；`pause_epoch` 必须精确表示非负整数，避免小数截断伪造 epoch 变化。Android 与 Swift 回归
  测试先失败，修复后通过；修复提交为 `5864a95`、`c2b1aaa`。复审进一步指出接近整数的小数会先由
  Android JSON parser 舍入；现仅接受 `Integer`/`Long`，并加入 `0.99999999999999999` HTTP 回归用例，
  修复提交为 `492a4ed`。相同只读审查者确认 rounded-fraction 问题关闭，最终复审未发现新的
  Critical/Important 问题。
- 复审说明：listener failure 竞态通过生命周期 predicate 的单元测试及源代码事件顺序检查确认；该测试
  未端到端驱动“延迟 prepare callback → listener failure → 迟到 cleanup”完整回调序列。真机竞态验收仍未做，
  故不把该证据表述为运行时/设备复现。
- `git diff --check`：退出码 0。最终提交范围仅含 B36 批次记录订正、B37 决策/状态/架构/风险/
  交接/批次文档、平台 README、设计规格和实施计划；Android APK 位于忽略的 `android/build/`，
  `dist/` 亦为忽略目录，均未暂存。
- 未执行 Android 无线调试安装、真机暂停/恢复/停止、文件系统完整性或成功传输验收；上述真机项目仍开放。

## 回滚

按依赖顺序反向撤销实现提交：`492a4ed`、`c2b1aaa`、`5864a95`、`8cd83ee`、`3ff1338`、`9faf4b4`、`4c97b26`；不要撤销先行
基线 `6ca48f6`。文档/ADR 可单独回滚。协议状态字段只被新 Android 客户端用于可选识别，去掉暂停控制后
仍保留已有 `/health` 和 PUT 行为；无需数据迁移，也不要删除接收目录中的用户媒体。

## 结果

- 实现提交：`4c97b26`、`9faf4b4`、`3ff1338`、`8cd83ee`、`5864a95`、`c2b1aaa`、`492a4ed`。
- 文档提交：待首个 B37 文档提交 SHA 核验后在记录校正提交中补入。
- 结果：Android 测试/构建、macOS 143 项测试、macOS app verify 和 `git diff --check` 通过；真机暂停/恢复/停止仍待执行。
- 后续：用户在 Android 与 Mac 真机验证暂停时丢弃并从头重传当前文件、恢复后同 run 续传、暂停等待时 Stop 生效、无重复落盘且无 `.part` 残留。R-004/R-007/R-009/R-015/R-016 保持登记状态。
