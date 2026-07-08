# B21：上传设备型号头与真机 QA 清单

日期：2026-07-08
分支：`codex/android-ui-redesign`
提交：`c8d88b6`
依据：`docs/superpowers/plans/2026-07-08-android-ui-redesign.md` Task 8

## 改动

- `android/HttpFileUploader`：在 `X-Android-Sync-Size` 头之后新增
  `X-Android-Sync-Device`（值 `android.os.Build.MODEL`），供 macOS 接收端
  后续区分来源设备。上传协议其余头与流式模式（B16）不变。

## 验证

- `./android/run_tests.sh` 通过；`./android/build.sh` 生成 APK。
- macOS 接收端读取该头的行为属 macOS 侧后续批次，本批不覆盖。

## 真机 QA 清单（未执行——无已连接 Android 设备）

以下为整条 Android 重设计（B17–B21）的验收项，**均未在真机执行**，B21 不宣称关闭：

1. 首启：权限 → 相册引导（预勾 Camera）→ 至少选一个才能完成。
2. 白名单外媒体（如 Download 电影）不出现在网格与确认态。
3. chips 过滤只影响显示；管理页增删相册后网格随之变化。
4. 确认态排除 2 项 → 上传数量与字节吻合；排除项未上传。
5. 传输中卡片行进度/展开逐文件/失败重试；完成显示今日统计后收起。
6. GB 级视频传输全程不崩溃、内存平稳（B16 回归）。
7. macOS 端收到 `X-Android-Sync-Device` 头（抓包或 macOS 后续读取批次验证）。
8. 弹层预览：图片显示、视频跳系统播放器；返回键路径正确
   （confirm/设置/相册页回 library）。

## 风险

- 未新增风险 ID。新增头不改请求体、长度或流式模式，B16 定长流式修复不受影响。
- R-001/R-002（Android 稳定性、真机压力）仍开放：本批新增的媒体库/确认态/
  传输卡片 UI 的真机稳定性未验证；里程碑 `M1_android_stability` 退出标准未满足。

## 不变量

- 上传协议向后兼容（仅新增可选头）；`.part` 暂存与尺寸校验不变。
