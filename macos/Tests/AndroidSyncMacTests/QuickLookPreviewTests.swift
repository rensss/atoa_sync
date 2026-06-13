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
        let preview = QuickLookPreview(panelProvider: provider)
        let url = URL(fileURLWithPath: "/tmp/visible.jpg")

        preview.show(url)
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(preview.url, url)

        preview.toggle(url)

        XCTAssertFalse(panel.isVisible)
        XCTAssertEqual(panel.dismissCount, 1)
        XCTAssertNil(preview.url)
        XCTAssertEqual(provider.sharedPanelCallCount, 1)
    }

    func testToggleShowsPreviewWhenExistingPanelIsHidden() {
        let panel = FakeQuickLookPanel()
        let provider = FakeQuickLookPanelProvider(panel: panel)
        let preview = QuickLookPreview(panelProvider: provider)
        let url = URL(fileURLWithPath: "/tmp/hidden.jpg")

        preview.toggle(url)

        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.presentCount, 1)
        XCTAssertEqual(preview.url, url)
        XCTAssertEqual(provider.existingPanelCallCount, 1)
        XCTAssertEqual(provider.sharedPanelCallCount, 1)
    }

    func testCloseDoesNotCreatePanelWhenNoneExists() {
        let provider = FakeQuickLookPanelProvider(panel: nil)
        let preview = QuickLookPreview(panelProvider: provider)

        preview.close()

        XCTAssertEqual(provider.existingPanelCallCount, 1)
        XCTAssertEqual(provider.sharedPanelCallCount, 0)
        XCTAssertNil(preview.url)
    }

    func testAppModelTogglesOnlyOneActiveSelection() throws {
        let panel = FakeQuickLookPanel()
        let provider = FakeQuickLookPanelProvider(panel: panel)
        let preview = QuickLookPreview(panelProvider: provider)
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
private final class FakeQuickLookPanel: QuickLookPanel {
    var isVisible = false
    private(set) var presentCount = 0
    private(set) var dismissCount = 0

    func present(dataSource: any QLPreviewPanelDataSource) {
        presentCount += 1
        isVisible = true
    }

    func dismiss() {
        dismissCount += 1
        isVisible = false
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
