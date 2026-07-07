import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class TransferProgressTests: XCTestCase {
    func testProgressAggregatesActiveUploads() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: config
        )
        let model = AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let id = UUID()
        model.handle(.uploadStarted(id: id, filename: "a.mp4", expectedSize: 200))
        XCTAssertNil(model.transferProgress) // 无进度样本前为不确定
        model.handle(
            .uploadProgress(id: id, bytesReceived: 50, expectedSize: 200)
        )
        XCTAssertEqual(model.transferProgress, 0.25)
    }

    func testSpeedFromSamples() {
        let base = Date(timeIntervalSince1970: 1_000)
        let samples = [
            AppModel.TransferSample(time: base, totalBytes: 0),
            AppModel.TransferSample(
                time: base.addingTimeInterval(2),
                totalBytes: 4_000_000
            ),
        ]
        XCTAssertEqual(AppModel.transferSpeed(samples: samples), 2_000_000)
    }

    func testSpeedNeedsTwoSamples() {
        XCTAssertNil(AppModel.transferSpeed(samples: []))
        XCTAssertNil(
            AppModel.transferSpeed(
                samples: [.init(time: Date(), totalBytes: 1)]
            )
        )
    }
}
