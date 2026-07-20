import AndroidSyncCore
import Foundation
import QuickLookUI
import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class QuickLookPreviewTests: XCTestCase {
    func testToggleHidesVisiblePanelAndClearsPreviewURL() {
        let panel = FakeQuickLookPanel()
        let provider = FakeQuickLookPanelProvider(panel: panel)
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(panelProvider: provider, keyMonitor: monitor)
        let url = URL(fileURLWithPath: "/tmp/visible.jpg")

        preview.show(url)
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(preview.url, url)

        preview.toggle(url)

        XCTAssertFalse(panel.isVisible)
        XCTAssertEqual(panel.dismissCount, 1)
        XCTAssertNil(preview.url)
        XCTAssertEqual(provider.sharedPanelCallCount, 1)
        XCTAssertEqual(monitor.stopCount, 1)
    }

    func testToggleShowsPreviewWhenExistingPanelIsHidden() {
        let panel = FakeQuickLookPanel()
        let provider = FakeQuickLookPanelProvider(panel: panel)
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(panelProvider: provider, keyMonitor: monitor)
        let url = URL(fileURLWithPath: "/tmp/hidden.jpg")

        preview.toggle(url)

        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.presentCount, 1)
        XCTAssertEqual(preview.url, url)
        XCTAssertEqual(provider.existingPanelCallCount, 1)
        XCTAssertEqual(provider.sharedPanelCallCount, 1)
        XCTAssertEqual(monitor.startCount, 1)
    }

    func testSpaceKeyMonitorClosesActivePanelWithoutLookingUpSharedPanelAgain() {
        let panel = FakeQuickLookPanel()
        let provider = FakeQuickLookPanelProvider(panel: panel)
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(panelProvider: provider, keyMonitor: monitor)
        let url = URL(fileURLWithPath: "/tmp/active.jpg")

        preview.show(url)
        XCTAssertTrue(monitor.send(.close))

        XCTAssertFalse(panel.isVisible)
        XCTAssertEqual(panel.dismissCount, 1)
        XCTAssertEqual(provider.existingPanelCallCount, 0)
        XCTAssertEqual(provider.sharedPanelCallCount, 1)
        XCTAssertNil(preview.url)
        XCTAssertEqual(monitor.stopCount, 1)
    }

    func testSpaceKeyIsIgnoredWhenPreviewPanelIsNotKey() {
        let panel = FakeQuickLookPanel()
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(
            panelProvider: FakeQuickLookPanelProvider(panel: panel),
            keyMonitor: monitor
        )

        preview.show(URL(fileURLWithPath: "/tmp/not-key.jpg"))
        panel.isKeyWindow = false

        XCTAssertFalse(monitor.send(.close))
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.dismissCount, 0)
        XCTAssertNotNil(preview.url)
    }

    func testExternalPanelHideClearsPreviewStateAndStopsMonitor() {
        let panel = FakeQuickLookPanel()
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(
            panelProvider: FakeQuickLookPanelProvider(panel: panel),
            keyMonitor: monitor
        )

        preview.show(URL(fileURLWithPath: "/tmp/external-close.jpg"))
        panel.hideExternally()

        XCTAssertNil(preview.url)
        XCTAssertEqual(monitor.stopCount, 1)
        XCTAssertFalse(monitor.send(.close))
    }

    func testRepeatedShowReusesActivePanelWrapper() {
        let panel = FakeQuickLookPanel()
        let provider = FakeQuickLookPanelProvider(panel: panel)
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(panelProvider: provider, keyMonitor: monitor)
        let firstURL = URL(fileURLWithPath: "/tmp/first.jpg")
        let secondURL = URL(fileURLWithPath: "/tmp/second.jpg")

        preview.show(firstURL)
        preview.show(secondURL)

        XCTAssertEqual(provider.sharedPanelCallCount, 1)
        XCTAssertEqual(panel.presentCount, 2)
        XCTAssertEqual(monitor.startCount, 1)
        XCTAssertEqual(preview.url, secondURL)
    }

    func testArrowKeysSwitchItemsWithoutPresentingOrReloadingPanelAgain() {
        let panel = FakeQuickLookPanel()
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(
            panelProvider: FakeQuickLookPanelProvider(panel: panel),
            keyMonitor: monitor
        )
        let urls = [
            URL(fileURLWithPath: "/tmp/first.jpg"),
            URL(fileURLWithPath: "/tmp/second.jpg"),
            URL(fileURLWithPath: "/tmp/third.jpg")
        ]
        var selectedURLs: [URL] = []

        preview.show(
            urls,
            selectedIndex: 1,
            onSelectionChange: { selectedURLs.append($0) }
        )

        XCTAssertEqual(panel.currentPreviewItemIndex, 1)
        XCTAssertEqual(panel.dataSource?.numberOfPreviewItems(in: nil), 3)
        XCTAssertTrue(monitor.send(.next))
        XCTAssertEqual(panel.currentPreviewItemIndex, 2)
        XCTAssertEqual(preview.url, urls[2])
        XCTAssertEqual(selectedURLs, [urls[2]])
        XCTAssertEqual(panel.presentCount, 1)
        XCTAssertEqual(panel.reloadCount, 0)

        XCTAssertTrue(monitor.send(.previous))
        XCTAssertEqual(panel.currentPreviewItemIndex, 1)
        XCTAssertEqual(preview.url, urls[1])
        XCTAssertEqual(selectedURLs, [urls[2], urls[1]])
        XCTAssertEqual(panel.presentCount, 1)
        XCTAssertEqual(panel.reloadCount, 0)
    }

    func testDeleteKeyRemovesCurrentItemAfterDeletionSucceeds() async {
        let panel = FakeQuickLookPanel()
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(
            panelProvider: FakeQuickLookPanelProvider(panel: panel),
            keyMonitor: monitor
        )
        let urls = [
            URL(fileURLWithPath: "/tmp/first.jpg"),
            URL(fileURLWithPath: "/tmp/second.jpg"),
            URL(fileURLWithPath: "/tmp/third.jpg")
        ]
        let deletion = expectation(description: "delete current preview item")
        var deletedURL: URL?
        var selectedURL: URL?

        preview.show(
            urls,
            selectedIndex: 1,
            onSelectionChange: { selectedURL = $0 },
            onDelete: { url in
                deletedURL = url
                deletion.fulfill()
                return true
            }
        )

        XCTAssertTrue(monitor.send(.delete))
        await fulfillment(of: [deletion], timeout: 1)
        await Task.yield()

        XCTAssertEqual(deletedURL, urls[1])
        XCTAssertEqual(panel.dataSource?.numberOfPreviewItems(in: nil), 2)
        XCTAssertEqual(panel.reloadCount, 1)
        XCTAssertEqual(panel.currentPreviewItemIndex, 1)
        XCTAssertEqual(preview.url, urls[2])
        XCTAssertEqual(selectedURL, urls[2])
        XCTAssertEqual(panel.dismissCount, 0)
    }

    func testCloseDoesNotCreatePanelWhenNoneExists() {
        let provider = FakeQuickLookPanelProvider(panel: nil)
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(panelProvider: provider, keyMonitor: monitor)

        preview.close()

        XCTAssertEqual(provider.existingPanelCallCount, 1)
        XCTAssertEqual(provider.sharedPanelCallCount, 0)
        XCTAssertNil(preview.url)
        XCTAssertEqual(monitor.stopCount, 1)
    }

    func testAppModelTogglesOnlyOneActiveSelection() throws {
        let panel = FakeQuickLookPanel()
        let provider = FakeQuickLookPanelProvider(panel: panel)
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(
            panelProvider: provider,
            keyMonitor: monitor
        )
        let model = try makeModel(quickLookPreview: preview)
        let active = makeItem(filename: "active.jpg")
        let other = makeItem(filename: "other.jpg")
        let deleted = makeItem(filename: "deleted.jpg", deleted: true)
        model.items = [active, other, deleted]

        model.toggleSelectedPreview()
        XCTAssertEqual(panel.presentCount, 0)

        model.selectedIDs = [active.id, other.id]
        model.toggleSelectedPreview()
        XCTAssertEqual(panel.presentCount, 0)

        model.selectedIDs = [deleted.id]
        model.toggleSelectedPreview()
        XCTAssertEqual(panel.presentCount, 0)

        model.selectedIDs = [active.id]
        model.toggleSelectedPreview()
        XCTAssertEqual(panel.presentCount, 1)
        XCTAssertEqual(preview.url, active.fileURL)
        XCTAssertEqual(panel.dataSource?.numberOfPreviewItems(in: nil), 2)

        let navigationCommand: QuickLookKeyCommand =
            panel.currentPreviewItemIndex == 0 ? .next : .previous
        XCTAssertTrue(monitor.send(navigationCommand))
        XCTAssertEqual(model.selectedIDs, Set([other.id]))
        XCTAssertEqual(preview.url, other.fileURL)
        XCTAssertEqual(panel.presentCount, 1)
        XCTAssertEqual(panel.reloadCount, 0)
    }

    func testAppModelDeleteKeyUsesRepositoryAndSelectsNextPreview() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("preview-delete-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = LibraryRepository(rootURL: directory)
        _ = try await repository.store(
            data: Data("first".utf8),
            metadata: UploadMetadata(
                filename: "first.jpg",
                contentType: "image/jpeg",
                stableID: "image:preview-first"
            )
        )
        _ = try await repository.store(
            data: Data("second".utf8),
            metadata: UploadMetadata(
                filename: "second.jpg",
                contentType: "image/jpeg",
                stableID: "image:preview-second"
            )
        )

        let panel = FakeQuickLookPanel()
        let monitor = FakeQuickLookKeyMonitor()
        let preview = QuickLookPreview(
            panelProvider: FakeQuickLookPanelProvider(panel: panel),
            keyMonitor: monitor
        )
        let model = try makeModel(quickLookPreview: preview)
        await model.configureDirectory(
            directory,
            startReceiverAfterConfiguration: false
        ).value

        let orderedItems = model.filteredItems
        let current = try XCTUnwrap(orderedItems.first)
        let next = try XCTUnwrap(orderedItems.dropFirst().first)
        model.select(current.id, additive: false)
        model.toggleSelectedPreview()
        try FileManager.default.removeItem(at: current.fileURL)

        let reload = expectation(description: "preview reload after repository deletion")
        panel.onReload = { reload.fulfill() }
        XCTAssertTrue(monitor.send(.delete))
        await fulfillment(of: [reload], timeout: 2)

        XCTAssertNil(model.lastError)
        XCTAssertTrue(model.items.first(where: { $0.id == current.id })?.removed == true)
        XCTAssertEqual(model.selectedIDs, Set([next.id]))
        XCTAssertEqual(preview.url, next.fileURL)
        XCTAssertEqual(panel.dataSource?.numberOfPreviewItems(in: nil), 1)
        XCTAssertEqual(panel.dismissCount, 0)
    }

    private func makeModel(quickLookPreview: QuickLookPreview) throws -> AppModel {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: configuration
        )
        return AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            quickLookPreview: quickLookPreview,
            bookmarkClient: .init(resolve: { nil }, save: { _ in }, clear: {}),
            directoryAccessClient: .init(start: { _ in true }, stop: { _ in })
        )
    }

    private func makeItem(
        filename: String,
        deleted: Bool = false
    ) -> MediaItemEntity {
        MediaItemEntity(
            record: UploadRecord(
                filename: filename,
                originalFilename: filename,
                kind: .photo,
                sizeBytes: 1,
                contentType: "image/jpeg",
                stableID: filename,
                dateModifiedMillis: nil,
                dateTakenMillis: nil,
                dateAddedMillis: nil,
                sourceIP: nil,
                receivedAt: Date(),
                fileURL: URL(fileURLWithPath: "/tmp/\(filename)"),
                deleted: deleted
            )
        )
    }
}

@MainActor
private final class FakeQuickLookKeyMonitor: QuickLookKeyMonitoring {
    private var handler: (@MainActor (QuickLookKeyCommand) -> Bool)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(handler: @escaping @MainActor (QuickLookKeyCommand) -> Bool) {
        guard self.handler == nil else { return }
        startCount += 1
        self.handler = handler
    }

    func stop() {
        stopCount += 1
        handler = nil
    }

    func send(_ command: QuickLookKeyCommand) -> Bool {
        handler?(command) ?? false
    }
}

@MainActor
private final class FakeQuickLookPanel: QuickLookPanel {
    var isVisible = false
    var isKeyWindow = false
    var currentPreviewItemIndex = 0
    private(set) var presentCount = 0
    private(set) var reloadCount = 0
    private(set) var dismissCount = 0
    private(set) var dataSource: (any QLPreviewPanelDataSource)?
    var onReload: (() -> Void)?
    private var onVisibilityLost: (@MainActor () -> Void)?

    func present(
        dataSource: any QLPreviewPanelDataSource,
        selectedIndex: Int,
        onVisibilityLost: @escaping @MainActor () -> Void
    ) {
        presentCount += 1
        isVisible = true
        isKeyWindow = true
        currentPreviewItemIndex = selectedIndex
        self.dataSource = dataSource
        self.onVisibilityLost = onVisibilityLost
    }

    func reloadData() {
        reloadCount += 1
        onReload?()
    }

    func dismiss() {
        dismissCount += 1
        isVisible = false
        isKeyWindow = false
        dataSource = nil
        onVisibilityLost = nil
    }

    func hideExternally() {
        isVisible = false
        isKeyWindow = false
        let handler = onVisibilityLost
        onVisibilityLost = nil
        handler?()
    }
}

@MainActor
private final class FakeQuickLookPanelProvider: QuickLookPanelProviding {
    var panel: FakeQuickLookPanel?
    private(set) var existingPanelCallCount = 0
    private(set) var sharedPanelCallCount = 0

    init(panel: FakeQuickLookPanel?) {
        self.panel = panel
    }

    func existingPanel() -> (any QuickLookPanel)? {
        existingPanelCallCount += 1
        return panel
    }

    func sharedPanel() -> (any QuickLookPanel)? {
        sharedPanelCallCount += 1
        return panel
    }
}
