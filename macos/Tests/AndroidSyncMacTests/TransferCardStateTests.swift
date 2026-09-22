import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class TransferCardStateTests: XCTestCase {
    private func makeModel() throws -> AppModel {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: config
        )
        let model = AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        return model
    }

    func testUploadLifecycleHidesCardImmediatelyAfterLastUpload() throws {
        let model = try makeModel()
        let id = UUID()
        XCTAssertEqual(model.transferCardState, .idle)

        model.handle(.uploadStarted(id: id, filename: "a.jpg", expectedSize: 100))
        XCTAssertEqual(model.transferCardState, .receiving)
        XCTAssertEqual(model.activeUploadsExpectedBytes, 100)
        XCTAssertEqual(model.transferTotalCount, 1)

        model.handle(.uploadStored(id: id, record: TestItems.record()))
        XCTAssertEqual(model.transferCardState, .idle)
        XCTAssertTrue(model.activeUploads.isEmpty)
        XCTAssertEqual(model.transferCompletedCount, 0)
        XCTAssertEqual(model.transferTotalCount, 0)
        XCTAssertNil(model.transferProgress)
        XCTAssertNil(model.transferSpeedBytesPerSecond)
        XCTAssertNil(model.transferRemainingBytes)
        XCTAssertNil(model.transferEstimatedSeconds)
    }

    func testAllFailedBurstSkipsCompletedState() throws {
        let model = try makeModel()
        let id = UUID()
        model.handle(.uploadStarted(id: id, filename: "a.jpg", expectedSize: 100))
        model.handle(.uploadFailed(id: id, filename: "a.jpg", message: "x"))
        XCTAssertEqual(model.transferCardState, .idle)
    }

    func testNewBurstStartsWithFreshProgressStateAfterPreviousCompletion() throws {
        let model = try makeModel()
        let first = UUID()
        model.handle(.uploadStarted(id: first, filename: "a.jpg", expectedSize: 100))
        model.handle(.uploadStored(id: first, record: TestItems.record()))
        XCTAssertEqual(model.transferCardState, .idle)

        let second = UUID()
        model.handle(.uploadStarted(id: second, filename: "b.jpg", expectedSize: 100))
        XCTAssertEqual(model.transferCardState, .receiving)
        model.handle(.uploadStored(id: second, record: TestItems.record()))
        XCTAssertEqual(model.transferCardState, .idle)
    }

    func testIntermediateBatchUploadKeepsCardVisibleUntilBatchEnd() throws {
        let model = try makeModel()
        let first = UUID()
        model.handle(
            .uploadStarted(
                id: first,
                filename: "first.jpg",
                expectedSize: 100,
                batchIndex: 1,
                batchTotal: 2
            )
        )
        model.handle(.uploadStored(id: first, record: TestItems.record()))

        XCTAssertEqual(model.transferCardState, .receiving)
        XCTAssertEqual(model.transferCompletedCount, 1)
        XCTAssertEqual(model.transferTotalCount, 2)

        let second = UUID()
        model.handle(
            .uploadStarted(
                id: second,
                filename: "second.jpg",
                expectedSize: 100,
                batchIndex: 2,
                batchTotal: 2
            )
        )
        model.handle(.uploadStored(id: second, record: TestItems.record()))

        XCTAssertEqual(model.transferCardState, .idle)
        XCTAssertNil(model.transferRemainingBytes)
        XCTAssertNil(model.transferEstimatedSeconds)
    }

    func testTodayStatsCountsOnlyTodayAndNotRemoved() {
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let stats = AppModel.todayStats(
            [
                TestItems.item(receivedAt: now, sizeBytes: 10),
                TestItems.item(receivedAt: now, sizeBytes: 5, removed: true),
                TestItems.item(receivedAt: yesterday, sizeBytes: 100),
            ],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(stats, AppModel.TodayStats(count: 1, bytes: 10))
    }

    func testBatchHeadersExposeTotalTaskCount() throws {
        let model = try makeModel()
        let id = UUID()

        model.handle(
            .uploadStarted(
                id: id,
                filename: "a.jpg",
                expectedSize: 100,
                batchIndex: 2,
                batchTotal: 5
            )
        )

        XCTAssertEqual(model.transferTotalCount, 5)
        XCTAssertEqual(model.transferCompletedCount, 1)
        XCTAssertEqual(model.activeUploadsRemainingBytes, 100)
    }

    func testStaleUploadEventsDoNotChangeCurrentBatchProgress() throws {
        let model = try makeModel()
        let activeID = UUID()
        model.handle(
            .uploadStarted(
                id: activeID,
                filename: "active.jpg",
                expectedSize: 400,
                batchIndex: 1,
                batchTotal: 2,
                batchTotalBytes: 1_000
            )
        )
        model.handle(.uploadProgress(id: activeID, bytesReceived: 100, expectedSize: 400))
        let missingID = UUID()
        model.handle(.uploadStored(id: missingID, record: TestItems.record(sizeBytes: 100)))
        model.handle(.uploadFailed(id: missingID, filename: "stale.jpg", message: "stale"))

        XCTAssertEqual(model.transferRemainingBytes, 900)
        XCTAssertEqual(model.transferCompletedCount, 0)
        XCTAssertNil(model.transientUploadMessage)
        XCTAssertEqual(model.activeUploads.keys.sorted { $0.uuidString < $1.uuidString }, [activeID])
    }

    func testOutOfOrderFailureAfterLastSuccessClearsFinishedBatch() throws {
        let model = try makeModel()
        let first = UUID()
        let last = UUID()
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
                id: last,
                filename: "last.jpg",
                expectedSize: 600,
                batchIndex: 2,
                batchTotal: 2,
                batchTotalBytes: 1_000
            )
        )
        model.handle(.uploadStored(id: last, record: TestItems.record(sizeBytes: 600)))
        XCTAssertEqual(model.transferCardState, .receiving)

        model.handle(.uploadFailed(id: first, filename: "first.jpg", message: "failed"))

        XCTAssertEqual(model.transferCardState, .idle)
        XCTAssertNil(model.transferRemainingBytes)
        XCTAssertNil(model.transferEstimatedSeconds)
    }

    func testNewBatchDoesNotReuseIncompleteBurstAfterCancellation() throws {
        let model = try makeModel()
        let previous = UUID()
        model.handle(
            .uploadStarted(
                id: previous,
                filename: "previous.jpg",
                expectedSize: 400,
                batchIndex: 1,
                batchTotal: 3,
                batchTotalBytes: 1_000
            )
        )
        model.handle(.uploadStored(id: previous, record: TestItems.record(sizeBytes: 400)))
        XCTAssertEqual(model.transferRemainingBytes, 600)

        let next = UUID()
        model.handle(
            .uploadStarted(
                id: next,
                filename: "next.jpg",
                expectedSize: 200,
                batchIndex: 1,
                batchTotal: 2,
                batchTotalBytes: 500
            )
        )

        XCTAssertEqual(model.transferRemainingBytes, 500)
        XCTAssertEqual(model.transferTotalCount, 2)
        XCTAssertEqual(model.transferCompletedCount, 0)
    }
}
