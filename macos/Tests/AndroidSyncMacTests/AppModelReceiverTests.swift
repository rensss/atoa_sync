import AndroidSyncCore
import Foundation
import SwiftData
import XCTest
@testable import AndroidSyncMac

@MainActor
final class AppModelReceiverTests: XCTestCase {
    func testUploadFailuresRemoveOnlyMatchingActiveUploadWithoutFailingReceiver() throws {
        let model = try makeModel()
        let firstID = UUID()
        let secondID = UUID()
        model.status = .running

        model.handle(
            .uploadStarted(
                id: firstID,
                filename: "same.jpg",
                expectedSize: 100
            )
        )
        model.handle(
            .uploadStarted(
                id: secondID,
                filename: "same.jpg",
                expectedSize: 200
            )
        )

        XCTAssertEqual(model.activeUploads.count, 2)

        model.handle(
            .uploadFailed(
                id: firstID,
                filename: "same.jpg",
                message: "upload body ended early"
            )
        )

        XCTAssertNil(model.activeUploads[firstID])
        XCTAssertEqual(model.activeUploads[secondID]?.expectedSize, 200)
        XCTAssertEqual(model.status, .running)
        XCTAssertNil(model.lastError)
        XCTAssertNotNil(model.transientUploadMessage)
        XCTAssertTrue(model.items.isEmpty)
    }

    func testStoredUploadRemovesMatchingActiveUpload() throws {
        let model = try makeModel()
        let uploadID = UUID()
        model.handle(
            .uploadStarted(
                id: uploadID,
                filename: "stored.jpg",
                expectedSize: 1
            )
        )

        model.handle(
            .uploadStored(
                id: uploadID,
                record: makeRecord(filename: "stored.jpg")
            )
        )

        XCTAssertTrue(model.activeUploads.isEmpty)
    }

    func testReceiverFailureUpdatesGlobalReceiverState() throws {
        let model = try makeModel()
        let uploadID = UUID()
        model.handle(
            .uploadStarted(
                id: uploadID,
                filename: "failed.jpg",
                expectedSize: 100
            )
        )
        model.handle(
            .uploadFailed(
                id: uploadID,
                filename: "failed.jpg",
                message: "connection reset"
            )
        )

        model.handle(.receiverFailed(message: "listener failed"))

        XCTAssertEqual(model.status, .failed("listener failed"))
        XCTAssertEqual(model.lastError, "listener failed")
        XCTAssertTrue(model.activeUploads.isEmpty)
        XCTAssertNil(model.transientUploadMessage)
    }

    func testStoppingReceiverClearsActiveUploadsWithoutGlobalError() throws {
        let model = try makeModel()
        let uploadID = UUID()
        model.status = .running
        model.handle(
            .uploadStarted(
                id: uploadID,
                filename: "stopped.jpg",
                expectedSize: 100
            )
        )

        model.handle(.stopped)

        XCTAssertTrue(model.activeUploads.isEmpty)
        XCTAssertNil(model.transientUploadMessage)
        XCTAssertNil(model.lastError)
    }

    private func makeModel() throws -> AppModel {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: configuration
        )
        return AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
    }

    private func makeRecord(filename: String) -> UploadRecord {
        UploadRecord(
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
            receivedAt: Date(),
            fileURL: URL(fileURLWithPath: "/tmp/\(filename)")
        )
    }
}
