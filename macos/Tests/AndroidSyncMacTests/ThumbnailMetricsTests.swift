import XCTest
@testable import AndroidSyncMac

final class ThumbnailMetricsTests: XCTestCase {
    func testThumbTokens() {
        XCTAssertEqual(Theme.Thumb.gridCell, 150)
        XCTAssertEqual(Theme.Thumb.gridGap, 3)
        XCTAssertEqual(
            Theme.Thumb.gridSize,
            CGSize(width: 150, height: 150)
        )
        XCTAssertEqual(Theme.Thumb.listSize, CGSize(width: 56, height: 42))
        XCTAssertEqual(
            Theme.Thumb.inspectorSize,
            CGSize(width: 240, height: 166)
        )
        XCTAssertEqual(Theme.Thumb.cornerRadius, Theme.radiusS)
    }
}
