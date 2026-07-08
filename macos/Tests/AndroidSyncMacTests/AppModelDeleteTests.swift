import AndroidSyncCore
import Foundation
import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class AppModelDeleteTests: XCTestCase {
    /// 回归：实体的删除标记不能命名为 `deleted`（与 NSManagedObject 的保留
    /// 属性冲突，save() 会静默回滚该值），否则已删除条目会一直留在主列表。
    func testDeleteSelectedHidesItemFromMainCategoryAndPersists() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("delete-flow-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = LibraryRepository(rootURL: directory)
        let stored = try await repository.store(
            data: Data("abcd".utf8),
            metadata: UploadMetadata(
                filename: "a.jpg",
                contentType: "image/jpeg",
                stableID: "image:test-1"
            )
        )

        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let model = AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            bookmarkClient: .init(resolve: { nil }, save: { _ in }, clear: {}),
            directoryAccessClient: .init(start: { _ in true }, stop: { _ in })
        )
        await model.configureDirectory(
            directory,
            startReceiverAfterConfiguration: false
        ).value

        let item = try XCTUnwrap(model.items.first)
        XCTAssertEqual(model.items.count, 1)
        XCTAssertFalse(item.removed)

        // 预先移除文件，避免测试把文件真的放进用户废纸篓；
        // delete 对缺失文件是幂等的（B04），仍会写入 tombstone。
        try FileManager.default.removeItem(at: stored.fileURL)

        model.select(item.id, additive: false)
        await model.deleteSelected()

        XCTAssertNil(model.lastError)
        XCTAssertEqual(model.items.count, 1)
        XCTAssertTrue(
            model.items.first?.removed == true,
            "删除后实体必须保持已删除标记（save() 不得回滚）"
        )
        XCTAssertTrue(
            AppModel.filterItems(
                model.items,
                category: .all,
                dateFilter: .all,
                sort: .newest,
                searchText: "",
                now: Date(),
                calendar: Calendar.current
            ).isEmpty,
            "已删除条目不能出现在“全部”分类"
        )
        XCTAssertEqual(
            AppModel.filterItems(
                model.items,
                category: .deleted,
                dateFilter: .all,
                sort: .newest,
                searchText: "",
                now: Date(),
                calendar: Calendar.current
            ).count,
            1,
            "已删除条目应出现在“已删除”分类"
        )

        // 持久化后的值必须在新的 ModelContext 中依然为 true。
        let fetched = try ModelContext(container).fetch(
            FetchDescriptor<MediaItemEntity>()
        )
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched.first?.removed == true)

        // 再次删除同一条目必须是 no-op，不追加重复 tombstone。
        let logURL = directory.appendingPathComponent("uploads.jsonl")
        let linesBefore = try String(contentsOf: logURL, encoding: .utf8)
            .split(whereSeparator: \.isNewline).count
        model.select(item.id, additive: false)
        await model.deleteSelected()
        let linesAfter = try String(contentsOf: logURL, encoding: .utf8)
            .split(whereSeparator: \.isNewline).count
        XCTAssertEqual(linesBefore, linesAfter)
        XCTAssertEqual(linesAfter, 2)

        model.clearDeletedItems()
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(
            try ModelContext(container).fetch(FetchDescriptor<MediaItemEntity>()).isEmpty
        )
        XCTAssertEqual(
            try String(contentsOf: logURL, encoding: .utf8)
                .split(whereSeparator: \.isNewline).count,
            2,
            "清空已删除只隐藏 tombstone，不擦除 manifest 历史"
        )

        await model.configureDirectory(
            directory,
            startReceiverAfterConfiguration: false
        ).value
        XCTAssertTrue(model.items.isEmpty)
    }
}
