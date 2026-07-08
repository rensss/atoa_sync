# B18：相册白名单过滤、选择页与设置页

日期：2026-07-08
分支：`codex/android-ui-redesign`
提交：Task 2 `c95098b`（扫描器 bucket 过滤/持久化）+ Task 3 `0ab7794`（选择页/设置页）
依据：`docs/superpowers/plans/2026-07-08-android-ui-redesign.md` Task 2–3

## 改动

- `core/MediaItem`：新增 `bucketId`/`bucketName` 字段与访问器；新增 11 参构造，
  旧 9 参/6 参构造委托传 `null`（向后兼容，`SyncQueueTest` 无需改）。
- `android/MediaStoreScanner`：投影追加 `bucket_id`/`bucket_display_name`
  （API 29 起在 MediaColumns 公开，26–28 用同名字符串常量）；新增
  `scanAll(Set<String>)` 白名单过滤（null 不过滤、空集合返回空、非空用
  `bucket_id IN (?,...)`）、`listAlbums()`/`Album`（全库聚合去重、count 降序）。
  旧 `scanAll()` 委托 `scanAll(null)`。
- `android/AlbumPrefs`：`album_whitelist` StringSet 持久化（load/save/
  isConfigured；未配置返回 null）。
- `ui/AlbumPickerView`：相册勾选列表（复用 `Widgets`/`Theme`）。
- `ui/SettingsPageView`：深色设置页（同步相册/接收端/关于三段，host 桥接
  targetUrl/editTarget/openAlbumPicker/appVersionText/whitelistCount）。
- `MainActivity`：新增 `albumPicker` 屏与 `albumPickerView()`；权限就绪走
  `onPermissionReady()`——未配置白名单则强制引导（异步 `listAlbums()`，预勾
  name 为 `Camera` 的 bucket，至少选一个才能完成），已配置则扫描；`scanMedia()`
  改用 `scanner.scanAll(AlbumPrefs.load(prefs()))`，未配置置 `scanMessage =
  "请先选择同步相册"` 并 return；`settingsView()` 换成 `SettingsPageView`；
  `onBackPressed` 处理 albumPicker 返回。

## 验证

- `./android/run_tests.sh` 通过；`./android/build.sh` 生成 APK。两个任务收尾各测各构建。
- UI 层无自动化测试；相册枚举/白名单过滤/首启引导的真机行为未验证——留待设备 QA。

## 风险

- 未新增风险 ID。白名单过滤发生在扫描查询层（`selection`），不改队列并发或
  锁内无 I/O 约束（R-009 不受影响）。
- `getColumnIndexOrThrow(bucket_id)` 依赖该列在 Images/Video external 集合存在；
  26–28 与 29+ 均提供，未见缺列风险，但仅在有真机时可最终确认。
- 空白名单语义：`scanAll(空集合)` 返回空（避免非法 `IN ()`）；
  `AlbumFilter.inWhitelist(null)`（B19）定义 null=未配置=不放行，二者一致。

## 不变量

- 上传协议、队列锁内无 I/O、`.part` 暂存不受影响。
- 旧 MediaItem 构造签名保留，既有调用与测试不破。
