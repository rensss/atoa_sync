import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class TransferProgressTests: XCTestCase {
    private func makeModel() throws -> AppModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: config
        )
        return AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
    }

    func testProgressAggregatesActiveUploads() throws {
        let model = try makeModel()
        let id = UUID()
        model.handle(.uploadStarted(id: id, filename: "a.mp4", expectedSize: 200))
        XCTAssertEqual(model.transferProgress, 0)
        model.handle(
            .uploadProgress(id: id, bytesReceived: 50, expectedSize: 200)
        )
        XCTAssertEqual(model.transferProgress, 0.25)
    }

    func testProgressSumsAcrossConcurrentUploads() throws {
        let model = try makeModel()
        let a = UUID()
        let b = UUID()
        model.handle(.uploadStarted(id: a, filename: "a.mp4", expectedSize: 100))
        model.handle(.uploadStarted(id: b, filename: "b.mp4", expectedSize: 300))
        model.handle(.uploadProgress(id: a, bytesReceived: 50, expectedSize: 100))
        model.handle(.uploadProgress(id: b, bytesReceived: 150, expectedSize: 300))
        XCTAssertEqual(model.transferProgress, 0.5) // (50+150)/(100+300)
    }

    func testNewBurstDuringLingerResetsProgressState() throws {
        let model = try makeModel()
        model.transferCompletionLinger = .seconds(60) // 驻留窗口内不触发回 idle
        let first = UUID()
        model.handle(.uploadStarted(id: first, filename: "a.mp4", expectedSize: 100))
        model.handle(.uploadProgress(id: first, bytesReceived: 100, expectedSize: 100))
        model.handle(.uploadStored(id: first, record: TestItems.record()))

        let second = UUID()
        model.handle(.uploadStarted(id: second, filename: "b.mp4", expectedSize: 200))
        XCTAssertEqual(model.transferProgress, 0) // 不吃上一轮 burstSawProgress
        XCTAssertNil(model.transferSpeedBytesPerSecond) // 样本已清
    }

    func testProgressUsesBatchTotalWhenProvided() throws {
        let model = try makeModel()
        let id = UUID()
        model.handle(
            .uploadStarted(
                id: id,
                filename: "a.mp4",
                expectedSize: 200,
                batchIndex: 2,
                batchTotal: 4
            )
        )
        model.handle(
            .uploadProgress(id: id, bytesReceived: 100, expectedSize: 200)
        )

        XCTAssertEqual(model.transferProgress, 0.375)
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
