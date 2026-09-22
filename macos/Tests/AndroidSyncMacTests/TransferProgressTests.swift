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

    func testNewBurstStartsWithFreshProgressStateAfterPreviousCompletion() throws {
        let model = try makeModel()
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

    func testWholeTaskRemainingIncludesCompletedAndActiveFileBytes() throws {
        let model = try makeModel()
        let first = UUID()
        model.handle(
            .uploadStarted(
                id: first,
                filename: "first.jpg",
                expectedSize: 400,
                batchIndex: 1,
                batchTotal: 2,
                batchTotalBytes: 1_000
            )
        )
        model.handle(.uploadProgress(id: first, bytesReceived: 100, expectedSize: 400))
        XCTAssertEqual(model.transferRemainingBytes, 900)

        model.handle(.uploadStored(id: first, record: TestItems.record(sizeBytes: 400)))
        XCTAssertEqual(model.transferRemainingBytes, 600)

        let second = UUID()
        model.handle(
            .uploadStarted(
                id: second,
                filename: "second.jpg",
                expectedSize: 600,
                batchIndex: 2,
                batchTotal: 2,
                batchTotalBytes: 1_000
            )
        )
        XCTAssertEqual(model.transferRemainingBytes, 600)
    }

    func testCompletedBytesCountWhenLaterUploadOmitsOptionalBatchHeader() throws {
        let model = try makeModel()
        let first = UUID()
        model.handle(
            .uploadStarted(
                id: first,
                filename: "first.jpg",
                expectedSize: 400,
                batchIndex: 1,
                batchTotal: 3,
                batchTotalBytes: 1_000
            )
        )
        model.handle(.uploadStored(id: first, record: TestItems.record(sizeBytes: 400)))

        let second = UUID()
        model.handle(
            .uploadStarted(
                id: second,
                filename: "second.jpg",
                expectedSize: 300,
                batchIndex: 2,
                batchTotal: 3
            )
        )
        model.handle(.uploadStored(id: second, record: TestItems.record(sizeBytes: 300)))

        let third = UUID()
        model.handle(
            .uploadStarted(
                id: third,
                filename: "third.jpg",
                expectedSize: 300,
                batchIndex: 3,
                batchTotal: 3,
                batchTotalBytes: 1_000
            )
        )

        XCTAssertEqual(model.transferRemainingBytes, 300)
    }

    func testCompletedBytesCountBeforeOptionalBatchHeaderArrives() throws {
        let model = try makeModel()
        let first = UUID()
        model.handle(
            .uploadStarted(
                id: first,
                filename: "first.jpg",
                expectedSize: 400,
                batchIndex: 1,
                batchTotal: 3
            )
        )
        model.handle(.uploadStored(id: first, record: TestItems.record(sizeBytes: 400)))

        let second = UUID()
        model.handle(
            .uploadStarted(
                id: second,
                filename: "second.jpg",
                expectedSize: 300,
                batchIndex: 2,
                batchTotal: 3,
                batchTotalBytes: 1_000
            )
        )
        model.handle(.uploadStored(id: second, record: TestItems.record(sizeBytes: 300)))

        let third = UUID()
        model.handle(
            .uploadStarted(
                id: third,
                filename: "third.jpg",
                expectedSize: 300,
                batchIndex: 3,
                batchTotal: 3,
                batchTotalBytes: 1_000
            )
        )

        XCTAssertEqual(model.transferRemainingBytes, 300)
    }

    func testWholeTaskRemainingSumsConcurrentActiveUploads() throws {
        let model = try makeModel()
        let first = UUID()
        let second = UUID()
        model.handle(
            .uploadStarted(
                id: first,
                filename: "first.jpg",
                expectedSize: 400,
                batchIndex: 1,
                batchTotal: 2,
                batchTotalBytes: 1_000
            )
        )
        model.handle(
            .uploadStarted(
                id: second,
                filename: "second.jpg",
                expectedSize: 600,
                batchIndex: 2,
                batchTotal: 2,
                batchTotalBytes: 1_000
            )
        )
        model.handle(.uploadProgress(id: first, bytesReceived: 100, expectedSize: 400))
        model.handle(.uploadProgress(id: second, bytesReceived: 200, expectedSize: 600))

        XCTAssertEqual(model.transferRemainingBytes, 700)
    }

    func testLegacyMultiFileBatchDoesNotUseCurrentFileRemainingAsTaskRemaining() throws {
        let model = try makeModel()
        let id = UUID()
        model.handle(
            .uploadStarted(
                id: id,
                filename: "first.jpg",
                expectedSize: 400,
                batchIndex: 1,
                batchTotal: 2
            )
        )
        model.handle(.uploadProgress(id: id, bytesReceived: 100, expectedSize: 400))

        XCTAssertNil(model.transferRemainingBytes)
        XCTAssertNil(model.transferEstimatedSeconds)
    }

    func testLegacySingleFileUsesCurrentFileRemaining() throws {
        let model = try makeModel()
        let id = UUID()
        model.handle(.uploadStarted(id: id, filename: "single.jpg", expectedSize: 100))
        model.handle(.uploadProgress(id: id, bytesReceived: 25, expectedSize: 100))

        XCTAssertEqual(model.transferRemainingBytes, 75)
        XCTAssertNil(model.transferEstimatedSeconds)
    }

    func testTransferETARequiresPositiveSpeed() {
        XCTAssertEqual(
            AppModel.transferETA(remainingBytes: 1_000_000, bytesPerSecond: 500_000),
            2
        )
        XCTAssertNil(AppModel.transferETA(remainingBytes: 1, bytesPerSecond: 0))
        XCTAssertNil(AppModel.transferETA(remainingBytes: -1, bytesPerSecond: 1))
    }

    func testModelEstimatesWholeTaskETAAfterTwoSpeedSamples() throws {
        let model = try makeModel()
        let id = UUID()
        model.handle(
            .uploadStarted(
                id: id,
                filename: "large.jpg",
                expectedSize: 1_000,
                batchIndex: 1,
                batchTotal: 1,
                batchTotalBytes: 1_000
            )
        )
        model.handle(.uploadProgress(id: id, bytesReceived: 100, expectedSize: 1_000))
        Thread.sleep(forTimeInterval: 0.02)
        model.handle(.uploadProgress(id: id, bytesReceived: 200, expectedSize: 1_000))

        XCTAssertGreaterThan(model.transferSpeedBytesPerSecond ?? 0, 0)
        XCTAssertGreaterThan(model.transferEstimatedSeconds ?? 0, 0)
        XCTAssertNotEqual(model.transferETADescription, model.text(.calculating))
    }

    func testTransferDurationRoundsUpAndUsesHoursWhenNeeded() {
        XCTAssertEqual(
            AppModel.formattedTransferDuration(60.1, language: .simplifiedChinese),
            "1:01"
        )
        XCTAssertEqual(
            AppModel.formattedTransferDuration(3_600, language: .english),
            "1:00:00"
        )
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
