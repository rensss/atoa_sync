# Android Sync v0.1.1

崩溃修复版本。

## 修复内容

- 队列 tab 不再尝试一次渲染所有已扫描照片/视频行。
- 队列显示改为有限首屏页面，并提供“显示更多”按钮加载下一批。

## 原因

版本 `0.1.0` 会扫描完整媒体库，然后队列 tab 同步构建每一行和缩略图。大型照片库
在打开队列时可能造成应用崩溃或冻结。

## 验证

- `android/run_tests.sh`
- `python3 -m unittest receiver.tests.test_receiver`
- `android/build.sh`
- `apksigner verify`
