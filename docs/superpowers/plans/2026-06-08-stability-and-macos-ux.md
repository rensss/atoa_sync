# Android Sync 稳定性与 macOS 体验改进实施计划

> **给执行代理：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，按任务逐项执行。所有步骤使用复选框跟踪。

**目标：** 修复 Android OOM 和队列闪烁，并完成 macOS 原生工具栏、固定缩略图、中英文切换、设置入口、版本号、单层菜单、Inspector、搜索、空格 Quick Look、失败上传清理及排序修正。

**架构：** Android 保留当前原生 View 架构，通过小尺寸缓存和页面内局部更新消除 Bitmap 峰值与整页重建。macOS 保留 SwiftUI + SwiftData + SwiftPM 架构，增加集中式运行时本地化、原生 ToolbarContent、纯逻辑排序边界和明确区分的接收器生命周期/单次上传事件。

**技术栈：** Java 8、Android SDK 35、Swift 6、SwiftUI、SwiftData、Network.framework、QuickLookUI、SwiftPM、XCTest。

---

## 文件结构

新增文件：

- `android/src/main/java/com/androidsync/app/core/ThumbnailPolicy.java`：统一缩略图和详情预览请求尺寸上限。
- `macos/Sources/AndroidSyncMac/Support/Localization.swift`：中英文键、默认语言和运行时查表。
- `macos/Sources/AndroidSyncMac/Support/AppVersionInfo.swift`：从 Bundle 读取发布版本与构建号。
- `macos/Tests/AndroidSyncMacTests/AppModelQueryTests.swift`：日期筛选和排序方向测试。
- `macos/Tests/AndroidSyncMacTests/LocalizationTests.swift`：默认中文和英文映射测试。
- `macos/Tests/AndroidSyncMacTests/AppVersionInfoTests.swift`：版本读取回退测试。

重点修改文件：

- `android/src/main/java/com/androidsync/app/MainActivity.java`：Bitmap 缓存、圆角裁切、队列局部刷新和分页追加。
- `android/tests/SyncQueueTest.java`：缩略图策略和队列顺序回归测试。
- `macos/Sources/AndroidSyncCore/ReceiverService.swift`：区分接收器失败和单次上传失败。
- `macos/Sources/AndroidSyncMac/Stores/AppModel.swift`：语言、查询、临时上传状态和失败清理。
- `macos/Sources/AndroidSyncMac/Views/ContentView.swift`：原生工具栏、搜索、Inspector 和空格预览入口。
- `macos/Sources/AndroidSyncMac/Views/LibraryToolbar.swift`：改为 `ToolbarContent` 和单层菜单。
- `macos/Sources/AndroidSyncMac/Views/ThumbnailView.swift`：固定尺寸内等比缩放。
- `macos/Sources/AndroidSyncMac/Views/*.swift`：替换用户可见硬编码文字。
- `macos/build_and_run.sh`：发布版本与构建号写入 Info.plist。
- `macos/Package.swift`：增加 macOS 应用测试目标。

### 任务 1：建立 Android 缩略图尺寸和顺序回归测试

**文件：**

- 新建：`android/src/main/java/com/androidsync/app/core/ThumbnailPolicy.java`
- 修改：`android/tests/SyncQueueTest.java`

- [ ] **步骤 1：先写失败测试**

在 `SyncQueueTest.main` 中加入：

```java
thumbnailPolicyCapsGridAndPreviewRequests();
recentWindowPreservesScannerNewestFirstOrder();
```

新增测试：

```java
private static void thumbnailPolicyCapsGridAndPreviewRequests() {
    assertEquals(96, ThumbnailPolicy.gridRequestPixels(320), "grid request should stay small");
    assertEquals(96, ThumbnailPolicy.gridRequestPixels(96), "grid request should match target");
    assertEquals(1024, ThumbnailPolicy.previewRequestPixels(1440), "preview should be capped");
    assertEquals(640, ThumbnailPolicy.previewRequestPixels(640), "preview should match viewport");
}

private static void recentWindowPreservesScannerNewestFirstOrder() {
    SyncQueue queue = new SyncQueue();
    queue.enqueueAll(List.of(
        itemAt("new", "new.jpg", 3_000L),
        itemAt("old", "old.jpg", 1_000L)
    ));

    assertEquals(
        "new.jpg",
        queue.recentWindow(2).visibleTasks().get(0).media().displayName(),
        "recent grid should show newest scanner result first"
    );
}
```

- [ ] **步骤 2：运行测试并确认失败**

运行：

```bash
./android/run_tests.sh
```

预期：编译失败，提示 `ThumbnailPolicy` 或 `itemAt` 尚不存在。

- [ ] **步骤 3：实现最小尺寸策略**

```java
public final class ThumbnailPolicy {
    private static final int GRID_MAX_PIXELS = 96;
    private static final int PREVIEW_MAX_PIXELS = 1024;

    private ThumbnailPolicy() {}

    public static int gridRequestPixels(int targetPixels) {
        return Math.max(1, Math.min(targetPixels, GRID_MAX_PIXELS));
    }

    public static int previewRequestPixels(int targetPixels) {
        return Math.max(1, Math.min(targetPixels, PREVIEW_MAX_PIXELS));
    }
}
```

为测试增加可指定时间的 `itemAt` helper。

- [ ] **步骤 4：重新运行 Android 核心测试**

运行：

```bash
./android/run_tests.sh
```

预期：全部通过。

- [ ] **步骤 5：提交**

```bash
git add android/src/main/java/com/androidsync/app/core/ThumbnailPolicy.java android/tests/SyncQueueTest.java
git commit -m "test: cover Android thumbnail sizing and order"
```

### 任务 2：修复 Android Bitmap 峰值和首页圆角方格

**文件：**

- 修改：`android/src/main/java/com/androidsync/app/MainActivity.java`

- [ ] **步骤 1：接入有上限的 Bitmap 缓存**

增加 `LruCache<String, Bitmap>`，容量使用运行时最大内存的 1/16，缓存键包含
URI 与请求尺寸：

```java
private final LruCache<String, Bitmap> thumbnailCache =
    new LruCache<String, Bitmap>(bitmapCacheBytes()) {
        @Override
        protected int sizeOf(String key, Bitmap bitmap) {
            return bitmap.getAllocationByteCount();
        }
    };

private static int bitmapCacheBytes() {
    long proposed = Runtime.getRuntime().maxMemory() / 16L;
    long bounded = Math.max(4L * 1024L * 1024L, proposed);
    return (int) Math.min(Integer.MAX_VALUE, bounded);
}
```

缓存只保存队列/首页小图，不保存详情大图。

- [ ] **步骤 2：按实际像素请求缩略图**

把：

```java
new Size(dp(96), dp(96))
```

替换为：

```java
int pixels = ThumbnailPolicy.gridRequestPixels(96);
new Size(pixels, pixels)
```

详情预览使用屏幕宽度和 `ThumbnailPolicy.previewRequestPixels(...)`，不再请求
`dp(1200)`。

- [ ] **步骤 3：处理 OOM 和失效视图**

在小图和详情预览的后台解码中分别捕获：

```java
} catch (OutOfMemoryError error) {
    Log.w(TAG, "Thumbnail allocation failed for " + mediaUri, error);
    return null;
} catch (Exception error) {
    Log.w(TAG, "Thumbnail load failed for " + mediaUri, error);
    return null;
}
```

主线程设置前同时检查 tag 和 `image.isAttachedToWindow()`。

- [ ] **步骤 4：让首页方格真正裁切圆角**

在 `recentTaskTile` 中：

- 使用 `tile.setClipToOutline(true)`
- 设置包含圆角的 `GradientDrawable`
- 缩略图继续 `CENTER_CROP`
- 状态条最后加入，确保覆盖图片

- [ ] **步骤 5：编译 Android 应用**

运行：

```bash
./android/run_tests.sh
./android/build.sh
```

预期：测试通过，输出 `android/build/AndroidSync-debug.apk`，签名验证成功。

- [ ] **步骤 6：提交**

```bash
git add android/src/main/java/com/androidsync/app/MainActivity.java
git commit -m "fix: bound Android thumbnail memory"
```

### 任务 3：消除 Android 队列整页闪烁

**文件：**

- 修改：`android/src/main/java/com/androidsync/app/MainActivity.java`

- [ ] **步骤 1：增加队列页面引用和任务行引用**

增加：

```java
private LinearLayout queueSummaryContainer;
private LinearLayout queueTaskContainer;
private TextView queueLoadMoreHint;
private final Map<String, QueueRowViews> queueRows = new HashMap<>();
```

`QueueRowViews` 保存状态文本、错误文本、进度条、重试按钮和根视图。

- [ ] **步骤 2：将任务行改为可原地刷新**

`taskRow` 只创建一次控件，再调用：

```java
private void bindQueueRow(QueueRowViews views, SyncTask task)
```

根据状态更新文字、颜色、进度条和重试按钮显隐，不替换整行。

- [ ] **步骤 3：将上传状态通知改为局部更新**

替换 `postRender()`：

```java
private void postTaskUpdate(final String taskId) {
    mainHandler.post(() -> {
        if ("queue".equals(screen)) {
            refreshQueueSummary();
            refreshQueueRow(taskId);
        }
    });
}
```

同步开始/结束时只更新当前页面按钮和汇总；每个任务开始/完成/失败时调用
`postTaskUpdate(task.id())`。

- [ ] **步骤 4：分页只追加新行**

滚动到底部时计算原 `queueVisibleLimit` 和新 limit，仅把新增区间的任务行
追加到 `queueTaskContainer`。不得调用 `render()`，并在追加结束后清除
`queueAutoLoading`。

- [ ] **步骤 5：筛选仍执行一次明确重建**

切换筛选时重置 limit 和滚动位置，允许调用一次 `render()`。确认自动分页
和后台上传状态不会触发 `setContentView`。

- [ ] **步骤 6：重新编译**

运行：

```bash
./android/run_tests.sh
./android/build.sh
```

预期：通过。

- [ ] **步骤 7：提交**

```bash
git add android/src/main/java/com/androidsync/app/MainActivity.java
git commit -m "fix: update Android queue in place"
```

### 任务 4：建立 macOS 查询、本地化和版本测试边界

**文件：**

- 修改：`macos/Package.swift`
- 新建：`macos/Sources/AndroidSyncMac/Support/Localization.swift`
- 新建：`macos/Sources/AndroidSyncMac/Support/AppVersionInfo.swift`
- 新建：`macos/Tests/AndroidSyncMacTests/AppModelQueryTests.swift`
- 新建：`macos/Tests/AndroidSyncMacTests/LocalizationTests.swift`
- 新建：`macos/Tests/AndroidSyncMacTests/AppVersionInfoTests.swift`

- [ ] **步骤 1：增加应用测试目标**

```swift
.testTarget(
    name: "AndroidSyncMacTests",
    dependencies: ["AndroidSyncMac", "AndroidSyncCore"],
    path: "Tests/AndroidSyncMacTests"
)
```

- [ ] **步骤 2：写失败的排序和日期测试**

测试三条记录：

```swift
XCTAssertEqual(query(sort: .newest).map(\.filename), ["new.jpg", "middle.jpg", "old.jpg"])
XCTAssertEqual(query(sort: .oldest).map(\.filename), ["old.jpg", "middle.jpg", "new.jpg"])
XCTAssertEqual(query(dateFilter: .today).map(\.filename), ["new.jpg"])
```

测试必须使用固定 `now` 和固定 `Calendar`，不依赖真实当前时间。

- [ ] **步骤 3：写失败的本地化测试**

```swift
XCTAssertEqual(AppLanguage.defaultLanguage, .simplifiedChinese)
XCTAssertEqual(AppStrings.text(.settings, language: .simplifiedChinese), "设置")
XCTAssertEqual(AppStrings.text(.settings, language: .english), "Settings")
```

- [ ] **步骤 4：写失败的版本测试**

使用注入字典：

```swift
let info = AppVersionInfo(infoDictionary: [
    "CFBundleShortVersionString": "1.2.3",
    "CFBundleVersion": "42"
])
XCTAssertEqual(info.displayText, "1.2.3 (42)")
```

- [ ] **步骤 5：运行并确认失败**

运行：

```bash
swift test --package-path macos
```

预期：缺少类型和查询注入点而失败。

- [ ] **步骤 6：实现最小纯逻辑边界**

新增：

```swift
enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    static let defaultLanguage: Self = .simplifiedChinese
}

enum AppStringKey {
    case settings
    // 后续视图使用的所有键集中放置
}

struct AppVersionInfo {
    let version: String
    let build: String
    var displayText: String { "\(version) (\(build))" }
}
```

将 `AppModel.filteredItems` 的筛选排序提取到可传入 `now` 和 `calendar` 的
内部方法，生产代码使用 `Date()`。

- [ ] **步骤 7：运行测试**

```bash
swift test --package-path macos
```

预期：新增测试和现有 Core 测试全部通过。

- [ ] **步骤 8：提交**

```bash
git add macos/Package.swift macos/Sources/AndroidSyncMac/Support macos/Tests/AndroidSyncMacTests macos/Sources/AndroidSyncMac/Stores/AppModel.swift
git commit -m "test: define macOS query localization and version behavior"
```

### 任务 5：实现 macOS 手动中英文切换

**文件：**

- 修改：`macos/Sources/AndroidSyncMac/Support/Localization.swift`
- 修改：`macos/Sources/AndroidSyncMac/Stores/AppModel.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/SidebarView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/ReceiverStatusView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/LibraryView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/InspectorView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/MenuBarView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/OnboardingView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/SettingsView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/ContentView.swift`

- [ ] **步骤 1：把语言偏好加入 AppModel**

```swift
var language: AppLanguage {
    didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
}

func text(_ key: AppStringKey) -> String {
    AppStrings.text(key, language: language)
}
```

初始化时没有保存值则使用 `.simplifiedChinese`。

- [ ] **步骤 2：补齐集中式中英文键**

覆盖侧栏、接收状态、空状态、工具栏、Inspector、重命名、菜单栏、设置、
错误标题和按钮。禁止在多个 View 中重复维护同一组翻译。

- [ ] **步骤 3：替换各 View 的硬编码字符串**

示例：

```swift
Text(model.text(.noReceivedFiles))
Button(model.text(.quickLook)) { model.preview(item) }
```

枚举标题由 `title` 改为：

```swift
func title(using model: AppModel) -> String
```

- [ ] **步骤 4：在设置中增加语言 Picker**

```swift
Picker(model.text(.language), selection: $model.language) {
    Text("简体中文").tag(AppLanguage.simplifiedChinese)
    Text("English").tag(AppLanguage.english)
}
```

- [ ] **步骤 5：运行测试和编译**

```bash
swift test --package-path macos
swift build --package-path macos
```

预期：通过。

- [ ] **步骤 6：提交**

```bash
git add macos/Sources/AndroidSyncMac
git commit -m "feat: add macOS Chinese and English localization"
```

### 任务 6：迁移到原生工具栏并修复菜单、Inspector 和搜索

**文件：**

- 修改：`macos/Sources/AndroidSyncMac/Views/ContentView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/LibraryToolbar.swift`

- [ ] **步骤 1：把 LibraryToolbar 改为 ToolbarContent**

```swift
struct LibraryToolbar: ToolbarContent {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) { categoryTitle }
        ToolbarItemGroup(placement: .primaryAction) {
            dateMenu
            sortMenu
            layoutPicker
            Button(action: openSettings.callAsFunction) {
                Label(model.text(.settings), systemImage: "gearshape")
            }
            Button { model.inspectorPresented.toggle() } label: {
                Label(model.text(.inspector), systemImage: "sidebar.right")
            }
        }
    }
}
```

- [ ] **步骤 2：日期和排序使用直接 Button**

```swift
Menu {
    ForEach(LibraryDateFilter.allCases) { filter in
        Button {
            model.dateFilter = filter
        } label: {
            if model.dateFilter == filter {
                Label(filter.title(using: model), systemImage: "checkmark")
            } else {
                Text(filter.title(using: model))
            }
        }
    }
} label: {
    Label(model.dateFilter.title(using: model), systemImage: "calendar")
}
```

排序菜单使用相同结构，不再嵌套 `Picker`。

- [ ] **步骤 3：从详情内容移除旧工具栏行**

`ContentView` 中删除：

```swift
LibraryToolbar(model: model)
```

改为：

```swift
.toolbar {
    LibraryToolbar(model: model)
}
.searchable(
    text: $model.searchText,
    placement: .toolbar,
    prompt: model.text(.searchFilenames)
)
```

- [ ] **步骤 4：保持 Inspector 绑定在详情层**

Inspector 继续由详情内容的 `.inspector(isPresented:)` 管理，按钮位于窗口
右上角工具栏。

- [ ] **步骤 5：编译**

```bash
swift build --package-path macos
swift test --package-path macos
```

预期：通过。

- [ ] **步骤 6：提交**

```bash
git add macos/Sources/AndroidSyncMac/Views/ContentView.swift macos/Sources/AndroidSyncMac/Views/LibraryToolbar.swift
git commit -m "fix: use native macOS library toolbar"
```

### 任务 7：固定 macOS 缩略图布局

**文件：**

- 修改：`macos/Sources/AndroidSyncMac/Views/ThumbnailView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/LibraryView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/InspectorView.swift`

- [ ] **步骤 1：ThumbnailView 改为等比完整缩放**

```swift
Image(nsImage: image)
    .resizable()
    .scaledToFit()
    .frame(width: size.width, height: size.height)
```

根容器固定为传入尺寸，并使用中性背景和 `.clipped()`。

- [ ] **步骤 2：网格使用固定 180 × 124**

```swift
LazyVGrid(
    columns: [GridItem(.adaptive(minimum: 180, maximum: 180), spacing: 16)],
    spacing: 18
)
```

`MediaGridItem`：

```swift
ThumbnailView(item: item, size: CGSize(width: 180, height: 124))
    .frame(width: 180, height: 124)
    .clipShape(RoundedRectangle(cornerRadius: 9))
```

元数据区域设置固定宽度 180，文件名保持一行。

- [ ] **步骤 3：列表和 Inspector 使用固定尺寸**

- 列表：56 × 42
- Inspector：240 × 166

不得使用 `frame(maxWidth: .infinity)` 与可变 aspect ratio 组合。

- [ ] **步骤 4：编译**

```bash
swift build --package-path macos
```

预期：通过。

- [ ] **步骤 5：提交**

```bash
git add macos/Sources/AndroidSyncMac/Views/ThumbnailView.swift macos/Sources/AndroidSyncMac/Views/LibraryView.swift macos/Sources/AndroidSyncMac/Views/InspectorView.swift
git commit -m "fix: stabilize macOS thumbnail layout"
```

### 任务 8：实现空格切换 Quick Look

**文件：**

- 修改：`macos/Sources/AndroidSyncMac/Services/QuickLookPreview.swift`
- 修改：`macos/Sources/AndroidSyncMac/Stores/AppModel.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/ContentView.swift`

- [ ] **步骤 1：先增加 QuickLookPreview 行为测试接口**

将 panel 操作收敛为：

```swift
var isPresented: Bool { QLPreviewPanel.sharedPreviewPanelExists() }
func toggle(_ url: URL)
func close()
```

`close()` 必须 `orderOut(nil)` 并把保留 URL 设为 `nil`。

- [ ] **步骤 2：AppModel 增加选中项切换方法**

```swift
func toggleSelectedPreview() {
    guard let item = selectedItem, !item.deleted else { return }
    QuickLookPreview.shared.toggle(item.fileURL)
}
```

- [ ] **步骤 3：在 ContentView 处理空格**

```swift
.onKeyPress(.space) {
    guard !renamePresented, model.selectedItem != nil else { return .ignored }
    model.toggleSelectedPreview()
    return .handled
}
.focusable()
```

确认搜索框或重命名 TextField 获得焦点时由文本控件消费空格，不触发预览。

- [ ] **步骤 4：编译和测试**

```bash
swift test --package-path macos
swift build --package-path macos
```

- [ ] **步骤 5：提交**

```bash
git add macos/Sources/AndroidSyncMac/Services/QuickLookPreview.swift macos/Sources/AndroidSyncMac/Stores/AppModel.swift macos/Sources/AndroidSyncMac/Views/ContentView.swift
git commit -m "feat: toggle Quick Look with space"
```

### 任务 9：区分服务失败与单次上传失败并清理临时状态

**文件：**

- 修改：`macos/Sources/AndroidSyncCore/ReceiverService.swift`
- 修改：`macos/Tests/AndroidSyncCoreTests/ReceiverServiceTests.swift`
- 修改：`macos/Sources/AndroidSyncMac/Stores/AppModel.swift`
- 修改：`macos/Sources/AndroidSyncMac/Views/ReceiverStatusView.swift`

- [ ] **步骤 1：写失败的中断上传测试**

启动真实服务，发送声明 `Content-Length: 8` 但只写入 3 字节后断开连接，
等待事件后断言：

```swift
XCTAssertTrue(events.contains { event in
    if case .uploadFailed(filename: "broken.jpg", message: _) = event { return true }
    return false
})
XCTAssertTrue(try FileManager.default.contentsOfDirectory(
    at: root.appendingPathComponent(".incoming"),
    includingPropertiesForKeys: nil
).isEmpty)
XCTAssertTrue(try await repository.manifest().isEmpty)
```

- [ ] **步骤 2：运行并确认失败**

```bash
swift test --package-path macos --filter ReceiverServiceTests
```

预期：`uploadFailed` 事件尚不存在或临时状态断言失败。

- [ ] **步骤 3：拆分事件类型**

```swift
case receiverFailed(message: String)
case uploadFailed(filename: String?, message: String)
```

Listener 失败发送 `receiverFailed`；`ReceiverConnection.fail` 在清理临时
文件后发送 `uploadFailed`。

- [ ] **步骤 4：AppModel 维护临时上传状态**

```swift
var activeUploads: [String: Int64] = [:]
var transientUploadMessage: String?
```

- `.uploadStarted`：加入
- `.uploadStored`：移除并重载图库
- `.uploadFailed`：移除，只更新短暂状态，不设置 `lastError`
- `.receiverFailed`：更新接收器失败状态和全局错误

- [ ] **步骤 5：ReceiverStatusView 显示临时状态**

存在上传时显示正在接收的文件；上传失败后显示短暂失败信息，但主状态仍为
“准备接收”。

- [ ] **步骤 6：运行测试**

```bash
swift test --package-path macos
```

预期：全部通过，失败上传无 manifest、无 SwiftData 来源记录、无 `.part`。

- [ ] **步骤 7：提交**

```bash
git add macos/Sources/AndroidSyncCore/ReceiverService.swift macos/Tests/AndroidSyncCoreTests/ReceiverServiceTests.swift macos/Sources/AndroidSyncMac/Stores/AppModel.swift macos/Sources/AndroidSyncMac/Views/ReceiverStatusView.swift
git commit -m "fix: clean failed macOS uploads"
```

### 任务 10：完成设置入口、版本号和构建号

**文件：**

- 修改：`macos/Sources/AndroidSyncMac/Views/SettingsView.swift`
- 修改：`macos/Sources/AndroidSyncMac/Support/AppVersionInfo.swift`
- 修改：`macos/build_and_run.sh`
- 修改：`macos/README.md`

- [ ] **步骤 1：设置中显示版本**

```swift
Section(model.text(.about)) {
    LabeledContent(model.text(.version), value: AppVersionInfo.current.version)
    LabeledContent(model.text(.build), value: AppVersionInfo.current.build)
}
```

- [ ] **步骤 2：生成构建号**

在打包脚本中：

```bash
if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD)"
else
  BUILD_NUMBER="$(date +%Y%m%d%H%M)"
fi
```

把固定的：

```xml
<string>1</string>
```

替换为 `$BUILD_NUMBER`。

- [ ] **步骤 3：验证 Info.plist**

运行：

```bash
./macos/build_and_run.sh verify
plutil -p "dist/Android Sync.app/Contents/Info.plist"
```

预期：

- `CFBundleShortVersionString` 等于 `VERSION`
- `CFBundleVersion` 等于当前 Git 提交数

- [ ] **步骤 4：更新 README**

说明语言设置、版本/构建号来源和空格 Quick Look。

- [ ] **步骤 5：提交**

```bash
git add macos/Sources/AndroidSyncMac/Views/SettingsView.swift macos/Sources/AndroidSyncMac/Support/AppVersionInfo.swift macos/build_and_run.sh macos/README.md
git commit -m "feat: add macOS settings version information"
```

### 任务 11：双端完整验证与运行时 QA

**文件：**

- 可能修改：`CHANGELOG.md`

- [ ] **步骤 1：运行静态和单元测试**

```bash
./android/run_tests.sh
swift test --package-path macos
git diff --check
```

预期：全部通过且无空白错误。

- [ ] **步骤 2：构建双端产物**

```bash
./android/build.sh
./macos/build_and_run.sh verify
```

预期：APK 签名成功；macOS App 启动成功。

- [ ] **步骤 3：验证 macOS App 包**

```bash
plutil -lint "dist/Android Sync.app/Contents/Info.plist"
codesign --verify --deep --strict "dist/Android Sync.app"
```

预期：两条命令退出码均为 0。

- [ ] **步骤 4：macOS 运行时检查**

逐项确认：

- 默认中文
- 设置中切换英文后主窗口即时更新
- 搜索在工具栏且不遮挡 Inspector
- Inspector 按钮位于右上角
- 日期/排序点击后只有一层菜单
- “最新优先”第一项为最近接收文件
- 网格缩略图固定、不重叠、完整等比显示
- 空格打开 Quick Look，再按空格关闭
- 设置齿轮打开设置窗口
- 设置中显示发布版本和构建号
- 中断上传后 `.incoming` 无残留，图库无失败记录

- [ ] **步骤 5：Android 真机安装与日志检查**

连接当前可用设备后：

```bash
adb install -r android/build/AndroidSync-debug.apk
adb logcat -c
```

操作首页、队列自动分页、上传和详情预览，再检查：

```bash
adb logcat -d | rg "AndroidRuntime|FATAL EXCEPTION|OutOfMemoryError|ANR|Skipped [0-9]+ frames|MainActivity"
```

预期：无 OOM、Fatal Exception 和 ANR；队列状态变化不整页闪烁。

- [ ] **步骤 6：更新变更日志**

在 `CHANGELOG.md` 的未发布版本中记录本次 Android 稳定性和 macOS 体验改进。

- [ ] **步骤 7：最终提交**

```bash
git add CHANGELOG.md
git commit -m "docs: record stability and macOS UX improvements"
```
