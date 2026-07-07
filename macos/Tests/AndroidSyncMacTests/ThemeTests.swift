import XCTest
@testable import AndroidSyncMac

final class ThemeTests: XCTestCase {
    func testSpacingScale() {
        XCTAssertEqual(Theme.spacingXS, 4)
        XCTAssertEqual(Theme.spacingS, 8)
        XCTAssertEqual(Theme.spacingM, 12)
        XCTAssertEqual(Theme.spacingL, 16)
    }

    func testRadiusScale() {
        XCTAssertEqual(Theme.radiusS, 6)
        XCTAssertEqual(Theme.radiusL, 10)
    }
}
