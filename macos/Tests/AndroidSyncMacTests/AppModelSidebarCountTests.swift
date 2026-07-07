import SwiftData
import XCTest
@testable import AndroidSyncMac
import AndroidSyncCore

@MainActor
final class AppModelSidebarCountTests: XCTestCase {
    private func makeItem(
        kind: UploadKind,
        removed: Bool = false,
        receivedAt: Date = Date()
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
            receivedAt: receivedAt,
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
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        model.items = [
            makeItem(kind: .photo, receivedAt: sixtyDaysAgo),
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
