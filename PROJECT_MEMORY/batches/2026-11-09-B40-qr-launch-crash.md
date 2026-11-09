# B40：二维码调起闪退修复

日期：2026-11-09

## 目标

修复扫码深链先进入设置页时，生命周期刷新未创建传输卡导致的闪退。

## 范围

- `TransferCardView.showProgress/showTodayStats/showFailure` 在 root 尚未创建时忽略 View 更新。
- 新增无第三方依赖的 Python/ADB 真机回归脚本，验证冷启动与前台深链路径。
- 更新 Android README、项目状态和交接。

## 非目标

不修改传输状态机、前台服务、数据库、网络协议、地址校验、macOS 或 B39 其余 UI 行为。

## 风险和决策

- R-009：Activity 进入设置页时仍可收到 Service/生命周期刷新；修复只保护 UI，服务所有权不变。
- R-002：继续使用现有有界任务快照，不增加队列遍历或逐项 View。
- R-012：二维码目标校验和可见设置反馈保持不变。
- 不改变受保护决策；上述风险及 M1/M2/M3 均不因本批关闭。

## 不变量

- build 前不操作未创建的 View；媒体库 build 后继续从最新队列快照刷新。
- `clearFailure/showStopping/hide` 既有空值保护保持不变。
- 未卸载或清空手机应用数据，未替换任何签名材料。

## 验证

基线：`feat/android-ui-refresh` 的 `6cf7b44443135e6b283e08a8dbe53a9bbc82f4a1`。
设备：`2410DPN6CC`，API 36，无线 ADB `10.10.2.241:39863`。

1. 原 APK crash buffer 显示 `MainActivity.onStart → driveTransferProgress →
   TransferCardView.showProgress:111` 对 null LinearLayout 调用 setVisibility。
2. 修复前运行下列 smoke 脚本，冷启动后 pidof 返回 1，进程已崩溃；失败堆栈与用户日志一致。
3. 原 main 工作树生成 APK 的签名与设备不符，覆盖安装被系统拒绝；核对证书后发现设备签名与
   本 UI 工作树一致，且源码行号匹配。最终修复/构建/安装使用本工作树，不降级到 main。

```bash
./android/run_tests.sh
./android/build.sh
adb -s 10.10.2.241:39863 install -r android/build/AndroidSync-debug.apk
python3 android/tests/qr_launch_smoke.py 10.10.2.241:39863 http://10.10.1.76:8765/uploads/
git diff --check
```

- Android 全套 harness、APK 构建、保留数据覆盖安装均退出 0。
- 修复后 smoke 退出 0：深链冷启动、设置页前台重入、媒体库前台调起三条路径通过；
  每条检查进程保持存活并显示匹配目标地址，前台重入检查 PID 不变。
- 最终应用 PID `6943`，按该 PID 查询 crash buffer 无输出。
- 未执行物理相机扫码、活动传输期间深链、空队列设备场景或完整 B39/稳定性验收。
- 未修改 macOS，未重复 macOS 测试。APK 和 keystore 均保持忽略状态。

## 回滚

撤销本批传输卡保护、回归脚本和说明文档即可；无数据迁移，不删除媒体或应用数据库。

## 结果

- 提交：见 `feat/android-ui-refresh` 的本批 Git 历史；实现基线为上方已核对的 `6cf7b44`。
- 结果：原闪退已复现并通过同设备修复后回归，APK 已安装。
- 后续：用户可用系统相机再次扫码确认实际入口；继续完成 B39 与 M1/M2/M3 开放验收。
