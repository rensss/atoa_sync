import AndroidSyncCore
import Foundation
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
