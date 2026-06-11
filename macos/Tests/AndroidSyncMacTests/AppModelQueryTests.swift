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

    func testNewestAndOldestSortUseReceivedDateInDisplayOrder() {
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

    func testTodayFilterUsesInjectedNowAndCalendar() {
        let startOfToday = makeItem(filename: "today.jpg", receivedAt: date(2026, 6, 11, 0))
        let yesterday = makeItem(filename: "yesterday.jpg", receivedAt: date(2026, 6, 10, 23, 59))

        let result = AppModel.filterItems(
            [yesterday, startOfToday],
            category: .all,
            dateFilter: .today,
            sort: .newest,
            searchText: "",
            now: date(2026, 6, 11, 15),
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.filename), ["today.jpg"])
    }

    private func makeItem(filename: String, receivedAt: Date) -> MediaItemEntity {
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
                receivedAt: receivedAt,
                fileURL: URL(fileURLWithPath: "/tmp/\(filename)")
            )
        )
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
