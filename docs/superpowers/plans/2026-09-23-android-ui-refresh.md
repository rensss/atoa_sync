# Android UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 重做 Android 竖屏手机端的界面视觉与导航呈现，使媒体浏览和传输状态清楚一致，同时保留现有同步能力和数据语义。

**Architecture:** 沿用 Java、原生 Android View 与当前 SDK 脚本。以共用 Theme/Widgets 建立视觉系统；媒体库改用可回收的原生 `GridView`，活动传输详情通过自定义原生 View 底部 Dialog 呈现。`MainActivity` 仍负责页面路由和现有队列/Service 桥接，不更改同步核心。

**Tech Stack:** Android framework Views、Java 8 source/target、Android SDK 35，最低 API 26；无第三方 UI 依赖。

**Spec:** `docs/superpowers/specs/2026-09-23-android-ui-refresh-design.md`

## Global Constraints

- 只改 Android UI 组件、路由呈现、Android 资源与实施批次文档。
- 保持 Java + 原生 View + `android/build.sh`；不引入 Gradle、Compose、AndroidX 或第三方库。
- 保持 `minSdkVersion=26`、`targetSdkVersion=35` 和竖屏约束。
- Android 15 上 target 35 强制 edge-to-edge；状态栏、底部应用导航、确认栏、预览 Dialog 和传输抽屉都必须按系统栏 insets 安排内容，不能依赖旧的系统栏颜色行为。[官方 View 指南](https://developer.android.com/develop/ui/views/layout/edge-to-edge)
- 不改 Service、队列状态机、SQLite、MediaStore 扫描/筛选、`bucket_id` 白名单格式、HTTP 协议或 macOS 接收端。
- 现有相册 chip 多选语义、确认页默认全选/单项排除、停止、失败重试、通知点击和二维码改地址行为保持不变。
- 继续使用 `ThumbnailLoader` 与 `SyncQueue.activeWindow(40)`；不得在队列锁中执行 I/O 或 bitmap 解码，不关闭 R-001/R-002。
- 不新建 UI 自动化框架；在现有无依赖 Java harness 中增加纯 Java 主题/inset 计算检查，`./android/build.sh` 编译原生 View 和资源。
- 每项任务独立检查并提交；最终写入一个 B39 Android UI 批次记录并更新项目状态/交接。

## Review Focus

1. API 35 edge-to-edge 与旧版本/三键导航的 top/bottom insets 只应用一次；页面、底栏和 Dialog 不被系统栏遮挡。由 Task 1 真机检查。
2. GridView 回收 ImageView 后，较早的缩略图异步结果不能覆盖当前媒体；继续依赖 ThumbnailLoader 的 URI tag 校验。由 Task 2 快速滚动/筛选检查。
3. 0、1、40、41+ 个非完成任务时，抽屉计数、停止可见性和“还有 N 项”正确；列表仍有界。由 Task 3 检查。
4. 上传在抽屉打开期间完成、失败或用户关闭抽屉时，Service 不被重复启动/停止；抽屉能展示最新快照，返回首页不丢位置。由 Task 3 真机检查。
5. 0 个待上传项、全部排除、长文件名和系统字体放大时，确认按钮与汇总仍正确，内容可读且可操作。由 Task 4 检查。

---

### Task 1: 建立视觉 token、共用控件与系统栏布局

**Files:**
- Modify: `android/src/main/java/com/androidsync/app/ui/Theme.java`
- Create: `android/src/main/java/com/androidsync/app/ui/UiInsetsPadding.java`
- Modify: `android/src/main/java/com/androidsync/app/ui/Widgets.java`
- Modify: `android/src/main/java/com/androidsync/app/MainActivity.java`
- Modify: `android/src/main/res/values/styles.xml`
- Modify: `android/run_tests.sh`
- Create: `android/tests/AndroidUiFoundationTest.java`
- Create: `android/src/main/res/drawable/ic_library.xml`
- Create: `android/src/main/res/drawable/ic_settings.xml`
- Create: `android/src/main/res/drawable/ic_sync.xml`
- Create: `android/src/main/res/drawable/ic_folder.xml`
- Create: `android/src/main/res/drawable/ic_close.xml`
- Create: `android/src/main/res/drawable/ic_stop.xml`
- Create: `android/src/main/res/drawable/ic_retry.xml`

**Interfaces:**
- Consumes: Existing `Theme` color strings, dp helpers, and programmatic control factory methods.
- Produces: Shared `Theme` tokens plus `Widgets.primaryButton(String, View.OnClickListener)`, `Widgets.secondaryButton(String, View.OnClickListener)`, `Widgets.iconButton(int drawableId, String contentDescription, View.OnClickListener)` returning `ImageButton`, `Widgets.sectionTitle(String)`, and consistent card/chip/divider factories. All button variants have a 48 dp minimum touch target.
- Produces: `Widgets.installSystemInsets(View insetHost, View topTarget, View bottomTarget)` and `Widgets.installDialogInsets(Dialog dialog, View topTarget, View bottomTarget)`. The helper captures baseline padding once, uses `WindowInsets.Type.systemBars()` on API 30+ and legacy system window insets on API 26–29, and never accumulates padding across inset dispatches.

- [x] **Step 1: Add red tests for theme tokens and inset math**

Add `AndroidUiFoundationTest` to the existing dependency-free harness and include the pure `Theme.java` source. Assert the selected color/spacing tokens, 48 dp minimum touch target, and an inset-padding helper that adds system-bar insets to an immutable baseline on every dispatch. Run `./android/run_tests.sh` before changing production code; the expected failures are the old/missing Theme tokens and missing inset helper.

- [x] **Step 2: Replace the palette and spacing tokens**

In `Theme.java`, define the dark professional palette and semantic status colors used by every page. Use these initial values:

```java
public static final String BG = "#11151A";
public static final String BG_SURFACE = "#1A2027";
public static final String BG_RAISED = "#242D36";
public static final String STROKE = "#35414B";
public static final String TEXT_PRIMARY = "#F2F5F7";
public static final String TEXT_SECONDARY = "#B3BEC6";
public static final String TEXT_MUTED = "#85939D";
public static final String ACCENT = "#59C3D4";
public static final String STATUS_RUNNING = "#57CB91";
public static final String STATUS_WARNING = "#E8B85E";
public static final String STATUS_FAILED = "#F07578";
public static final int SPACE_XS = 4;
public static final int SPACE_S = 8;
public static final int SPACE_M = 12;
public static final int SPACE_L = 16;
public static final int SPACE_XL = 24;
```

Keep semantic meaning in the token names; remove the old blue-purple gradient from primary surfaces.

- [x] **Step 3: Add the pure inset-padding helper and shared widget factories**

Implement `UiInsetsPadding.apply(int[] baseline, int[] systemInsets)` as a pure Java helper and make the tests pass. In `Widgets.java`, add the factories listed above. Set `minHeight` to `dp(Theme.MIN_TOUCH_TARGET_DP)`, retain native focus/click behavior, and use the existing `rounded`, `color`, and `dp` helpers. Keep existing `formatBytes` behavior unchanged. Replace existing callers in Tasks 2–4 rather than adding a second styling system.

- [x] **Step 4: Add local vector icons**

Create the seven drawable resources listed above as 24×24 monochrome vectors, use `#FFFFFFFF` for path fill, and tint each `ImageButton` with `ImageView.setImageTintList(ColorStateList.valueOf(color))`. Use these path descriptions so the icon family stays consistent: library = four equal square tiles; settings = three horizontal rails with one circular knob on each rail; sync = vertical up arrow over a short baseline; folder = one tabbed folder silhouette; close = two diagonal strokes; stop = centered square; retry = one circular arrow with a right-facing arrowhead. Use only local vector resources; do not add an icon library or text glyph fallback.

- [x] **Step 5: Handle edge-to-edge insets once**

Update `MainActivity.configureSystemBars()` to use transparent system bars, preserve light-colored system icons on the dark app surface, and leave `SYSTEM_UI_FLAG_LIGHT_STATUS_BAR` / `SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR` unset. On API 30+, call `Window.setDecorFitsSystemWindows(false)`; on API 26–29, use `SYSTEM_UI_FLAG_LAYOUT_STABLE | SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION`. Implement the two `Widgets` helpers from Interfaces. Apply the top inset to page content and the bottom inset to the app navigation/confirmation footer or modal that owns the screen edge. Remove per-page `statusBarHeight()` top padding from `Widgets.pageLayout()`, `LibraryPageView`, and `ConfirmSelectionView` in their owning tasks. Keep the existing 76 dp app navigation content height before adding bottom inset.

- [x] **Step 6: Build the UI resources**

Run: `./android/build.sh`

Expected: `aapt2` compiles the vector resources and the APK builds/signature verifies. Do not stage `android/build/` or local signing material.

Manual device check pending: `adb devices -l` reports no connected device. On an API 35 phone verify gesture and 3-button navigation, then check API 26–29 legacy insets when available.

- [x] **Step 7: Commit the visual foundation**

```bash
git add android/src/main/java/com/androidsync/app/ui/Theme.java android/src/main/java/com/androidsync/app/ui/Widgets.java android/src/main/java/com/androidsync/app/MainActivity.java android/src/main/res/values/styles.xml android/src/main/res/drawable/ic_library.xml android/src/main/res/drawable/ic_settings.xml android/src/main/res/drawable/ic_sync.xml android/src/main/res/drawable/ic_folder.xml android/src/main/res/drawable/ic_close.xml android/src/main/res/drawable/ic_stop.xml android/src/main/res/drawable/ic_retry.xml
git add android/src/main/java/com/androidsync/app/ui/UiInsetsPadding.java android/tests/AndroidUiFoundationTest.java android/run_tests.sh
git commit -m "feat: establish Android UI design system"
```

### Task 2: Rebuild the media library and preserve grid state

**Files:**
- Create: `android/src/main/java/com/androidsync/app/ui/MediaGridAdapter.java`
- Create: `android/src/main/java/com/androidsync/app/ui/MediaGridData.java`
- Modify: `android/src/main/java/com/androidsync/app/ui/LibraryPageView.java`
- Modify: `android/src/main/java/com/androidsync/app/MainActivity.java`
- Modify: `android/run_tests.sh`
- Create: `android/tests/MediaGridDataTest.java`

**Interfaces:**
- Consumes: `MediaItem`, `SyncStatus`, `ThumbnailLoader`, existing multi-select `chipFilter`, and the shared widget factories from Task 1.
- Produces: `MediaGridAdapter(Activity, Widgets, ThumbnailLoader, ItemClickListener)`, extending `BaseAdapter` with `getCount()`, `getItem(int position)`, `getItemId(int position)`, and `getView(int position, View convertView, ViewGroup parent)` plus `replaceItems(List<MediaItem>)` and `replaceStatuses(Map<String, SyncStatus>)`. `getItemId(position)` returns the position and stable IDs remain disabled. `LibraryPageView.LibraryHost` adds `Map<String, SyncStatus> statusByStableId()`. `LibraryPageView` exposes `int firstVisiblePosition()`, `int firstChildTop()`, and `void restorePosition(int firstVisiblePosition, int firstChildTop)` for route preservation.
- `MainActivity` remains the owner of `scannedMedia`, `chipFilter`, and status lookup. `LibraryPageView` never rescans or mutates a queue.

- [x] **Step 1: Add a red test for replaceable grid data**

Add MediaGridDataTest to the existing harness. Cover defensive replacement of visible items and status snapshots, default WAITING status, and first-visible-index clamping for empty, shorter, and unchanged result lists. Run ./android/run_tests.sh before implementing the model; the expected failure is the missing model contract.

- [x] **Step 2: Create a recycling 3-column media adapter**

Implement `MediaGridAdapter extends BaseAdapter`. `getView` reuses a `FrameLayout` containing an `ImageView`, a loading/empty placeholder, and a status badge. Set the image tag to the current `MediaItem.uri()` before calling `ThumbnailLoader.loadThumbnailInto`; bind the badge from the current stable-ID status map. Use `GridView`'s measured column width for square cells; if the first bind occurs before measurement, install a one-shot layout callback and update the adapter cell height after the actual width is known.

```java
public interface ItemClickListener {
    void onItemClick(MediaItem item);
}

public void replaceItems(List<MediaItem> items);
public void replaceStatuses(Map<String, SyncStatus> statuses);
@Override public int getCount();
@Override public MediaItem getItem(int position);
@Override public long getItemId(int position); // return position; stable IDs stay disabled
@Override public View getView(int position, View convertView, ViewGroup parent);
```

- [x] **Step 3: Replace the eager GridLayout with GridView**

In `LibraryPageView`, use the adapter in a native `GridView` with three columns and small even spacing. Preserve thumbnail center-crop, current status badge meanings, and click-to-preview. Keep the existing sync action available above the bottom navigation.

- [x] **Step 4: Make chip changes update the adapter in place**

Change `LibraryHost.toggleChip` so it updates only the `chipFilter` set; remove the `render()` call from that callback. After toggling, refresh chip selected states and call `adapter.replaceItems(host.visibleItems())`. Capture `getFirstVisiblePosition()` and the first child top before replacement, then restore with `setSelectionFromTop()` after the adapter update. Do not call `scanMedia()` or `ThumbnailLoader.bumpGeneration()` for an in-place filter update.

On a service-state broadcast, call `adapter.replaceStatuses(host.statusByStableId())` and `notifyDataSetChanged()` without rebuilding the Activity. Clamp the restored first-visible index to the new last item when filtering reduces the item count; use index 0 when the new list is empty.

- [x] **Step 5: Preserve the viewport across secondary routes**

Add Activity-owned fields for the library grid’s first visible position and top offset. Capture them before opening settings, album management, or sync confirmation; restore them when `LibraryPageView` is rebuilt. Preview and transfer sheet are overlays and must leave the existing grid attached.

- [x] **Step 6: Run automated checks; device verification pending**

Run: `./android/run_tests.sh`

Run: `./android/build.sh`

Manual device check pending: no device is connected. Scroll well below the first row, toggle two album chips rapidly, and confirm the resulting filter and viewport; scroll across thumbnails to check URI reuse; check zero visible items and long filenames.

- [x] **Step 7: Commit the media library**

```bash
git add android/src/main/java/com/androidsync/app/ui/MediaGridAdapter.java android/src/main/java/com/androidsync/app/ui/LibraryPageView.java android/src/main/java/com/androidsync/app/MainActivity.java
git add android/src/main/java/com/androidsync/app/ui/MediaGridData.java android/tests/MediaGridDataTest.java android/run_tests.sh
git commit -m "feat: refresh Android media library UI"
```

### Task 3: Add the live transfer bottom sheet

**Files:**
- Create: `android/src/main/java/com/androidsync/app/ui/TransferDetailsSheet.java`
- Create: `android/src/main/java/com/androidsync/app/ui/TransferSheetData.java`
- Modify: `android/src/main/java/com/androidsync/app/ui/TransferCardView.java`
- Modify: `android/src/main/java/com/androidsync/app/ui/Widgets.java`
- Modify: `android/src/main/java/com/androidsync/app/ui/Theme.java`
- Modify: `android/src/main/java/com/androidsync/app/MainActivity.java`
- Modify: `android/run_tests.sh`
- Create: `android/tests/TransferSheetDataTest.java`

**Interfaces:**
- Consumes: `SyncQueue.Summary`, `TaskWindow`, `SyncTask`, current foreground-service broadcasts, and the existing `stopSync()`/retry behavior.
- Produces: `TransferDetailsSheet(Activity, Widgets, Actions)` with `show(SyncQueue.Summary, TaskWindow, boolean runActive)`, `update(SyncQueue.Summary, TaskWindow, boolean runActive)`, and `isShowing()`. Its `Actions` interface contains only `void stop()` and `void retry(String taskId)`.
- `TransferCardView(Activity, Widgets, DetailsHandler)` becomes a compact clickable status summary and calls `DetailsHandler.open()`; it no longer builds an inline task list. No service command is issued by opening or dismissing the sheet.

```java
public interface DetailsHandler {
    void open();
}
```

- [x] **Step 1: Add red tests for transfer-sheet data boundaries**

Add TransferSheetDataTest to the existing harness. Cover 0, 1, 40, and 41 active tasks, the 40-row cap/hidden count, run-active Stop visibility, terminal Stop hiding, and remaining-byte derivation. Run ./android/run_tests.sh before implementing the data model; the expected failure is the missing model contract.

- [x] **Step 2: Build the custom native bottom sheet shell**

Create `TransferDetailsSheet` using an Android framework `Dialog`, not `BottomSheetDialog`. Set window gravity to `BOTTOM`, width to `MATCH_PARENT`, and height to wrap content capped at 80% of available height. Give it a top drag handle, close button, rounded top surface, dimmed scrim, and a scrollable task region. Support Back, outside tap, close-button, and downward drag on the handle; do not attach drag dismissal to the scrolling task list.

- [x] **Step 3: Render queue summary and bounded tasks**

Display done/total, remaining bytes, uploading/waiting/failed counts, and only `TaskWindow.visibleTasks()`. When `TaskWindow.hasMore()` is true, show `TaskWindow.hiddenCount()` in a final “另有 N 项” row. Show the stop action only while `runActive`; show retry only on `FAILED` task rows.

- [x] **Step 4: Convert TransferCardView to a summary entry point**

Keep its existing progress, failure, and today-stat data, but remove its inline expand-list construction. Make the entire summary region at least 48 dp high and clickable, set a useful content description, and delegate opening to `DetailsHandler`.

- [x] **Step 5: Wire snapshot updates without re-rendering the Activity**

In `MainActivity.driveTransferProgress()`, read `queue.summary()` and `queue.activeWindow(40)` once, then update the summary card and call `transferSheet.update(...)` only when the dialog is showing. Keep the existing `SyncQueue`/database ownership and retry checks. If a run completes while the sheet is open, update the sheet to its terminal summary, hide Stop, and leave dismissal to the user. Avoid the terminal-event `render()` path while the sheet is open.

Dismiss the sheet from `MainActivity.onDestroy()` before destroying its Activity-owned Views; dismissal must not call `stopSync()`.

- [x] **Step 6: Run automated checks; device verification pending**

Run: `./android/run_tests.sh`

Run: `./android/build.sh`

Manual device check pending: no device is connected. Cover 0, 1, 40, and 41+ tasks; verify counts, Stop visibility, the “另有 N 项” row, and bounded rows. Open the sheet during a real run, dismiss/reopen without interrupting upload, verify Stop and one-task retry, and cover failures with no run plus run completion while open.

- [x] **Step 7: Commit transfer details**

```bash
git add android/src/main/java/com/androidsync/app/ui/TransferDetailsSheet.java android/src/main/java/com/androidsync/app/ui/TransferCardView.java android/src/main/java/com/androidsync/app/ui/Widgets.java android/src/main/java/com/androidsync/app/ui/Theme.java android/src/main/java/com/androidsync/app/MainActivity.java
git add android/src/main/java/com/androidsync/app/ui/TransferSheetData.java android/tests/TransferSheetDataTest.java android/run_tests.sh
git commit -m "feat: add Android transfer details sheet"
```

### Task 4: Unify album, confirmation, settings, and preview screens

**Files:**
- Modify: `android/src/main/java/com/androidsync/app/ui/AlbumPickerView.java`
- Modify: `android/src/main/java/com/androidsync/app/ui/ConfirmSelectionView.java`
- Modify: `android/src/main/java/com/androidsync/app/ui/SettingsPageView.java`
- Modify: `android/src/main/java/com/androidsync/app/MainActivity.java`
- Create: `android/src/main/res/drawable/ic_exclude.xml`
- Create: `android/src/main/java/com/androidsync/app/ui/SelectionSummary.java`
- Create: `android/tests/SelectionSummaryTest.java`
- Modify: `android/run_tests.sh`

**Interfaces:**
- Consumes: Task 1 design tokens, Task 2 viewport state, existing `AlbumTree`, `AlbumPrefs`, `AlbumFilter`, `AddressConfiguration`, and current screen callbacks.
- Produces: consistent Android-native screen layouts using the shared widget factories. Existing view/host callback meanings remain unchanged; callback names may be adjusted only where required to retain the origin route and current grid position.

- [x] **Step 1: Add red tests for confirmation selection totals**

Add `SelectionSummaryTest` to the existing harness. Cover the default all-included set, a subset excluded, all items excluded, and an empty input; assert both selected count and total bytes. Run `./android/run_tests.sh` before implementing the model; the expected failure is the missing model contract.

- [x] **Step 2: Restyle album rows without changing selection meaning**

Use common folder/albums rows with 48 dp minimum height. Give folder navigation a distinct trailing icon/touch region from its checkbox. Keep parent `NONE/PARTIAL/ALL`, cascading toggle, direct album toggle, breadcrumb, and existing `bucket_id` save behavior.

- [x] **Step 3: Make confirmation summary persistent and accurate**

Restyle the current selection grid and replace the ad-hoc cross icon with the local exclude icon. Use `SelectionSummary` as the one count/byte recomputation method during initial build and every toggle. Pin the summary/action bar above the system navigation inset; disable Start at zero selected items. Keep cancel/back, default all-pending inclusion, and “tap to exclude this run” semantics.

- [x] **Step 4: Restyle settings as grouped rows**

Display album count/manage, configured receive URL/edit, and app version in consistent sections. Long URLs wrap or ellipsize without pushing the edit action off-screen. Use icon-plus-label bottom tabs with a distinct selected state. Keep `editTarget()`, QR deep-link behavior, and existing success/error messages.

- [x] **Step 5: Restyle full-screen preview and preserve return context**

Add a visible close control and consistent metadata spacing to the existing full-screen Dialog; retain image preview and the video “open in system player” action. Ensure Back/close dismisses the Dialog without rebuilding or scrolling the library grid.

- [x] **Step 6: Run automated checks; device verification pending**

Run: `./android/run_tests.sh`

Run: `./android/build.sh`

Manual device check pending: no device is connected. Open album management from both Library and Settings and verify return routes; navigate folder/check states; exclude all items and verify count/bytes and disabled Start; open/close preview; edit the receiver URL; check regular/enlarged text and clipping.

- [x] **Step 7: Commit secondary screens**

```bash
git add android/src/main/java/com/androidsync/app/ui/AlbumPickerView.java android/src/main/java/com/androidsync/app/ui/ConfirmSelectionView.java android/src/main/java/com/androidsync/app/ui/SettingsPageView.java android/src/main/java/com/androidsync/app/MainActivity.java
git add android/src/main/java/com/androidsync/app/ui/SelectionSummary.java android/tests/SelectionSummaryTest.java android/run_tests.sh
git commit -m "feat: unify Android settings and selection flows"
```

### Task 5: Integrate, record the batch, and complete verification

**Files:**
- Modify: `PROJECT_MEMORY/00_PROJECT_STATUS.md`
- Modify: `PROJECT_MEMORY/HANDOFF.md`
- Modify: `PROJECT_MEMORY/02_RISK_REGISTER.md`
- Create: `PROJECT_MEMORY/batches/2026-09-23-B39-android-ui-refresh.md`
- Modify: `android/README.md`
- Modify: `docs/superpowers/specs/2026-09-23-android-ui-refresh-design.md`
- Modify: `docs/superpowers/plans/2026-09-23-android-ui-refresh.md`

**Interfaces:**
- Consumes: integrated UI from Tasks 1–4 and actual command/device evidence.
- Produces: a B39 record with scope, invariants, R-001/R-002 review, exact validation results, device QA status, and rollback notes; status/handoff point to the current verified commit.

- [x] **Step 1: Record only verified batch facts**

Create the B39 record in Chinese. Preserve R-001/R-002 as open until their full real-device criteria pass. Record the UI code verification commit (resolved with `git rev-parse HEAD` after Task 4) and device QA as pending if no device is connected; do not describe build success as visual acceptance. Update the design spec status to reflect the user's approval on 2026-09-23, and keep this plan's checked implementation/verification state. The documentation commit itself need not be self-referenced.

- [x] **Step 2: Run the complete Android automated checks**

Run: `./android/run_tests.sh`

Run: `./android/build.sh`

Run: `git diff --check`

Record each result and the verified UI implementation commit from Task 4 in the status and handoff documents.

Observed on 2026-09-23: initial implementation checks passed at `b045f44`; review fixes landed in `8be2fa7e8f1d7daa8f55b0008e49eb993c1c5ed6`, and the local-first media refresh fix landed in `923c61debb3398c7db1a80aa81a08ee23a47b449`. The final `./android/run_tests.sh`, `./android/build.sh`, and `git diff --check` each exited 0 and produced `android/build/AndroidSync-debug.apk`. The APK was incrementally installed on the paired device `2410DPN6CC`; `adb devices -l` had no device before pairing and the device was available after wireless ADB reconnect.

- [x] **Step 3: Check device availability; real-device acceptance pending**

Check `adb devices -l`. If a portrait Android phone is available, cover all manual cases from Tasks 1–4, notification tap returning to the foreground while transfer continues, Android system-bar overlap under gesture and 3-button navigation if available, and the open R-001/R-002 large-library/rapid-scroll checks. If no device is connected, record that output and leave these criteria explicitly pending.

Observed: the first `adb devices -l` returned only `List of devices attached`; after wireless ADB reconnect, device `2410DPN6CC` was detected and the APK was installed/launched. All listed manual cases remain pending and R-001/R-002 remain open.

- [x] **Step 4: Commit the batch evidence**

```bash
git add PROJECT_MEMORY/00_PROJECT_STATUS.md PROJECT_MEMORY/HANDOFF.md PROJECT_MEMORY/02_RISK_REGISTER.md PROJECT_MEMORY/batches/2026-09-23-B39-android-ui-refresh.md android/README.md docs/superpowers/specs/2026-09-23-android-ui-refresh-design.md docs/superpowers/plans/2026-09-23-android-ui-refresh.md
git commit -m "docs: record Android UI refresh batch"
```

### Final review corrections

- [x] Reset the reusable transfer sheet's drag offset on show/dismiss, and scope the stop button's pending state to the current sync run.
- [x] Measure the transfer task list with the sheet's weighted remaining height so long active windows cannot clip the stop action.
- [x] Capture the media-library viewport only after the replacement `GridView` is laid out with children, preserving the position across the immediate scan render.
- [x] Add pure-Java regression contracts for transfer state, sheet layout bounds, and viewport capture policy. The tests were observed failing before the helper implementations and pass in the final Android harness.
- [x] Re-run `./android/run_tests.sh`, `./android/build.sh`, and `git diff --check`; keep the remaining device QA and R-001/R-002 open pending interactive checks.
- [x] Let local media render before the remote manifest lookup, with `MediaScanPresentationTest` covering the pending and completed snapshots; an incremental APK install on `2410DPN6CC` succeeded.

## Rollback

Revert the B39 UI commits and batch documentation in reverse order. The plan introduces no database migration, protocol change, dependency, or macOS modification.
