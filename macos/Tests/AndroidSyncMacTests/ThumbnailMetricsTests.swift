import XCTest
@testable import AndroidSyncMac

final class ThumbnailMetricsTests: XCTestCase {
    func testThumbnailSizesMatchLayoutContracts() {
        XCTAssertEqual(ThumbnailMetrics.gridSize, CGSize(width: 180, height: 124))
        XCTAssertEqual(ThumbnailMetrics.listSize, CGSize(width: 56, height: 42))
        XCTAssertEqual(ThumbnailMetrics.inspectorSize, CGSize(width: 240, height: 166))
    }

    func testGridMetadataWidthMatchesThumbnailWidth() {
        XCTAssertEqual(ThumbnailMetrics.gridCardWidth, 180)
        XCTAssertEqual(
            ThumbnailMetrics.gridSize.width,
            ThumbnailMetrics.gridCardWidth,
            "Grid thumbnail and metadata must share the fixed card width"
        )
    }
}
