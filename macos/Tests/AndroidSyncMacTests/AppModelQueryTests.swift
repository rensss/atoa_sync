import AndroidSyncCore
import AppKit
import Foundation
import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class AppModelQueryTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testNewestAndOldestSortUseReceivedDateWhenOriginalDateIsMissing() {
        let older = makeItem(filename: "older.jpg", receivedAt: date(2026, 6, 9, 12))
        let newer = makeItem(filename: "newer.jpg", receivedAt: date(2026, 6, 11, 8))

        let newest = AppModel.filterItems(
            [older, newer],
            category: .all,
            dateFilter: .all,
            sort: .newest,
            searchText: "",
            now: date(2026, 6, 11, 15),
            calendar: calendar
        )
        let oldest = AppModel.filterItems(
            [newer, older],
            category: .all,
            dateFilter: .all,
            sort: .oldest,
            searchText: "",
            now: date(2026, 6, 11, 15),
            calendar: calendar
        )

        XCTAssertEqual(newest.map(\.filename), ["newer.jpg", "older.jpg"])
        XCTAssertEqual(oldest.map(\.filename), ["older.jpg", "newer.jpg"])
    }

    func testNewestAndOldestSortUseOriginalMediaDateBeforeReceivedDate() {
        let receivedLater = makeItem(
            filename: "received-later.jpg",
            receivedAt: date(2026, 6, 11, 12),
            dateTakenMillis: millis(date(2026, 6, 1, 12))
        )
        let capturedLater = makeItem(
            filename: "captured-later.jpg",
            receivedAt: date(2026, 6, 10, 12),
            dateTakenMillis: millis(date(2026, 6, 9, 12))
        )

        let newest = AppModel.filterItems(
            [receivedLater, capturedLater],
            category: .all,
            dateFilter: .all,
            sort: .newest,
            searchText: "",
            now: date(2026, 6, 11, 15),
            calendar: calendar
        )
        let oldest = AppModel.filterItems(
            [capturedLater, receivedLater],
            category: .all,
            dateFilter: .all,
            sort: .oldest,
            searchText: "",
            now: date(2026, 6, 11, 15),
            calendar: calendar
        )

        XCTAssertEqual(newest.map(\.filename), ["captured-later.jpg", "received-later.jpg"])
        XCTAssertEqual(oldest.map(\.filename), ["received-later.jpg", "captured-later.jpg"])
    }

    func testTodayFilterUsesInjectedNowAndCalendar() {
        let startOfToday = makeItem(filename: "today.jpg", receivedAt: date(2026, 6, 11, 0))
        let yesterday = makeItem(filename: "yesterday.jpg", receivedAt: date(2026, 6, 10, 23, 59))
        let future = makeItem(filename: "future.jpg", receivedAt: date(2026, 6, 11, 15, 1))

        let result = AppModel.filterItems(
            [yesterday, startOfToday, future],
            category: .all,
            dateFilter: .today,
            sort: .newest,
            searchText: "",
            now: date(2026, 6, 11, 15),
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.filename), ["today.jpg"])
    }

    func testRecentCategoryExcludesItemsAfterNow() {
        let current = makeItem(filename: "current.jpg", receivedAt: date(2026, 6, 11, 15))
        let future = makeItem(filename: "future.jpg", receivedAt: date(2026, 6, 11, 15, 1))

        let result = AppModel.filterItems(
            [future, current],
            category: .recent,
            dateFilter: .all,
            sort: .newest,
            searchText: "",
            now: date(2026, 6, 11, 15),
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.filename), ["current.jpg"])
    }

    func testSevenDaysUsesNaturalDayBoundaryAndExcludesFutureItems() {
        let lowerBoundary = makeItem(
            filename: "boundary.jpg",
            receivedAt: date(2026, 6, 5, 0)
        )
        let beforeBoundary = makeItem(
            filename: "before.jpg",
            receivedAt: date(2026, 6, 4, 23, 59)
        )
        let future = makeItem(filename: "future.jpg", receivedAt: date(2026, 6, 11, 15, 1))

        let result = AppModel.filterItems(
            [beforeBoundary, lowerBoundary, future],
            category: .all,
            dateFilter: .sevenDays,
            sort: .newest,
            searchText: "",
            now: date(2026, 6, 11, 15),
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.filename), ["boundary.jpg"])
    }

    func testThirtyDaysUsesNaturalDayBoundaryAndExcludesFutureItems() {
        let lowerBoundary = makeItem(
            filename: "boundary.jpg",
            receivedAt: date(2026, 5, 13, 0)
        )
        let beforeBoundary = makeItem(
            filename: "before.jpg",
            receivedAt: date(2026, 5, 12, 23, 59)
        )
        let future = makeItem(filename: "future.jpg", receivedAt: date(2026, 6, 11, 15, 1))

        let result = AppModel.filterItems(
            [beforeBoundary, lowerBoundary, future],
            category: .all,
            dateFilter: .thirtyDays,
            sort: .newest,
            searchText: "",
            now: date(2026, 6, 11, 15),
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.filename), ["boundary.jpg"])
    }

    func testSelectAdjacentItemUsesVisibleSortOrderAndClampsAtEdges() throws {
        let model = try makeModel()
        let first = makeItem(filename: "first.jpg", receivedAt: date(2026, 6, 9, 12))
        let second = makeItem(filename: "second.jpg", receivedAt: date(2026, 6, 10, 12))
        let third = makeItem(filename: "third.jpg", receivedAt: date(2026, 6, 11, 12))
        model.items = [third, first, second]
        model.sort = .oldest

        XCTAssertEqual(model.selectAdjacentItem(offset: 1), first.id)
        XCTAssertEqual(model.selectedIDs, Set([first.id]))
        XCTAssertEqual(model.selectAdjacentItem(offset: 1), second.id)
        XCTAssertEqual(model.selectedIDs, Set([second.id]))
        XCTAssertEqual(model.selectAdjacentItem(offset: 20), third.id)
        XCTAssertEqual(model.selectedIDs, Set([third.id]))
        XCTAssertEqual(model.selectAdjacentItem(offset: 1), third.id)

        model.selectedIDs.removeAll()
        XCTAssertEqual(model.selectAdjacentItem(offset: -1), third.id)
        XCTAssertEqual(model.selectAdjacentItem(offset: -20), first.id)

        model.searchText = "second"
        model.selectedIDs = [first.id]
        XCTAssertEqual(model.selectAdjacentItem(offset: 1), second.id)
        XCTAssertEqual(model.selectedIDs, Set([second.id]))
    }

    func testLibraryKeyMonitorNavigatesGridAndHonorsFocusState() throws {
        let monitor = FakeLibraryKeyMonitor()
        let model = try makeModel(libraryKeyMonitor: monitor)
        let first = makeItem(filename: "first.jpg", receivedAt: date(2026, 6, 9, 12))
        let second = makeItem(filename: "second.jpg", receivedAt: date(2026, 6, 10, 12))
        let third = makeItem(filename: "third.jpg", receivedAt: date(2026, 6, 11, 12))
        model.items = [third, first, second]
        model.sort = .oldest
        model.libraryKeyboardNavigationEnabled = true
        model.libraryGridColumnCount = 2

        XCTAssertTrue(monitor.send(.right))
        XCTAssertEqual(model.selectedIDs, Set([first.id]))
        XCTAssertTrue(monitor.send(.right))
        XCTAssertEqual(model.selectedIDs, Set([second.id]))
        XCTAssertTrue(monitor.send(.down))
        XCTAssertEqual(model.selectedIDs, Set([third.id]))
        XCTAssertTrue(monitor.send(.up))
        XCTAssertEqual(model.selectedIDs, Set([first.id]))

        model.libraryKeyboardNavigationEnabled = false
        XCTAssertFalse(monitor.send(.right))
        XCTAssertEqual(model.selectedIDs, Set([first.id]))
    }

    func testLibraryKeyMonitorAcceptsSystemArrowFlags() {
        XCTAssertEqual(
            AppKitLibraryKeyMonitor.command(
                forKeyCode: 123,
                modifierFlags: [.numericPad, .function]
            ),
            .left
        )
        XCTAssertEqual(
            AppKitLibraryKeyMonitor.command(
                forKeyCode: 126,
                modifierFlags: [.numericPad, .function, .capsLock]
            ),
            .up
        )
        XCTAssertNil(
            AppKitLibraryKeyMonitor.command(
                forKeyCode: 124,
                modifierFlags: [.numericPad, .command]
            )
        )
    }

    private func makeModel(
        libraryKeyMonitor: (any LibraryKeyMonitoring)? = nil
    ) throws -> AppModel {
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        if let libraryKeyMonitor {
            return AppModel(
                modelContainer: container,
                userDefaults: UserDefaults(suiteName: UUID().uuidString)!,
                libraryKeyMonitor: libraryKeyMonitor
            )
        }
        return AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
    }

    private func makeItem(
        filename: String,
        receivedAt: Date,
        dateTakenMillis: Int64? = nil
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
                dateTakenMillis: dateTakenMillis,
                dateAddedMillis: nil,
                sourceIP: nil,
                receivedAt: receivedAt,
                fileURL: URL(fileURLWithPath: "/tmp/\(filename)")
            )
        )
    }

    private func millis(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1_000)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}

@MainActor
private final class FakeLibraryKeyMonitor: LibraryKeyMonitoring {
    private var handler: (@MainActor (LibraryNavigationCommand) -> Bool)?

    func start(handler: @escaping @MainActor (LibraryNavigationCommand) -> Bool) {
        self.handler = handler
    }

    func stop() {
        handler = nil
    }

    func send(_ command: LibraryNavigationCommand) -> Bool {
        handler?(command) ?? false
    }
}
