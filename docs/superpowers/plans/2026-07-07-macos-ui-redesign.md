# macOS UI/UX 重设计实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 `docs/superpowers/specs/2026-07-07-macos-ui-redesign-design.md` 把 macOS 端重做为强制深色媒体工作台：主题 token、工具栏状态胶囊、侧栏计数、网格上方传输卡片行、高密度网格，最后为进度条/速度扩展 ReceiverService 进度事件。

**Architecture:** 渐进重构 View 层。AppModel 只新增可测试的计算属性与传输卡片状态机，既有行为不动；除最后一个任务外不触碰 Services。所有新视觉常量集中在新建的 `Theme.swift`。

**Tech Stack:** SwiftUI、AppKit、SwiftData、QuickLookThumbnailing、AVFoundation（均为系统框架，不新增依赖）。

## Global Constraints

- 开工前置：当前工作树中 B09 未提交改动（`MediaItemEntity.swift`、`AppModel.swift`、`InspectorView.swift`、`LibraryView.swift`、`ThumbnailView.swift`、`AppModelDeleteTests.swift`、PROJECT_MEMORY 文档）必须先行提交；`git status --short` 里不得残留这些文件再开始 Task 1。
- 不新增第三方依赖、不新增构建系统。
- 全部新用户可见文案必须走 `AppStringKey`（`macos/Sources/AndroidSyncMac/Support/Localization.swift`），中文（`.simplifiedChinese`）和英文（`.english`）两张表都要加；`LocalizationTests` 会因缺表项失败。
- 每个任务收尾：`swift test --package-path macos` 全绿（基线 78 个测试）+ `./macos/build_and_run.sh verify` 通过。
- 每个任务一次独立 git 提交。spec 批次与任务对应：批次1=Task 1–3、批次2=Task 4、批次3=Task 5–6、批次4=Task 7–8、批次5=Task 9、批次6=Task 10。每个批次的最后一个任务提交时，在 `PROJECT_MEMORY/batches/` 新增 `2026-MM-DD-BNN-*.md` 批次记录（编号从 B10 顺延），并更新 `PROJECT_MEMORY/00_PROJECT_STATUS.md` 与 `PROJECT_MEMORY/HANDOFF.md`。
- 已知过渡态：Task 3 删除状态条后到 Task 6 卡片行落地前，`transientUploadMessage` 暂无展示位。批次 1 与批次 3 须在同一发布列车内完成，不得单独发版。
- 文档一律中文；代码符号、命令保留原文。

---

### Task 1: Theme token 与强制深色

**Files:**
- Create: `macos/Sources/AndroidSyncMac/Support/Theme.swift`
- Modify: `macos/Sources/AndroidSyncMac/App/AndroidSyncMacApp.swift`
- Test: `macos/Tests/AndroidSyncMacTests/ThemeTests.swift`

**Interfaces:**
- Consumes: 无
- Produces: `enum Theme`——`Theme.bg/bgRaised/bgSidebar/stroke/textPrimary/textSecondary/accent/statusRunning/statusFailed/statusIdle: Color`、`Theme.cardGradient: LinearGradient`、`Theme.spacingXS/spacingS/spacingM/spacingL: CGFloat`（4/8/12/16）、`Theme.radiusS/radiusL: CGFloat`（6/10）。后续所有任务的颜色与间距只从这里取。

- [ ] **Step 1: 写失败测试**

```swift
// macos/Tests/AndroidSyncMacTests/ThemeTests.swift
import XCTest
@testable import AndroidSyncMac

final class ThemeTests: XCTestCase {
    func testSpacingScale() {
        XCTAssertEqual(Theme.spacingXS, 4)
        XCTAssertEqual(Theme.spacingS, 8)
        XCTAssertEqual(Theme.spacingM, 12)
        XCTAssertEqual(Theme.spacingL, 16)
    }

    func testRadiusScale() {
        XCTAssertEqual(Theme.radiusS, 6)
        XCTAssertEqual(Theme.radiusL, 10)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --package-path macos --filter ThemeTests`
Expected: 编译失败 `cannot find 'Theme' in scope`

- [ ] **Step 3: 写 Theme.swift**

```swift
// macos/Sources/AndroidSyncMac/Support/Theme.swift
import SwiftUI

/// 深色工作台主题 token。所有视图的颜色、间距、圆角只从这里取，
/// 不在视图内散落硬编码。取值见 spec
/// docs/superpowers/specs/2026-07-07-macos-ui-redesign-design.md。
enum Theme {
    // 色板
    static let bg = Color(red: 0.118, green: 0.118, blue: 0.137)            // #1E1E23
    static let bgRaised = Color(red: 0.169, green: 0.169, blue: 0.192)      // #2B2B31
    static let bgSidebar = Color(red: 0.110, green: 0.110, blue: 0.129)     // #1C1C21
    static let stroke = Color(red: 0.220, green: 0.220, blue: 0.247)        // #38383F
    static let textPrimary = Color(red: 0.933, green: 0.933, blue: 0.941)   // #EEEEF0
    static let textSecondary = Color(red: 0.604, green: 0.604, blue: 0.639) // #9A9AA3
    static let accent = Color(red: 0.910, green: 0.639, blue: 0.239)        // #E8A33D
    static let statusRunning = Color(red: 0.298, green: 0.851, blue: 0.392) // #4CD964
    static let statusFailed = Color(red: 1.0, green: 0.373, blue: 0.341)    // #FF5F57
    static let statusIdle = textSecondary
    static let cardGradient = LinearGradient(
        colors: [
            Color(red: 0.310, green: 0.486, blue: 0.941),                   // #4F7CF0
            Color(red: 0.416, green: 0.361, blue: 0.847),                   // #6A5CD8
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // 间距
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16

    // 圆角
    static let radiusS: CGFloat = 6
    static let radiusL: CGFloat = 10
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --package-path macos --filter ThemeTests`
Expected: PASS

- [ ] **Step 5: App 三个 Scene 强制深色**

`AndroidSyncMacApp.swift` 中三处各加一行 `.preferredColorScheme(.dark)`：

```swift
        WindowGroup("Android Sync", id: "main") {
            ContentView(model: appModel)
                .frame(minWidth: 860, minHeight: 560)
                .environment(\.locale, appModel.language.locale)
                .preferredColorScheme(.dark)
                .task { await appModel.launchIfNeeded() }
        }
```

```swift
        MenuBarExtra("Android Sync", systemImage: appModel.menuBarSystemImage) {
            MenuBarView(model: appModel)
                .environment(\.locale, appModel.language.locale)
                .preferredColorScheme(.dark)
        }
```

```swift
        Settings {
            SettingsView(model: appModel)
                .environment(\.locale, appModel.language.locale)
                .preferredColorScheme(.dark)
        }
```

- [ ] **Step 6: 全量验证**

Run: `swift test --package-path macos && ./macos/build_and_run.sh verify`
Expected: 全绿；verify 通过

- [ ] **Step 7: 提交**

```bash
git add macos/Sources/AndroidSyncMac/Support/Theme.swift \
        macos/Sources/AndroidSyncMac/App/AndroidSyncMacApp.swift \
        macos/Tests/AndroidSyncMacTests/ThemeTests.swift
git commit -m "feat: macOS 深色主题 token 与强制深色"
```

---

### Task 2: AppModel 状态胶囊文案（视图逻辑下沉）

**Files:**
- Modify: `macos/Sources/AndroidSyncMac/Stores/AppModel.swift`（`menuBarSystemImage` 附近，约 355 行后）
- Test: `macos/Tests/AndroidSyncMacTests/AppModelStatusCapsuleTests.swift`

**Interfaces:**
- Consumes: 现有 `ReceiverStatus`、`activeUploads`、`text(_:)`、`format(_:_:)`
- Produces: `var statusCapsuleTitle: String`、`var statusCapsuleDetail: String`（Task 3 的 `StatusCapsuleView` 消费）

- [ ] **Step 1: 写失败测试**

```swift
// macos/Tests/AndroidSyncMacTests/AppModelStatusCapsuleTests.swift
import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class AppModelStatusCapsuleTests: XCTestCase {
    private func makeModel() throws -> AppModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: config
        )
        return AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
    }

    func testTitleCoversAllFiveStatuses() throws {
        let model = try makeModel()
        let cases: [(ReceiverStatus, AppStringKey)] = [
            (.needsDirectory, .receiveFolderRequired),
            (.stopped, .receiverPaused),
            (.starting, .startingReceiver),
            (.running, .readyToReceive),
            (.failed("x"), .receiverUnavailable),
        ]
        for (status, key) in cases {
            model.status = status
            XCTAssertEqual(model.statusCapsuleTitle, model.text(key))
        }
    }

    func testTitleShowsReceivingCountWhileRunning() throws {
        let model = try makeModel()
        model.status = .running
        model.activeUploads[UUID()] = ActiveUpload(
            id: UUID(), filename: "a.jpg", expectedSize: 1
        )
        XCTAssertEqual(
            model.statusCapsuleTitle,
            model.format(.receivingFilesFormat, 1)
        )
    }

    func testDetailFallsBackToPortWhenNoURL() throws {
        let model = try makeModel()
        model.uploadURL = ""
        XCTAssertEqual(
            model.statusCapsuleDetail,
            model.format(.portFormat, Int(model.port))
        )
        model.uploadURL = "http://192.168.1.8:8765/uploads/"
        XCTAssertEqual(model.statusCapsuleDetail, model.uploadURL)
    }
}
```

若既有 `AppModelQueryTests` 已有等价 `makeModel` helper，复用其构造方式。

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --package-path macos --filter AppModelStatusCapsuleTests`
Expected: 编译失败 `value of type 'AppModel' has no member 'statusCapsuleTitle'`

- [ ] **Step 3: AppModel 加两个计算属性**

加在 `menuBarSystemImage` 之后：

```swift
    var statusCapsuleTitle: String {
        if isRunning, !activeUploads.isEmpty {
            return format(.receivingFilesFormat, activeUploads.count)
        }
        return switch status {
        case .needsDirectory: text(.receiveFolderRequired)
        case .stopped: text(.receiverPaused)
        case .starting: text(.startingReceiver)
        case .running: text(.readyToReceive)
        case .failed: text(.receiverUnavailable)
        }
    }

    var statusCapsuleDetail: String {
        uploadURL.isEmpty ? format(.portFormat, Int(port)) : uploadURL
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --package-path macos --filter AppModelStatusCapsuleTests`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add macos/Sources/AndroidSyncMac/Stores/AppModel.swift \
        macos/Tests/AndroidSyncMacTests/AppModelStatusCapsuleTests.swift
git commit -m "feat: 状态胶囊文案下沉到 AppModel"
```

---

### Task 3: StatusCapsuleView，删除 ReceiverStatusView

**Files:**
- Create: `macos/Sources/AndroidSyncMac/Views/StatusCapsuleView.swift`
- Modify: `macos/Sources/AndroidSyncMac/Views/LibraryToolbar.swift`、`macos/Sources/AndroidSyncMac/Views/ContentView.swift:16-23`
- Delete: `macos/Sources/AndroidSyncMac/Views/ReceiverStatusView.swift`

**Interfaces:**
- Consumes: Task 1 `Theme`、Task 2 `statusCapsuleTitle/statusCapsuleDetail`、现有 `model.toggleReceiver()`、`model.isRunning`、`model.uploadURL`、`model.status`
- Produces: `struct StatusCapsuleView: View`（仅 `LibraryToolbar` 使用）

- [ ] **Step 1: 写 StatusCapsuleView**

```swift
// macos/Sources/AndroidSyncMac/Views/StatusCapsuleView.swift
import AppKit
import SwiftUI

struct StatusCapsuleView: View {
    @Bindable var model: AppModel

    var body: some View {
        Menu {
            Button(model.text(model.isRunning ? .pause : .start)) {
                model.toggleReceiver()
            }
            if !model.uploadURL.isEmpty {
                Button(model.text(.copyAddress)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        model.uploadURL,
                        forType: .string
                    )
                }
            }
            Divider()
            Text(model.statusCapsuleDetail)
        } label: {
            HStack(spacing: Theme.spacingXS + 2) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(model.statusCapsuleTitle)
                    .font(.callout)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(model.statusCapsuleDetail)
    }

    private var statusColor: Color {
        switch model.status {
        case .running: Theme.statusRunning
        case .failed: Theme.statusFailed
        case .starting, .needsDirectory, .stopped: Theme.statusIdle
        }
    }
}
```

- [ ] **Step 2: 挂进工具栏**

`LibraryToolbar.swift` 的 `var body: some ToolbarContent` 开头（`if model.receiveDirectory != nil` 之前）加：

```swift
        ToolbarItem(placement: .status) {
            StatusCapsuleView(model: model)
        }
```

- [ ] **Step 3: ContentView 删状态条**

`ContentView.swift` 中删除：

```swift
                    VStack(spacing: 0) {
                        ReceiverStatusView(model: model)
                        Divider()
                        LibraryView(
```

改为：

```swift
                    VStack(spacing: 0) {
                        LibraryView(
```

- [ ] **Step 4: 删文件**

```bash
git rm macos/Sources/AndroidSyncMac/Views/ReceiverStatusView.swift
```

- [ ] **Step 5: 全量验证**

Run: `swift test --package-path macos && ./macos/build_and_run.sh verify`
Expected: 全绿；verify 通过

- [ ] **Step 6: 手工核对五种状态（spec 风险项）**

Run: `./macos/build_and_run.sh`
逐一确认胶囊呈现：未选目录（needsDirectory）、暂停（点菜单"暂停"）、启动中（点"启动"瞬间）、运行中、失败（把端口改成已占用端口触发）。每种状态胶囊都有文案和圆点颜色，菜单里能暂停/启动、能复制地址。

- [ ] **Step 7: 提交（批次 1 收尾）**

新增 `PROJECT_MEMORY/batches/` 批次记录（B10：主题 + 状态胶囊），更新 `00_PROJECT_STATUS.md`、`HANDOFF.md`，然后：

```bash
git add -A macos/Sources/AndroidSyncMac/Views/ PROJECT_MEMORY/
git commit -m "feat: 工具栏状态胶囊替代顶部状态条"
```

---

### Task 4: 侧栏分类计数与深色样式

**Files:**
- Modify: `macos/Sources/AndroidSyncMac/Stores/AppModel.swift`（`filteredItems` 附近）、`macos/Sources/AndroidSyncMac/Views/SidebarView.swift`
- Test: `macos/Tests/AndroidSyncMacTests/AppModelSidebarCountTests.swift`

**Interfaces:**
- Consumes: 现有 `AppModel.filterItems(...)` 静态方法、Task 1 `Theme`
- Produces: `func categoryCount(_ category: LibraryCategory) -> Int`

- [ ] **Step 1: 写失败测试**

```swift
// macos/Tests/AndroidSyncMacTests/AppModelSidebarCountTests.swift
import SwiftData
import XCTest
@testable import AndroidSyncMac
import AndroidSyncCore

@MainActor
final class AppModelSidebarCountTests: XCTestCase {
    private func makeItem(
        kind: UploadKind,
        removed: Bool = false
    ) -> MediaItemEntity {
        let record = UploadRecord(
            id: UUID(),
            filename: "f",
            originalFilename: "f",
            kind: kind,
            sizeBytes: 10,
            contentType: nil,
            stableID: nil,
            dateModifiedMillis: nil,
            dateTakenMillis: nil,
            dateAddedMillis: nil,
            sourceIP: nil,
            receivedAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/f"),
            deleted: removed
        )
        return MediaItemEntity(record: record)
    }

    func testCategoryCountIgnoresSearchAndDateFilter() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: config
        )
        let model = AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        model.items = [
            makeItem(kind: .photo),
            makeItem(kind: .photo),
            makeItem(kind: .video),
            makeItem(kind: .photo, removed: true),
        ]
        model.searchText = "不匹配任何文件"
        model.dateFilter = .today
        XCTAssertEqual(model.categoryCount(.all), 3)
        XCTAssertEqual(model.categoryCount(.photos), 2)
        XCTAssertEqual(model.categoryCount(.videos), 1)
        XCTAssertEqual(model.categoryCount(.deleted), 1)
    }
}
```

`UploadRecord` 的成员顺序以 `AndroidSyncCore` 实际定义为准；若既有测试已有 item 构造 helper，复用。

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --package-path macos --filter AppModelSidebarCountTests`
Expected: 编译失败 `no member 'categoryCount'`

- [ ] **Step 3: AppModel 实现**

加在 `filteredItems` 之后：

```swift
    func categoryCount(_ category: LibraryCategory) -> Int {
        Self.filterItems(
            items,
            category: category,
            dateFilter: .all,
            sort: .newest,
            searchText: "",
            now: Date(),
            calendar: .current
        ).count
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --package-path macos --filter AppModelSidebarCountTests`
Expected: PASS

- [ ] **Step 5: SidebarView 重样式**

整体替换 `SidebarView.swift` 的 `body`：

```swift
    var body: some View {
        List(LibraryCategory.allCases, selection: $model.category) { category in
            Label(
                category.title(using: model.language),
                systemImage: category.systemImage
            )
            .badge(
                Text("\(model.categoryCount(category))")
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            )
            .tag(category)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Theme.bgSidebar)
        .navigationTitle("Android Sync")
        .safeAreaInset(edge: .bottom) {
            if let directory = model.receiveDirectory {
                Button {
                    model.openReceiveDirectory()
                } label: {
                    Label(directory.lastPathComponent, systemImage: "folder")
                        .lineLimit(1)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(Theme.spacingM)
                .help(directory.path)
            }
        }
    }
```

- [ ] **Step 6: 全量验证**

Run: `swift test --package-path macos && ./macos/build_and_run.sh verify`
Expected: 全绿；verify 通过

- [ ] **Step 7: 提交（批次 2 收尾，含批次记录 B11 与状态/交接文档更新）**

```bash
git add macos/Sources/AndroidSyncMac/Stores/AppModel.swift \
        macos/Sources/AndroidSyncMac/Views/SidebarView.swift \
        macos/Tests/AndroidSyncMacTests/AppModelSidebarCountTests.swift \
        PROJECT_MEMORY/
git commit -m "feat: 侧栏分类计数与深色样式"
```

---

### Task 5: 今日统计与传输卡片状态机（AppModel 逻辑）

**Files:**
- Modify: `macos/Sources/AndroidSyncMac/Stores/AppModel.swift`（属性区约 202 行、`handle(_:generation:)` 约 834-872 行）
- Test: `macos/Tests/AndroidSyncMacTests/TransferCardStateTests.swift`、`macos/Tests/AndroidSyncMacTests/TestItems.swift`

**Interfaces:**
- Consumes: 现有 `handle(_ event: ReceiverServiceEvent, generation:)`、`activeUploads`
- Produces:
  - `enum TransferCardState: Equatable { case idle, receiving, completed(Int) }`
  - `private(set) var transferCardState: TransferCardState`
  - `var transferCompletionLinger: Duration`（默认 `.seconds(3)`，测试注入 `.zero`）
  - `private(set) var transferLingerTask: Task<Void, Never>?`（测试 await 用）
  - `struct TodayStats: Equatable { let count: Int; let bytes: Int64 }`
  - `var todayStats: TodayStats` 与 `static func todayStats(_:now:calendar:) -> TodayStats`
  - `var activeUploadsExpectedBytes: Int64`
  - 测试共享 helper `TestItems.item(kind:receivedAt:sizeBytes:removed:) -> MediaItemEntity`（把 Task 4 的 `makeItem` 提为共享，Task 4 测试同步改用）

- [ ] **Step 1: 写失败测试**

先建共享 helper（把 Task 4 的构造逻辑挪进来，Task 4 测试文件改为调用它）：

```swift
// macos/Tests/AndroidSyncMacTests/TestItems.swift
import Foundation
import AndroidSyncCore
@testable import AndroidSyncMac

enum TestItems {
    static func item(
        kind: UploadKind = .photo,
        receivedAt: Date = Date(),
        sizeBytes: Int64 = 10,
        removed: Bool = false
    ) -> MediaItemEntity {
        let record = UploadRecord(
            id: UUID(),
            filename: "f",
            originalFilename: "f",
            kind: kind,
            sizeBytes: sizeBytes,
            contentType: nil,
            stableID: nil,
            dateModifiedMillis: nil,
            dateTakenMillis: nil,
            dateAddedMillis: nil,
            sourceIP: nil,
            receivedAt: receivedAt,
            fileURL: URL(fileURLWithPath: "/tmp/f"),
            deleted: removed
        )
        return MediaItemEntity(record: record)
    }

    static func record(filename: String = "f") -> UploadRecord {
        item().uploadRecord
    }
}
```

```swift
// macos/Tests/AndroidSyncMacTests/TransferCardStateTests.swift
import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class TransferCardStateTests: XCTestCase {
    private func makeModel() throws -> AppModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: config
        )
        let model = AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        model.transferCompletionLinger = .zero
        return model
    }

    func testUploadLifecycleDrivesState() async throws {
        let model = try makeModel()
        let id = UUID()
        XCTAssertEqual(model.transferCardState, .idle)

        model.handle(.uploadStarted(id: id, filename: "a.jpg", expectedSize: 100))
        XCTAssertEqual(model.transferCardState, .receiving)
        XCTAssertEqual(model.activeUploadsExpectedBytes, 100)

        model.handle(.uploadStored(id: id, record: TestItems.record()))
        XCTAssertEqual(model.transferCardState, .completed(1))

        await model.transferLingerTask?.value
        XCTAssertEqual(model.transferCardState, .idle)
    }

    func testAllFailedBurstSkipsCompletedState() throws {
        let model = try makeModel()
        let id = UUID()
        model.handle(.uploadStarted(id: id, filename: "a.jpg", expectedSize: 100))
        model.handle(.uploadFailed(id: id, filename: "a.jpg", message: "x"))
        XCTAssertEqual(model.transferCardState, .idle)
    }

    func testTodayStatsCountsOnlyTodayAndNotRemoved() {
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let stats = AppModel.todayStats(
            [
                TestItems.item(receivedAt: now, sizeBytes: 10),
                TestItems.item(receivedAt: now, sizeBytes: 5, removed: true),
                TestItems.item(receivedAt: yesterday, sizeBytes: 100),
            ],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(stats, AppModel.TodayStats(count: 1, bytes: 10))
    }
}
```

`.uploadStored` 的 `record` 参数类型以 `ReceiverServiceEvent` 实际签名为准。

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --package-path macos --filter TransferCardStateTests`
Expected: 编译失败 `no member 'transferCardState'`

- [ ] **Step 3: AppModel 实现**

类型（放 `ActiveUpload` 之后）：

```swift
enum TransferCardState: Equatable {
    case idle
    case receiving
    case completed(Int)
}
```

属性（放 `transientUploadMessage` 之后）：

```swift
    private(set) var transferCardState: TransferCardState = .idle
    var transferCompletionLinger: Duration = .seconds(3)
    private(set) var transferLingerTask: Task<Void, Never>?
    private var burstCompletedCount = 0
```

计算属性与类型（放 `filteredItems` 之后）：

```swift
    struct TodayStats: Equatable {
        let count: Int
        let bytes: Int64
    }

    static func todayStats(
        _ items: [MediaItemEntity],
        now: Date,
        calendar: Calendar
    ) -> TodayStats {
        let startOfToday = calendar.startOfDay(for: now)
        let todays = items.filter {
            !$0.removed && $0.receivedAt >= startOfToday && $0.receivedAt <= now
        }
        return TodayStats(
            count: todays.count,
            bytes: todays.reduce(0) { $0 + $1.sizeBytes }
        )
    }

    var todayStats: TodayStats {
        Self.todayStats(items, now: Date(), calendar: .current)
    }

    var activeUploadsExpectedBytes: Int64 {
        activeUploads.values.reduce(0) { $0 + $1.expectedSize }
    }
```

`handle(_:generation:)` 各分支追加（既有语句保持在前）：

```swift
        case let .uploadStarted(id, filename, expectedSize):
            activeUploads[id] = ActiveUpload(
                id: id,
                filename: filename,
                expectedSize: expectedSize
            )
            transferLingerTask?.cancel()
            transferLingerTask = nil
            transferCardState = .receiving
        case let .uploadStored(id, _):
            activeUploads.removeValue(forKey: id)
            burstCompletedCount += 1
            if activeUploads.isEmpty {
                beginTransferLinger()
            }
            guard let repository else { return }
            // …既有 reloadLibrary Task 不动…
        case let .uploadFailed(id, filename, message):
            activeUploads.removeValue(forKey: id)
            showTransientUploadFailure(filename: filename, message: message)
            if activeUploads.isEmpty {
                if burstCompletedCount > 0 {
                    beginTransferLinger()
                } else {
                    resetTransferCard()
                }
            }
```

`case .stopped` 与 `case .receiverFailed` 里 `activeUploads.removeAll()` 之后各加一行 `resetTransferCard()`。

私有方法（放 `clearTransientUploadFailure()` 之后）：

```swift
    private func beginTransferLinger() {
        transferCardState = .completed(burstCompletedCount)
        transferLingerTask?.cancel()
        transferLingerTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: transferCompletionLinger)
            guard !Task.isCancelled else { return }
            self.transferCardState = .idle
            self.burstCompletedCount = 0
        }
    }

    private func resetTransferCard() {
        transferLingerTask?.cancel()
        transferLingerTask = nil
        transferCardState = .idle
        burstCompletedCount = 0
    }
```

注意：`.uploadStored` 分支中状态机语句必须在 `guard let repository` 之前（测试环境 repository 为 nil）。

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --package-path macos --filter TransferCardStateTests`
Expected: PASS

- [ ] **Step 5: 全量验证 + 提交**

Run: `swift test --package-path macos && ./macos/build_and_run.sh verify`

```bash
git add macos/Sources/AndroidSyncMac/Stores/AppModel.swift \
        macos/Tests/AndroidSyncMacTests/TransferCardStateTests.swift \
        macos/Tests/AndroidSyncMacTests/TestItems.swift \
        macos/Tests/AndroidSyncMacTests/AppModelSidebarCountTests.swift
git commit -m "feat: 传输卡片状态机与今日统计"
```

---

### Task 6: TransferCardRow 视图与接入

**Files:**
- Create: `macos/Sources/AndroidSyncMac/Views/TransferCardRow.swift`
- Modify: `macos/Sources/AndroidSyncMac/Support/Localization.swift`、`macos/Sources/AndroidSyncMac/Views/ContentView.swift`

**Interfaces:**
- Consumes: Task 5 `transferCardState/todayStats/activeUploadsExpectedBytes`、`transientUploadMessage`、Task 1 `Theme`
- Produces: `struct TransferCardRow: View`（仅 `ContentView` 使用）

- [ ] **Step 1: 加本地化 key（先加 enum case，跑 LocalizationTests 看失败，再补两表）**

`AppStringKey` 追加：

```swift
    case receivingSummaryFormat
    case todayReceived
    case itemsCountFormat
    case completedLingerFormat
```

Run: `swift test --package-path macos --filter LocalizationTests`
Expected: FAIL（新 key 缺表项）

中文表追加：

```swift
            .receivingSummaryFormat: "接收中 %d 个文件 · 预计 %@",
            .todayReceived: "今天已接收",
            .itemsCountFormat: "%d 项",
            .completedLingerFormat: "已完成 %d 项",
```

英文表追加：

```swift
            .receivingSummaryFormat: "Receiving %d files · about %@",
            .todayReceived: "Received today",
            .itemsCountFormat: "%d items",
            .completedLingerFormat: "Completed %d items",
```

Run: `swift test --package-path macos --filter LocalizationTests`
Expected: PASS

- [ ] **Step 2: 写 TransferCardRow**

```swift
// macos/Sources/AndroidSyncMac/Views/TransferCardRow.swift
import SwiftUI

struct TransferCardRow: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: Theme.spacingS) {
            if let message = model.transientUploadMessage {
                banner(message)
            }
            switch model.transferCardState {
            case .idle:
                EmptyView()
            case .receiving:
                HStack(spacing: Theme.spacingM) {
                    progressCard
                    statsCard
                }
            case let .completed(count):
                HStack(spacing: Theme.spacingM) {
                    completedCard(count)
                    statsCard
                }
            }
        }
        .padding(.horizontal, Theme.spacingL)
        .padding(.top, contentIsEmpty ? 0 : Theme.spacingM)
        .animation(
            .easeInOut(duration: 0.25),
            value: model.transferCardState
        )
        .animation(
            .easeInOut(duration: 0.25),
            value: model.transientUploadMessage
        )
    }

    private var contentIsEmpty: Bool {
        model.transferCardState == .idle
            && model.transientUploadMessage == nil
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Text(
                model.format(
                    .receivingSummaryFormat,
                    model.activeUploads.count,
                    model.formatByteCount(model.activeUploadsExpectedBytes)
                )
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            ProgressView()
                .progressViewStyle(.linear)
                .tint(.white)
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .fill(Theme.cardGradient)
        )
    }

    private func completedCard(_ count: Int) -> some View {
        HStack(spacing: Theme.spacingS) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.statusRunning)
            Text(model.format(.completedLingerFormat, count))
                .font(.callout.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .fill(Theme.bgRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .strokeBorder(Theme.stroke)
        )
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Text(model.text(.todayReceived))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: Theme.spacingS) {
                Text(model.format(.itemsCountFormat, model.todayStats.count))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(model.formatByteCount(model.todayStats.bytes))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.spacingM)
        .frame(width: 180, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .fill(Theme.bgRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .strokeBorder(Theme.stroke)
        )
    }

    private func banner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(Theme.statusFailed)
            .padding(.vertical, Theme.spacingS)
            .padding(.horizontal, Theme.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusS)
                    .fill(Theme.statusFailed.opacity(0.12))
            )
    }
}
```

- [ ] **Step 3: ContentView 接入**

Task 3 改过的位置：

```swift
                    VStack(spacing: 0) {
                        TransferCardRow(model: model)
                        LibraryView(
```

- [ ] **Step 4: 全量验证 + 手工核对**

Run: `swift test --package-path macos && ./macos/build_and_run.sh verify`
手工：`./macos/build_and_run.sh` 启动后空闲时内容区顶部无卡片行占位（网格满高）。

- [ ] **Step 5: 提交（批次 3 收尾，含批次记录 B12 与状态/交接文档更新）**

```bash
git add macos/Sources/AndroidSyncMac/Views/TransferCardRow.swift \
        macos/Sources/AndroidSyncMac/Views/ContentView.swift \
        macos/Sources/AndroidSyncMac/Support/Localization.swift \
        PROJECT_MEMORY/
git commit -m "feat: 网格上方传输卡片行"
```

---

### Task 7: 高密度网格、列表与缩略图

**Files:**
- Modify: `macos/Sources/AndroidSyncMac/Support/Theme.swift`、`macos/Sources/AndroidSyncMac/Views/ThumbnailView.swift`、`macos/Sources/AndroidSyncMac/Views/LibraryView.swift`、`macos/Sources/AndroidSyncMac/Views/InspectorView.swift:14`
- Test: `macos/Tests/AndroidSyncMacTests/ThumbnailMetricsTests.swift`（改写为 `Theme.Thumb` 断言）

**Interfaces:**
- Consumes: Task 1 `Theme`
- Produces: `Theme.Thumb.gridCell/gridGap/gridSize/listSize/inspectorSize/cornerRadius`；`ThumbnailMetrics` 枚举删除，全仓引用改为 `Theme.Thumb`

- [ ] **Step 1: 更新测试（先改测试）**

`ThumbnailMetricsTests.swift` 改为断言新常量：

```swift
import XCTest
@testable import AndroidSyncMac

final class ThumbnailMetricsTests: XCTestCase {
    func testThumbTokens() {
        XCTAssertEqual(Theme.Thumb.gridCell, 150)
        XCTAssertEqual(Theme.Thumb.gridGap, 3)
        XCTAssertEqual(
            Theme.Thumb.gridSize,
            CGSize(width: 150, height: 150)
        )
        XCTAssertEqual(Theme.Thumb.listSize, CGSize(width: 56, height: 42))
        XCTAssertEqual(
            Theme.Thumb.inspectorSize,
            CGSize(width: 240, height: 166)
        )
        XCTAssertEqual(Theme.Thumb.cornerRadius, Theme.radiusS)
    }
}
```

Run: `swift test --package-path macos --filter ThumbnailMetricsTests`
Expected: 编译失败 `no member 'Thumb'`

- [ ] **Step 2: Theme 加 Thumb，删 ThumbnailMetrics**

`Theme.swift` 追加：

```swift
extension Theme {
    /// 缩略图尺寸 token（原 ThumbnailMetrics，并入主题避免两套常量）。
    enum Thumb {
        static let gridCell: CGFloat = 150
        static let gridGap: CGFloat = 3
        static let gridSize = CGSize(width: gridCell, height: gridCell)
        static let listSize = CGSize(width: 56, height: 42)
        static let inspectorSize = CGSize(width: 240, height: 166)
        static let cornerRadius: CGFloat = Theme.radiusS
    }
}
```

`ThumbnailView.swift` 删除 `enum ThumbnailMetrics { ... }` 整块；全仓 `ThumbnailMetrics.` 替换为 `Theme.Thumb.`（出现于 `LibraryView.swift`、`ThumbnailView.swift`、`InspectorView.swift`）。

- [ ] **Step 3: ThumbnailView 深色 + 填充裁切**

`ZStack` 内改为：

```swift
            Theme.bgRaised
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
            } else {
```

（`Color(nsColor: .controlBackgroundColor)` → `Theme.bgRaised`；`scaledToFit` → `scaledToFill`，外层已有 `.clipped()`。）

- [ ] **Step 4: 网格高密度 + 无标签 + 时长角标**

`LibraryView.swift` 的 `grid`：`GridItem` spacing 与 `LazyVGrid` spacing 都改 `Theme.Thumb.gridGap`，`.padding(18)` 改 `.padding(Theme.spacingS)`，`minimum/maximum` 改 `Theme.Thumb.gridCell`。

`MediaGridItem` 的 `body` 整体替换：

```swift
    var body: some View {
        ThumbnailView(item: item, size: Theme.Thumb.gridSize)
            .overlay(alignment: .bottomTrailing) {
                if item.kind == .video {
                    DurationBadge(item: item)
                }
            }
            .clipShape(
                RoundedRectangle(cornerRadius: Theme.Thumb.cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Thumb.cornerRadius)
                    .stroke(
                        selected ? Theme.accent : .clear,
                        lineWidth: 2
                    )
            }
            .opacity(item.removed ? 0.45 : 1)
            .help(item.filename)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .onTapGesture(count: 2, perform: onPreview)
            .contextMenu {
                Button(model.text(.quickLook), action: onPreview)
                    .disabled(item.removed)
                Button(model.text(.showInFinder), action: onReveal)
                    .disabled(item.removed)
            }
    }
```

同文件新增：

```swift
private struct DurationBadge: View {
    let item: MediaItemEntity
    @State private var duration: String?

    var body: some View {
        Group {
            if let duration {
                Text(duration)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.spacingXS + 1)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.black.opacity(0.6))
                    )
                    .padding(Theme.spacingXS)
            }
        }
        .task(id: item.filePath) {
            guard !item.removed else { return }
            let asset = AVURLAsset(url: item.fileURL)
            guard let time = try? await asset.load(.duration) else { return }
            let seconds = Int(time.seconds.rounded())
            guard seconds > 0 else { return }
            duration = String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
    }
}
```

文件头部加 `import AVFoundation`。

- [ ] **Step 5: 列表深色**

`LibraryView.swift` 的 `list`：选中背景 `Color.accentColor.opacity(0.12)` 改 `Theme.accent.opacity(0.15)`；`List` 尾部追加 `.scrollContentBackground(.hidden)` 与 `.background(Theme.bg)`；网格 `ScrollView` 尾部追加 `.background(Theme.bg)`。

- [ ] **Step 6: 全量验证 + 提交**

Run: `swift test --package-path macos && ./macos/build_and_run.sh verify`

```bash
git add macos/Sources/AndroidSyncMac/Support/Theme.swift \
        macos/Sources/AndroidSyncMac/Views/ \
        macos/Tests/AndroidSyncMacTests/ThumbnailMetricsTests.swift
git commit -m "feat: 高密度深色网格与视频时长角标"
```

---

### Task 8: Inspector 与 RenameSheet 深色重样式

**Files:**
- Modify: `macos/Sources/AndroidSyncMac/Views/InspectorView.swift`、`macos/Sources/AndroidSyncMac/Views/ContentView.swift:68-93`（RenameSheet）

**Interfaces:**
- Consumes: Task 1 `Theme`、Task 7 `Theme.Thumb`
- Produces: 无新接口（纯样式）

- [ ] **Step 1: InspectorView 样式**

- `ThumbnailView(item:size:)` 的 `cornerRadius: 10` 改 `Theme.radiusL`。
- `Text(item.filename).font(.headline)` 加 `.foregroundStyle(Theme.textPrimary)`。
- `metadata` 的 `row(_:_:)` 中 `.foregroundStyle(.secondary)` 改 `.foregroundStyle(Theme.textSecondary)`。
- `ScrollView` 尾部追加 `.background(Theme.bg)`。
- 操作按钮（Quick Look / Finder / 重命名）统一 `.buttonStyle(.bordered)`；删除按钮保持 `role: .destructive` 并加 `.buttonStyle(.bordered)`。

- [ ] **Step 2: RenameSheet 样式**

`ContentView.swift` 中 `RenameSheet` 的外层 `VStack`：`.padding(20)` 改 `.padding(Theme.spacingL + Theme.spacingXS)`，`frame(width: 380)` 保留，追加 `.background(Theme.bgRaised)`。

- [ ] **Step 3: 全量验证 + 提交（批次 4 收尾，含批次记录 B13 与状态/交接文档更新）**

Run: `swift test --package-path macos && ./macos/build_and_run.sh verify`

```bash
git add macos/Sources/AndroidSyncMac/Views/ PROJECT_MEMORY/
git commit -m "feat: Inspector 与重命名弹窗深色化"
```

---

### Task 9: 设置、Onboarding 与菜单栏

**Files:**
- Modify: `macos/Sources/AndroidSyncMac/Views/OnboardingView.swift`、`macos/Sources/AndroidSyncMac/Views/SettingsView.swift`

**Interfaces:**
- Consumes: Task 1 `Theme`
- Produces: 无新接口（纯样式）

- [ ] **Step 1: OnboardingView 重做**

整体替换 `body`：

```swift
    var body: some View {
        VStack(spacing: Theme.spacingL) {
            ZStack {
                Circle()
                    .fill(Theme.cardGradient)
                    .frame(width: 96, height: 96)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white)
            }
            Text(model.text(.chooseReceiveFolder))
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(model.text(.onboardingDescription))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(model.text(.chooseFolderEllipsis)) {
                model.chooseDirectory()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
```

- [ ] **Step 2: SettingsView 最小调整**

强制深色已由 Task 1 覆盖。本步只做两处：根视图追加 `.tint(Theme.accent)`；若有硬编码浅色背景/系统色则替换为 Theme token，无则不动。

- [ ] **Step 3: MenuBarView 核对（不改样式）**

系统菜单内容不可主题化，`MenuBarView` 结构与文案保持不变，仅人工核对菜单在深色系统外观下显示正常。此项为明确豁免，不算跳过。

- [ ] **Step 4: 全量验证 + 提交（批次 5 收尾，含批次记录 B14 与状态/交接文档更新）**

Run: `swift test --package-path macos && ./macos/build_and_run.sh verify`

```bash
git add macos/Sources/AndroidSyncMac/Views/ PROJECT_MEMORY/
git commit -m "feat: Onboarding 与设置深色化"
```

---

### Task 10: ReceiverService 进度事件、进度条与速度

**Files:**
- Modify: `macos/Sources/AndroidSyncCore/ReceiverService.swift`（事件枚举约 5-12 行；`consumeBody` 约 523-546 行）、`macos/Sources/AndroidSyncMac/Stores/AppModel.swift`、`macos/Sources/AndroidSyncMac/Support/Localization.swift`、`macos/Sources/AndroidSyncMac/Views/TransferCardRow.swift`
- Test: `macos/Tests/AndroidSyncMacTests/TransferProgressTests.swift`

**Interfaces:**
- Consumes: Task 5 状态机、Task 6 视图
- Produces:
  - `ReceiverServiceEvent` 新 case：`uploadProgress(id: UUID, bytesReceived: Int64, expectedSize: Int64)`
  - `ActiveUpload.bytesReceived: Int64`（var，默认 0）
  - `var transferProgress: Double?`、`var transferSpeedBytesPerSecond: Int64?`
  - `struct TransferSample: Equatable { let time: Date; let totalBytes: Int64 }` 与 `static func transferSpeed(samples: [TransferSample]) -> Int64?`

- [ ] **Step 1: 写失败测试**

```swift
// macos/Tests/AndroidSyncMacTests/TransferProgressTests.swift
import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class TransferProgressTests: XCTestCase {
    func testProgressAggregatesActiveUploads() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: config
        )
        let model = AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let id = UUID()
        model.handle(.uploadStarted(id: id, filename: "a.mp4", expectedSize: 200))
        XCTAssertNil(model.transferProgress) // 无进度样本前为不确定
        model.handle(
            .uploadProgress(id: id, bytesReceived: 50, expectedSize: 200)
        )
        XCTAssertEqual(model.transferProgress, 0.25)
    }

    func testSpeedFromSamples() {
        let base = Date(timeIntervalSince1970: 1_000)
        let samples = [
            AppModel.TransferSample(time: base, totalBytes: 0),
            AppModel.TransferSample(
                time: base.addingTimeInterval(2),
                totalBytes: 4_000_000
            ),
        ]
        XCTAssertEqual(AppModel.transferSpeed(samples: samples), 2_000_000)
    }

    func testSpeedNeedsTwoSamples() {
        XCTAssertNil(AppModel.transferSpeed(samples: []))
        XCTAssertNil(
            AppModel.transferSpeed(
                samples: [.init(time: Date(), totalBytes: 1)]
            )
        )
    }
}
```

`transferProgress` 约定：本轮 burst 尚未收到任何 `uploadProgress` 事件时返回 `nil`（视图显示不确定进度条），用标志位 `burstSawProgress` 判定。

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --package-path macos --filter TransferProgressTests`
Expected: 编译失败（`uploadProgress` case 不存在）

- [ ] **Step 3: Core 加事件与发射**

`ReceiverServiceEvent` 追加：

```swift
    case uploadProgress(id: UUID, bytesReceived: Int64, expectedSize: Int64)
```

上传连接处理类型（`eventHandler` 所在、约 348 行起的类）加节流状态：

```swift
    private var lastProgressBytes: Int64 = 0
```

`consumeBody` 中 `remainingBytes -= Int64(writableCount)` 之后追加：

```swift
            let received = expectedSize - remainingBytes
            if received - lastProgressBytes >= 512 * 1_024 || remainingBytes == 0 {
                lastProgressBytes = received
                eventHandler(
                    .uploadProgress(
                        id: uploadID,
                        bytesReceived: received,
                        expectedSize: expectedSize
                    )
                )
            }
```

节流 512 KB：10 MB 文件约 20 次事件，不淹 MainActor。核心层无独立测试 target，节流行为由构建与手工 QA 覆盖（批次记录如实写明，不表述为已测）。

- [ ] **Step 4: AppModel 消费**

`ActiveUpload` 改：

```swift
struct ActiveUpload: Equatable, Identifiable {
    let id: UUID
    let filename: String
    let expectedSize: Int64
    var bytesReceived: Int64 = 0
}
```

属性区追加：

```swift
    struct TransferSample: Equatable {
        let time: Date
        let totalBytes: Int64
    }

    private var burstBytesReceived: Int64 = 0
    private var burstSawProgress = false
    private var transferSamples: [TransferSample] = []
```

计算属性追加：

```swift
    var transferProgress: Double? {
        guard burstSawProgress else { return nil }
        let expected = activeUploadsExpectedBytes
        guard expected > 0 else { return nil }
        let received = activeUploads.values.reduce(0) { $0 + $1.bytesReceived }
        return min(1, Double(received) / Double(expected))
    }

    static func transferSpeed(samples: [TransferSample]) -> Int64? {
        guard let first = samples.first, let last = samples.last,
              last.time > first.time
        else { return nil }
        let dt = last.time.timeIntervalSince(first.time)
        return Int64(Double(last.totalBytes - first.totalBytes) / dt)
    }

    var transferSpeedBytesPerSecond: Int64? {
        Self.transferSpeed(samples: transferSamples)
    }
```

`handle(_:generation:)` 追加分支：

```swift
        case let .uploadProgress(id, bytesReceived, _):
            guard var upload = activeUploads[id] else { return }
            let delta = bytesReceived - upload.bytesReceived
            upload.bytesReceived = bytesReceived
            activeUploads[id] = upload
            guard delta > 0 else { return }
            burstSawProgress = true
            burstBytesReceived += delta
            let now = Date()
            transferSamples.append(
                TransferSample(time: now, totalBytes: burstBytesReceived)
            )
            transferSamples.removeAll {
                now.timeIntervalSince($0.time) > 3
            }
```

`resetTransferCard()` 与 `beginTransferLinger()` 的收尾闭包里追加：

```swift
        burstBytesReceived = 0
        burstSawProgress = false
        transferSamples.removeAll()
```

- [ ] **Step 5: 本地化与视图**

`AppStringKey` 追加 `case speedFormat`；中文表 `"%@/秒"`，英文表 `"%@/s"`（流程同 Task 6 Step 1：先 case、跑 LocalizationTests 红、补表转绿）。

`TransferCardRow.progressCard` 的 `ProgressView` 部分替换：

```swift
            if let progress = model.transferProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.white)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.white)
            }
            if let speed = model.transferSpeedBytesPerSecond {
                Text(
                    model.format(
                        .speedFormat,
                        model.formatByteCount(speed)
                    )
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            }
```

- [ ] **Step 6: 跑测试确认通过 + 全量验证**

Run: `swift test --package-path macos --filter TransferProgressTests`
Expected: PASS
Run: `swift test --package-path macos && ./macos/build_and_run.sh verify`
Expected: 全绿；verify 通过

- [ ] **Step 7: 手工 QA（进度真机/模拟上传）**

按仓库手动调试指南（`docs/` 下 manual debugging guide，提交 `cc84c05` 引入）向接收端发起一次大文件上传，确认进度条从不确定切换为确定、速度文案出现且随传输变化、结束后卡片行停留后收起。无设备时如实记录为未完成项。

- [ ] **Step 8: 提交（批次 6 收尾，含批次记录 B15 与状态/交接文档更新；触及 Services，批次记录须列出 02_RISK_REGISTER 相关风险 ID）**

```bash
git add macos/Sources/AndroidSyncCore/ReceiverService.swift \
        macos/Sources/AndroidSyncMac/ \
        macos/Tests/AndroidSyncMacTests/TransferProgressTests.swift \
        PROJECT_MEMORY/
git commit -m "feat: 上传进度事件与传输卡片速度显示"
```
