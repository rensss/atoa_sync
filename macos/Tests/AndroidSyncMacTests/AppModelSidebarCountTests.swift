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

    func testLibraryStatsCountActiveKindsAndBytesOnly() throws {
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
            TestItems.item(kind: .photo, sizeBytes: 100),
            TestItems.item(kind: .photo, sizeBytes: 200),
            TestItems.item(kind: .video, sizeBytes: 3_000),
            TestItems.item(kind: .file, sizeBytes: 40),
            TestItems.item(kind: .video, sizeBytes: 9_000, removed: true),
        ]
        model.searchText = "不匹配任何文件"
        model.dateFilter = .today

        XCTAssertEqual(
            model.sidebarLibraryStats,
            AppModel.SidebarLibraryStats(
                photoCount: 2,
                videoCount: 1,
                fileCount: 1,
                totalBytes: 3_340
            )
        )
    }

    func testLibraryStatsClampInvalidAndOverflowingSizes() {
        let stats = AppModel.sidebarLibraryStats([
            TestItems.item(kind: .photo, sizeBytes: -1),
            TestItems.item(kind: .video, sizeBytes: .max),
            TestItems.item(kind: .file, sizeBytes: 1),
        ])

        XCTAssertEqual(stats.photoCount, 1)
        XCTAssertEqual(stats.videoCount, 1)
        XCTAssertEqual(stats.fileCount, 1)
        XCTAssertEqual(stats.totalBytes, .max)
    }
}
