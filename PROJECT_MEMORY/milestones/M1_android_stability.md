# M1：Android 运行时稳定性

状态：进行中

## 进入标准

- [x] 稳定性设计和实施计划已存在。
- [x] 当前 Android 测试和构建命令已记录。
- [x] 相关风险 R-001 和 R-002 已登记。

## 退出标准

- [x] 网格缩略图请求限制在显示级尺寸内。
- [x] 预览请求有已记录的上限。
- [x] 缩略图缓存有严格内存/条目上限。
- [x] 重复解码请求会被合并。
- [x] 过期异步缩略图结果不能更新复用或已分离视图。
- [x] 队列状态和分页更新不会重建整个屏幕。
- [x] 过期同步代次不能修改当前运行。
- [x] `./android/run_tests.sh` 在目标提交通过。
- [x] `./android/build.sh` 通过并验证 APK 签名。
- [ ] 真机压力测试覆盖大型媒体库、快速导航、前后台切换和重复开始同步。
- [ ] 未观察到 OOM、ANR、队列状态回归或过期缩略图缺陷。

## 候选证据

分支 `codex/stability-macos-ux` 的 `cbf31db` 包含候选控制措施。2026-06-15，
`./android/run_tests.sh` 和 `./android/build.sh` 通过。没有连接 Android 设备，
所以真机标准和最终无回归观察仍未完成。这些控制措施已于 2026-06-22 合并到
`codex/agent-governance` 的 `23b09d5`，但在记录设备证据前不能视为在 `main`
完成验收。

2026-06-22，集成提交通过 `./android/run_tests.sh` 和 `./android/build.sh`，并合并
到 `main` 的 `8a09aa0`。真机压力测试仍未完成。

2026-08-10，`main` 当前 HEAD `17c7538` 再次通过 `./android/run_tests.sh` 和
`./android/build.sh`，APK 签名校验通过。未连接 Android 真机，故大型媒体库、快速
导航、前后台切换、重复开始同步以及 OOM/ANR 无回归观察仍未完成。

2026-09-20，B33 未提交工作树通过 `./android/run_tests.sh` 和 `./android/build.sh`，
并在无线 ADB 设备 `22081212C` 上安装验证。约 1963 项媒体库中，一次确认 run 包含
445 项：Home 后前台服务和 `dataSync` 通知进度继续增长；force-stop 后重新打开应用，
Service 恢复并继续上传；连接失败后后续任务继续；应用内停止后 Service 消失。上述是
受控真机证据，不等同于完整系统低内存回收、长时间锁屏、厂商电池策略或全量落盘验收，
因此两项真机退出标准仍未勾选。

对应批次：`PROJECT_MEMORY/batches/2026-09-20-B33-android-background-sync.md`。

## 回滚

把集成批次作为整体回滚。不要移除该里程碑之前已经引入的有界 `TaskWindow` 行为。
