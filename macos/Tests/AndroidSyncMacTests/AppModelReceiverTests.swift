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

    func testOldReceiverEventsCannotOverwriteNewReceiverState() throws {
        let model = try makeModel()
        let oldGeneration = model.receiverGeneration
        model.rebuildReceiverService()
        let newGeneration = model.receiverGeneration
        let uploadID = UUID()

        XCTAssertNotEqual(oldGeneration, newGeneration)
        model.status = .running
        model.handle(
            .uploadStarted(
                id: uploadID,
                filename: "new.jpg",
                expectedSize: 100
            ),
            generation: newGeneration
        )

        model.handle(.stopped, generation: oldGeneration)
        model.handle(
            .receiverFailed(message: "old receiver failed"),
            generation: oldGeneration
        )

        XCTAssertEqual(model.status, .running)
        XCTAssertEqual(model.activeUploads[uploadID]?.filename, "new.jpg")
        XCTAssertNil(model.lastError)
    }

    func testDirectoryTransitionWaitsForOldReceiverAndLatestSelectionWins() async throws {
        let receiverFactory = TestReceiverFactory()
        let model = try makeModel(receiverFactory: receiverFactory.make)
        let oldDirectory = temporaryDirectory(named: "old")
        let firstDirectory = temporaryDirectory(named: "first")
        let latestDirectory = temporaryDirectory(named: "latest")
        defer {
            try? FileManager.default.removeItem(at: oldDirectory)
            try? FileManager.default.removeItem(at: firstDirectory)
            try? FileManager.default.removeItem(at: latestDirectory)
        }

        await model.configureDirectory(
            oldDirectory,
            startReceiverAfterConfiguration: false
        ).value
        let oldReceiverGeneration = model.receiverGeneration
        let oldDirectoryGeneration = model.directoryConfigurationGeneration
        let oldService = try XCTUnwrap(receiverFactory.services.first)
        oldService.blockStop()

        let firstTransition = model.configureDirectory(
            firstDirectory,
            startReceiverAfterConfiguration: false
        )
        await oldService.waitUntilStopRequested()
        let latestTransition = model.configureDirectory(
            latestDirectory,
            startReceiverAfterConfiguration: false
        )

        await Task.yield()
        XCTAssertEqual(model.receiveDirectory, oldDirectory)
        XCTAssertEqual(model.receiverGeneration, oldReceiverGeneration)
        XCTAssertEqual(
            model.directoryConfigurationGeneration,
            oldDirectoryGeneration + 2
        )

        oldService.allowStop()
        await firstTransition.value
        await latestTransition.value

        XCTAssertEqual(model.receiveDirectory, latestDirectory)
        XCTAssertEqual(model.receiverGeneration, oldReceiverGeneration + 1)
        XCTAssertEqual(receiverFactory.services.count, 2)
    }

    private func makeModel(
        receiverFactory: AppModel.ReceiverServiceFactory? = nil
    ) throws -> AppModel {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: configuration
        )
        if let receiverFactory {
            return AppModel(
                modelContainer: container,
                userDefaults: UserDefaults(suiteName: UUID().uuidString)!,
                receiverServiceFactory: receiverFactory
            )
        }
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

    private func temporaryDirectory(named name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(name)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

@MainActor
private final class TestReceiverFactory {
    private(set) var services: [TestReceiverService] = []

    func make(
        repository: LibraryRepository,
        port: UInt16,
        eventHandler: @escaping ReceiverService.EventHandler
    ) -> any ReceiverServiceControlling {
        let service = TestReceiverService()
        services.append(service)
        return service
    }
}

private final class TestReceiverService: ReceiverServiceControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var stopGates: [CheckedContinuation<Void, Never>] = []
    private var stopRequestedContinuation: CheckedContinuation<Void, Never>?
    private var shouldBlockStop = false
    private var didRequestStop = false

    func start() async throws -> UInt16 {
        8765
    }

    func stop() {}

    func stopAndWait() async {
        await withCheckedContinuation { continuation in
            let result = lock.withLock {
                didRequestStop = true
                let requestWaiter = stopRequestedContinuation
                stopRequestedContinuation = nil
                if shouldBlockStop {
                    stopGates.append(continuation)
                    return (requestWaiter, false)
                }
                return (requestWaiter, true)
            }
            result.0?.resume()
            if result.1 {
                continuation.resume()
            }
        }
    }

    func blockStop() {
        lock.withLock {
            shouldBlockStop = true
        }
    }

    func allowStop() {
        let waiters = lock.withLock {
            shouldBlockStop = false
            let waiters = stopGates
            stopGates.removeAll()
            return waiters
        }
        waiters.forEach { $0.resume() }
    }

    func waitUntilStopRequested() async {
        if lock.withLock({ didRequestStop }) {
            return
        }
        await withCheckedContinuation { continuation in
            lock.withLock {
                if didRequestStop {
                    continuation.resume()
                } else {
                    stopRequestedContinuation = continuation
                }
            }
        }
    }
}
