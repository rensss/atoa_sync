import SwiftData
import XCTest
@testable import AndroidSyncMac
import AndroidSyncCore

@MainActor
final class AppModelSidebarCountTests: XCTestCase {
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
            TestItems.item(kind: .photo, receivedAt: sixtyDaysAgo),
            TestItems.item(kind: .photo),
            TestItems.item(kind: .video),
            TestItems.item(kind: .photo, removed: true),
        ]
        model.searchText = "不匹配任何文件"
        model.dateFilter = .today
        XCTAssertEqual(model.categoryCount(.all), 3)
        XCTAssertEqual(model.categoryCount(.photos), 2)
        XCTAssertEqual(model.categoryCount(.videos), 1)
        XCTAssertEqual(model.categoryCount(.deleted), 1)
    }
}
