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
        let monitor = FakeQuickLookSpaceKeyMonitor()
        let preview = QuickLookPreview(panelProvider: provider, spaceKeyMonitor: monitor)
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
        let monitor = FakeQuickLookSpaceKeyMonitor()
        let preview = QuickLookPreview(panelProvider: provider, spaceKeyMonitor: monitor)
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
        let monitor = FakeQuickLookSpaceKeyMonitor()
        let preview = QuickLookPreview(panelProvider: provider, spaceKeyMonitor: monitor)
        let url = URL(fileURLWithPath: "/tmp/active.jpg")

        preview.show(url)
        XCTAssertTrue(monitor.pressSpace())

        XCTAssertFalse(panel.isVisible)
        XCTAssertEqual(panel.dismissCount, 1)
        XCTAssertEqual(provider.existingPanelCallCount, 0)
        XCTAssertEqual(provider.sharedPanelCallCount, 1)
        XCTAssertNil(preview.url)
        XCTAssertEqual(monitor.stopCount, 1)
    }

    func testSpaceKeyIsIgnoredWhenPreviewPanelIsNotKey() {
        let panel = FakeQuickLookPanel()
        let monitor = FakeQuickLookSpaceKeyMonitor()
        let preview = QuickLookPreview(
            panelProvider: FakeQuickLookPanelProvider(panel: panel),
            spaceKeyMonitor: monitor
        )

        preview.show(URL(fileURLWithPath: "/tmp/not-key.jpg"))
        panel.isKeyWindow = false

        XCTAssertFalse(monitor.pressSpace())
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.dismissCount, 0)
        XCTAssertNotNil(preview.url)
    }

    func testExternalPanelHideClearsPreviewStateAndStopsMonitor() {
        let panel = FakeQuickLookPanel()
        let monitor = FakeQuickLookSpaceKeyMonitor()
        let preview = QuickLookPreview(
            panelProvider: FakeQuickLookPanelProvider(panel: panel),
            spaceKeyMonitor: monitor
        )

        preview.show(URL(fileURLWithPath: "/tmp/external-close.jpg"))
        panel.hideExternally()

        XCTAssertNil(preview.url)
        XCTAssertEqual(monitor.stopCount, 1)
        XCTAssertFalse(monitor.pressSpace())
    }

    func testRepeatedShowReusesActivePanelWrapper() {
        let panel = FakeQuickLookPanel()
        let provider = FakeQuickLookPanelProvider(panel: panel)
        let monitor = FakeQuickLookSpaceKeyMonitor()
        let preview = QuickLookPreview(panelProvider: provider, spaceKeyMonitor: monitor)
        let firstURL = URL(fileURLWithPath: "/tmp/first.jpg")
        let secondURL = URL(fileURLWithPath: "/tmp/second.jpg")

        preview.show(firstURL)
        preview.show(secondURL)

        XCTAssertEqual(provider.sharedPanelCallCount, 1)
        XCTAssertEqual(panel.presentCount, 2)
        XCTAssertEqual(monitor.startCount, 1)
        XCTAssertEqual(preview.url, secondURL)
    }

    func testCloseDoesNotCreatePanelWhenNoneExists() {
        let provider = FakeQuickLookPanelProvider(panel: nil)
        let monitor = FakeQuickLookSpaceKeyMonitor()
        let preview = QuickLookPreview(panelProvider: provider, spaceKeyMonitor: monitor)

        preview.close()

        XCTAssertEqual(provider.existingPanelCallCount, 1)
        XCTAssertEqual(provider.sharedPanelCallCount, 0)
        XCTAssertNil(preview.url)
        XCTAssertEqual(monitor.stopCount, 1)
    }

    func testAppModelTogglesOnlyOneActiveSelection() throws {
        let panel = FakeQuickLookPanel()
        let provider = FakeQuickLookPanelProvider(panel: panel)
        let preview = QuickLookPreview(
            panelProvider: provider,
            spaceKeyMonitor: FakeQuickLookSpaceKeyMonitor()
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
            quickLookPreview: quickLookPreview
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
private final class FakeQuickLookSpaceKeyMonitor: QuickLookSpaceKeyMonitoring {
    private var handler: (@MainActor () -> Bool)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(handler: @escaping @MainActor () -> Bool) {
        guard self.handler == nil else { return }
        startCount += 1
        self.handler = handler
    }

    func stop() {
        stopCount += 1
        handler = nil
    }

    func pressSpace() -> Bool {
        handler?() ?? false
    }
}

@MainActor
private final class FakeQuickLookPanel: QuickLookPanel {
    var isVisible = false
    var isKeyWindow = false
    private(set) var presentCount = 0
    private(set) var dismissCount = 0
    private var onVisibilityLost: (@MainActor () -> Void)?

    func present(
        dataSource: any QLPreviewPanelDataSource,
        onVisibilityLost: @escaping @MainActor () -> Void
    ) {
        presentCount += 1
        isVisible = true
        isKeyWindow = true
        self.onVisibilityLost = onVisibilityLost
    }

    func dismiss() {
        dismissCount += 1
        isVisible = false
        isKeyWindow = false
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
