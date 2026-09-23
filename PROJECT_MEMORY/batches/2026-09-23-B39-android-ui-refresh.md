# B39：Android UI 重设计

日期：2026-09-23

## 目标

统一 Android 手机端的视觉层级和主要交互，让媒体浏览、传输进度、相册选择、同步确认、设置与预览使用一致的原生界面，同时保留当前同步与数据语义。

## 范围

- 建立共用深色视觉 token、控件、系统栏 inset 处理和本地矢量图标。
- 将媒体库改为可回收三列缩略图网格，保留筛选多选语义、媒体状态标记和网格位置。
- 让传输摘要打开底部详情抽屉；任务列表继续限制为 `activeWindow(40)`，保留现有停止和失败项重试回调。
- 统一目录相册行、同步确认汇总、设置分组、全屏预览关闭入口和媒体库/设置底部导航。
- 在现有无依赖 Java harness 中增加 UI 纯数据合同测试；未增加 UI 自动化框架或第三方依赖。

## 非目标

- 不改任务状态机、`SyncQueue`/`SyncDatabase`/`SyncForegroundService`、SQLite schema、媒体扫描/过滤、HTTP/WebDAV 协议或 macOS 接收端。
- 不改变 `bucket_id` 白名单格式、开始同步的确认流程、停止/重试能力、目标地址配置、通知或图片/视频打开路径。
- 不宣称完成 Android 真机视觉、交互、性能或传输验收。

## 风险和决策

- R-001 保持开放：继续由 `ThumbnailLoader` 限制并复用缩略图请求、校验 URI 身份；快速滚动、回收单元与大型媒体库内存压力仍需真机测试。
- R-002 保持开放：任务详情仍限于 `activeWindow(40)`，媒体状态更新使用现有原地刷新路径；大型媒体库滚动和 Activity/Service 状态交互仍需真机测试。
- 未触及架构、协议、存储布局、并发所有权或平台职责；没有新增 ADR。

## 不变量

- 默认包含所有未同步媒体；点击缩略图只排除本次同步，数量/字节汇总随选择变化，清空时禁用开始操作。
- 相册目录可级联选择，文件夹内的直接相册可单独切换；已保存值仍为 `bucket_id` 集合，完成后返回原入口。
- 打开或关闭传输抽屉、媒体预览不向 Service 发送命令；停止和单项失败重试继续调用原路径。
- 图片仍使用现有预览，视频仍交由系统播放器；关闭预览不重建媒体库网格。
- 传输详情保持 40 项上限和额外项数量提示，不在队列锁内做 I/O 或 bitmap 解码。

## 验证

实现提交：`923c61d`（分支 `feat/android-ui-refresh`，基于 `1749eb4`）。该提交补齐了代码审查发现的弹层复用位移、长任务列表测量、停止状态跨 run 残留和媒体库位置覆盖问题，并让本地媒体在远端 manifest 查询完成前先显示；核心传输与数据管理仍未改动。

```bash
./android/run_tests.sh
./android/build.sh
git diff --check
adb devices -l
```

- `./android/run_tests.sh`：退出码 0；原有 Android harness 与 `AndroidUiFoundationTest`、`MediaGridDataTest`、`TransferSheetDataTest`、`SelectionSummaryTest`、`TransferSheetStateTest`、`TransferSheetLayoutTest`、`LibraryViewportPolicyTest`、`MediaScanPresentationTest` 均通过。新增回归测试先在实现缺失时观察到编译失败，再在修复后通过。
- `./android/build.sh`：退出码 0；生成忽略产物 `android/build/AndroidSync-debug.apk`。
- `git diff --check`：通过。
- `adb devices -l`：首次检查只输出 `List of devices attached`；无线 ADB 重连后检测到设备 `2410DPN6CC`，APK 已增量安装并启动。媒体浏览/筛选、抽屉实时更新/停止/重试、相册与设置返回、确认排除、预览关闭、系统栏、字体放大、通知点击、快速滚动及大型媒体库验收均待用户执行。
- 上述结果证明源码 harness 与 APK 构建成功，不代表真机视觉或交互验收。R-001/R-002 继续开放。

## 回滚

按文档提交、`923c61d`、`8be2fa7`、`b045f44`、`4fb0a14`、`b0cffb3`、`a12942c` 的逆序撤销本批文档和 UI 提交即可。无数据库迁移、协议变化、远端兼容步骤或同步数据回滚。

## 结果

- 提交：UI 实现与验证指针为 `923c61d`；本批文档提交另见当前 Git 历史，不在自身记录中引用。
- 结果：UI 改版、Android harness 与 APK 构建完成；设备已安装启动，交互验收待用户执行。
- 后续：连接竖屏 Android 手机，执行本批设备清单并复核 R-001/R-002；不得在设备证据齐全前关闭相关风险或稳定性里程碑。
