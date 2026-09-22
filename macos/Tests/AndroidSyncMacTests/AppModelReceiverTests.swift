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

    func testPauseResumeUsesSameReceiverAndDisablesDuringTransition() async throws {
        let receiverFactory = TestReceiverFactory()
        let model = try makeModel(receiverFactory: receiverFactory.make)
        let directory = temporaryDirectory(named: "pause-resume")
        defer { try? FileManager.default.removeItem(at: directory) }

        await model.configureDirectory(directory).value
        let originalService = try XCTUnwrap(receiverFactory.services.first)
        XCTAssertEqual(model.receiverActionTitle, model.text(.pauseReceiving))
        XCTAssertEqual(model.receiverActionHelp, model.receiverActionTitle)
        XCTAssertEqual(model.receiverActionSystemImage, "pause.fill")

        let pause = model.toggleReceiver()
        XCTAssertEqual(model.status, .pausing)
        XCTAssertEqual(model.statusCapsuleTitle, model.text(.receiverPausing))
        XCTAssertTrue(model.receiverActionDisabled)
        XCTAssertEqual(model.receiverActionSystemImage, "arrow.triangle.2.circlepath")
        await pause.value
        await waitForStatus(.paused, model: model)

        XCTAssertEqual(model.status, .paused)
        XCTAssertEqual(model.statusCapsuleTitle, model.text(.receiverPaused))
        XCTAssertEqual(model.receiverActionTitle, model.text(.resumeReceiving))
        XCTAssertFalse(model.receiverActionDisabled)
        XCTAssertEqual(model.receiverActionSystemImage, "play.fill")
        XCTAssertEqual(receiverFactory.services.count, 1)
        XCTAssertEqual(originalService.stopCount, 0)
        XCTAssertEqual(originalService.pauseCount, 1)

        let resume = model.toggleReceiver()
        XCTAssertEqual(model.status, .running)
        await resume.value
        await waitForStatus(.running, model: model)

        XCTAssertEqual(model.receiverActionTitle, model.text(.pauseReceiving))
        XCTAssertEqual(receiverFactory.services.count, 1)
        XCTAssertEqual(originalService.startCount, 1)
        XCTAssertEqual(originalService.stopCount, 0)
        XCTAssertEqual(originalService.resumeCount, 1)
    }

    func testInterruptedUploadRemovesOnlyItsBytesWithoutFailureOrCompletion() async throws {
        let model = try makeModel()
        model.status = .running
        let completedID = UUID()
        let interruptedID = UUID()
        let otherID = UUID()

        model.handle(.uploadStarted(
            id: completedID,
            filename: "completed.jpg",
            expectedSize: 100,
            batchIndex: 1,
            batchTotal: 3,
            batchTotalBytes: 1_000
        ))
        model.handle(.uploadProgress(id: completedID, bytesReceived: 100, expectedSize: 100))
        model.handle(.uploadStored(id: completedID, record: makeRecord(filename: "completed.jpg", sizeBytes: 100)))

        model.handle(.uploadStarted(
            id: interruptedID,
            filename: "video.mp4",
            expectedSize: 400,
            batchIndex: 2,
            batchTotal: 3,
            batchTotalBytes: 1_000
        ))
        model.handle(.uploadStarted(
            id: otherID,
            filename: "other.jpg",
            expectedSize: 300
        ))
        model.handle(.uploadProgress(id: interruptedID, bytesReceived: 100, expectedSize: 400))
        try await Task.sleep(for: .milliseconds(25))
        model.handle(.uploadProgress(id: interruptedID, bytesReceived: 150, expectedSize: 400))
        model.handle(.uploadProgress(id: otherID, bytesReceived: 50, expectedSize: 300))

        XCTAssertNotNil(model.transferSpeedBytesPerSecond)
        XCTAssertEqual(model.transferRemainingBytes, 700)
        XCTAssertEqual(model.transferCompletedCount, 1)

        model.handle(.uploadInterrupted(id: interruptedID, filename: "video.mp4"))

        XCTAssertNil(model.activeUploads[interruptedID])
        XCTAssertEqual(model.activeUploads[otherID]?.bytesReceived, 50)
        XCTAssertEqual(model.transferRemainingBytes, 850)
        XCTAssertEqual(model.transferCompletedCount, 1)
        XCTAssertEqual(model.transferTotalCount, 3)
        XCTAssertEqual(model.transferSpeedBytesPerSecond, nil)
        XCTAssertEqual(model.transferCardState, .paused)
        XCTAssertNil(model.transientUploadMessage)

        model.handle(.availabilityChanged(state: .paused))
        XCTAssertEqual(model.status, .paused)
        model.handle(.availabilityChanged(state: .running))
        let retryID = UUID()
        model.handle(.uploadStarted(
            id: retryID,
            filename: "video.mp4",
            expectedSize: 400,
            batchIndex: 2,
            batchTotal: 3,
            batchTotalBytes: 1_000
        ))
        XCTAssertEqual(model.transferCardState, .receiving)
        XCTAssertEqual(model.transferRemainingBytes, 850)
        XCTAssertEqual(model.transferCompletedCount, 1)
    }

    func testOldReceiverEventsCannotOverwriteNewReceiverState() async throws {
        let model = try makeModel()
        let firstDirectory = temporaryDirectory(named: "first")
        let secondDirectory = temporaryDirectory(named: "second")
        defer {
            try? FileManager.default.removeItem(at: firstDirectory)
            try? FileManager.default.removeItem(at: secondDirectory)
        }

        await model.configureDirectory(
            firstDirectory,
            startReceiverAfterConfiguration: false
        ).value
        let oldGeneration = model.receiverGeneration
        await model.configureDirectory(
            secondDirectory,
            startReceiverAfterConfiguration: false
        ).value
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

    func testPendingStartDoesNotBlockDirectoryConfiguration() async throws {
        let receiverFactory = TestReceiverFactory()
        receiverFactory.blockNextStart()
        let model = try makeModel(receiverFactory: receiverFactory.make)
        let oldDirectory = temporaryDirectory(named: "old")
        let newDirectory = temporaryDirectory(named: "new")
        defer {
            try? FileManager.default.removeItem(at: oldDirectory)
            try? FileManager.default.removeItem(at: newDirectory)
        }

        let initial = model.configureDirectory(oldDirectory)
        let pendingService = await receiverFactory.waitForService(at: 0)
        await pendingService.waitUntilStartRequested()

        let configuration = model.configureDirectory(
            newDirectory,
            startReceiverAfterConfiguration: false
        )
        await configuration.value
        await initial.value

        XCTAssertEqual(model.receiveDirectory, newDirectory)
        XCTAssertEqual(model.status, .stopped)
        XCTAssertEqual(receiverFactory.services.count, 1)
    }

    func testPendingStartDoesNotBlockRestart() async throws {
        let receiverFactory = TestReceiverFactory()
        let model = try makeModel(receiverFactory: receiverFactory.make)
        let directory = temporaryDirectory(named: "receiver")
        defer { try? FileManager.default.removeItem(at: directory) }

        await model.configureDirectory(
            directory,
            startReceiverAfterConfiguration: false
        ).value
        receiverFactory.blockNextStart()
        let start = model.toggleReceiver()
        let pendingService = await receiverFactory.waitForService(at: 0)
        await pendingService.waitUntilStartRequested()

        let restart = model.restartReceiver()
        await restart.value
        await start.value

        XCTAssertEqual(receiverFactory.services.count, 2)
        XCTAssertEqual(model.status, .running)
    }

    func testStoredUploadReloadFromOldDirectoryCannotOverwriteNewDirectory() async throws {
        let receiverFactory = TestReceiverFactory()
        let libraryLoader = TestLibraryLoader()
        let model = try makeModel(
            receiverFactory: receiverFactory.make,
            libraryRecordsLoader: libraryLoader.load
        )
        let oldDirectory = temporaryDirectory(named: "old")
        let newDirectory = temporaryDirectory(named: "new")
        defer {
            try? FileManager.default.removeItem(at: oldDirectory)
            try? FileManager.default.removeItem(at: newDirectory)
        }
        await libraryLoader.setRecords([], for: oldDirectory)
        await libraryLoader.setRecords(
            [makeRecord(filename: "new.jpg", root: newDirectory)],
            for: newDirectory
        )

        await model.configureDirectory(
            oldDirectory,
            startReceiverAfterConfiguration: false
        ).value
        let generation = model.receiverGeneration
        await libraryLoader.blockNextLoad(
            for: oldDirectory,
            records: [makeRecord(filename: "old.jpg", root: oldDirectory)]
        )

        model.handle(
            .uploadStored(
                id: UUID(),
                record: makeRecord(filename: "old.jpg", root: oldDirectory)
            ),
            generation: generation
        )
        await libraryLoader.waitUntilBlockedLoadStarts()

        await model.configureDirectory(
            newDirectory,
            startReceiverAfterConfiguration: false
        ).value
        XCTAssertEqual(model.items.map(\.filename), ["new.jpg"])

        await libraryLoader.releaseBlockedLoad()
        await libraryLoader.waitUntilBlockedLoadFinishes()
        await Task.yield()

        XCTAssertEqual(model.receiveDirectory, newDirectory)
        XCTAssertEqual(model.items.map(\.filename), ["new.jpg"])
    }

    func testSameDirectoryConfigurationReloadsAfterReceiverStops() async throws {
        let receiverFactory = TestReceiverFactory()
        let libraryLoader = TestLibraryLoader()
        let model = try makeModel(
            receiverFactory: receiverFactory.make,
            libraryRecordsLoader: libraryLoader.load
        )
        let directory = temporaryDirectory(named: "same")
        defer { try? FileManager.default.removeItem(at: directory) }
        await libraryLoader.setRecords([], for: directory)

        await model.configureDirectory(directory).value
        let runningService = try XCTUnwrap(receiverFactory.services.first)
        runningService.blockStop()

        let configuration = model.configureDirectory(
            directory,
            startReceiverAfterConfiguration: false
        )
        await runningService.waitUntilStopRequested()
        await libraryLoader.setRecords(
            [makeRecord(filename: "committed.jpg", root: directory)],
            for: directory
        )
        runningService.allowStop()
        await configuration.value

        XCTAssertEqual(model.receiveDirectory, directory)
        XCTAssertEqual(model.items.map(\.filename), ["committed.jpg"])
        XCTAssertEqual(model.status, .stopped)
    }

    func testSingleStartAfterListenerFailureWaitsForShutdownAndRecovers() async throws {
        let receiverFactory = TestReceiverFactory()
        let model = try makeModel(receiverFactory: receiverFactory.make)
        let directory = temporaryDirectory(named: "receiver")
        defer { try? FileManager.default.removeItem(at: directory) }

        await model.configureDirectory(directory).value
        let failedService = try XCTUnwrap(receiverFactory.services.first)
        failedService.blockStop()
        model.handle(
            .receiverFailed(message: "listener failed"),
            generation: model.receiverGeneration
        )

        let start = model.toggleReceiver()
        await failedService.waitUntilStopRequested()
        XCTAssertEqual(receiverFactory.services.count, 1)

        failedService.allowStop()
        await start.value

        XCTAssertEqual(receiverFactory.services.count, 2)
        XCTAssertEqual(receiverFactory.services.last?.startCount, 1)
        XCTAssertEqual(model.status, .running)
    }

    func testCancelledConfigurationKeepsRunningReceiverAndCleansCandidateScope() async throws {
        let receiverFactory = TestReceiverFactory()
        let bookmarkStore = TestBookmarkStore()
        let directoryAccess = TestDirectoryAccess()
        let libraryLoader = TestLibraryLoader()
        let model = try makeModel(
            receiverFactory: receiverFactory.make,
            bookmarkClient: bookmarkStore.client,
            directoryAccessClient: directoryAccess.client,
            libraryRecordsLoader: libraryLoader.load
        )
        let oldDirectory = temporaryDirectory(named: "old")
        let cancelledDirectory = temporaryDirectory(named: "cancelled")
        defer {
            try? FileManager.default.removeItem(at: oldDirectory)
            try? FileManager.default.removeItem(at: cancelledDirectory)
        }
        await libraryLoader.setRecords([], for: oldDirectory)

        await model.configureDirectory(oldDirectory).value
        let runningService = try XCTUnwrap(receiverFactory.services.first)
        bookmarkStore.reset()
        directoryAccess.reset()
        await libraryLoader.blockNextLoad(for: cancelledDirectory, records: [])

        let configuration = model.configureDirectory(
            cancelledDirectory,
            startReceiverAfterConfiguration: false
        )
        await libraryLoader.waitUntilBlockedLoadStarts()
        configuration.cancel()
        XCTAssertEqual(model.receiveDirectory, oldDirectory)
        XCTAssertEqual(model.status, .running)
        XCTAssertTrue(receiverFactory.services.first === runningService)

        await libraryLoader.releaseBlockedLoad()
        await configuration.value

        XCTAssertEqual(model.receiveDirectory, oldDirectory)
        XCTAssertEqual(model.status, .running)
        XCTAssertEqual(receiverFactory.services.count, 1)
        XCTAssertEqual(runningService.stopCount, 0)
        XCTAssertTrue(bookmarkStore.savedURLs.isEmpty)
        XCTAssertEqual(directoryAccess.startedURLs, [cancelledDirectory])
        XCTAssertEqual(directoryAccess.stoppedURLs, [cancelledDirectory])
    }

    func testBookmarkSaveFailureKeepsCurrentDirectoryAndReceiver() async throws {
        let receiverFactory = TestReceiverFactory()
        let bookmarkStore = TestBookmarkStore()
        let directoryAccess = TestDirectoryAccess()
        let model = try makeModel(
            receiverFactory: receiverFactory.make,
            bookmarkClient: bookmarkStore.client,
            directoryAccessClient: directoryAccess.client
        )
        let oldDirectory = temporaryDirectory(named: "old")
        let rejectedDirectory = temporaryDirectory(named: "rejected")
        defer {
            try? FileManager.default.removeItem(at: oldDirectory)
            try? FileManager.default.removeItem(at: rejectedDirectory)
        }

        await model.configureDirectory(oldDirectory).value
        let runningService = try XCTUnwrap(receiverFactory.services.first)
        bookmarkStore.reset()
        directoryAccess.reset()
        bookmarkStore.failNextSave()

        await model.configureDirectory(
            rejectedDirectory,
            startReceiverAfterConfiguration: false
        ).value

        XCTAssertEqual(model.receiveDirectory, oldDirectory)
        XCTAssertEqual(model.status, .running)
        XCTAssertTrue(receiverFactory.services.first === runningService)
        XCTAssertEqual(receiverFactory.services.count, 1)
        XCTAssertEqual(runningService.stopCount, 0)
        XCTAssertEqual(bookmarkStore.currentURL, oldDirectory)
        XCTAssertTrue(bookmarkStore.savedURLs.isEmpty)
        XCTAssertEqual(directoryAccess.startedURLs, [rejectedDirectory])
        XCTAssertEqual(directoryAccess.stoppedURLs, [rejectedDirectory])
    }

    func testBlockedOldCandidateDoesNotBlockLatestConfiguration() async throws {
        let receiverFactory = TestReceiverFactory()
        let bookmarkStore = TestBookmarkStore()
        let directoryAccess = TestDirectoryAccess()
        let libraryLoader = TestLibraryLoader()
        let model = try makeModel(
            receiverFactory: receiverFactory.make,
            bookmarkClient: bookmarkStore.client,
            directoryAccessClient: directoryAccess.client,
            libraryRecordsLoader: libraryLoader.load
        )
        let oldDirectory = temporaryDirectory(named: "old")
        let blockedDirectory = temporaryDirectory(named: "blocked")
        let latestDirectory = temporaryDirectory(named: "latest")
        defer {
            try? FileManager.default.removeItem(at: oldDirectory)
            try? FileManager.default.removeItem(at: blockedDirectory)
            try? FileManager.default.removeItem(at: latestDirectory)
        }
        await libraryLoader.setRecords([], for: oldDirectory)
        await libraryLoader.setRecords(
            [makeRecord(filename: "latest.jpg", root: latestDirectory)],
            for: latestDirectory
        )

        await model.configureDirectory(oldDirectory).value
        bookmarkStore.reset()
        directoryAccess.reset()
        await libraryLoader.blockNextLoad(for: blockedDirectory, records: [])

        let blocked = model.configureDirectory(
            blockedDirectory,
            startReceiverAfterConfiguration: false
        )
        await libraryLoader.waitUntilBlockedLoadStarts()
        let latest = model.configureDirectory(
            latestDirectory,
            startReceiverAfterConfiguration: false
        )
        await latest.value

        XCTAssertEqual(model.receiveDirectory, latestDirectory)
        XCTAssertEqual(model.items.map(\.filename), ["latest.jpg"])

        await libraryLoader.releaseBlockedLoad()
        await blocked.value

        XCTAssertEqual(model.receiveDirectory, latestDirectory)
        XCTAssertEqual(bookmarkStore.savedURLs, [latestDirectory])
        XCTAssertEqual(
            directoryAccess.startedURLs,
            [blockedDirectory, latestDirectory]
        )
        XCTAssertTrue(directoryAccess.stoppedURLs.contains(oldDirectory))
        XCTAssertTrue(directoryAccess.stoppedURLs.contains(blockedDirectory))
    }

    func testBlockedCandidateDoesNotBlockRestart() async throws {
        let receiverFactory = TestReceiverFactory()
        let libraryLoader = TestLibraryLoader()
        let model = try makeModel(
            receiverFactory: receiverFactory.make,
            libraryRecordsLoader: libraryLoader.load
        )
        let oldDirectory = temporaryDirectory(named: "old")
        let blockedDirectory = temporaryDirectory(named: "blocked")
        defer {
            try? FileManager.default.removeItem(at: oldDirectory)
            try? FileManager.default.removeItem(at: blockedDirectory)
        }
        await libraryLoader.setRecords([], for: oldDirectory)
        await model.configureDirectory(oldDirectory).value
        await libraryLoader.blockNextLoad(for: blockedDirectory, records: [])

        let blocked = model.configureDirectory(blockedDirectory)
        await libraryLoader.waitUntilBlockedLoadStarts()
        let restart = model.restartReceiver()
        await restart.value

        XCTAssertEqual(model.receiveDirectory, oldDirectory)
        XCTAssertEqual(model.status, .running)
        XCTAssertEqual(receiverFactory.services.count, 2)

        await libraryLoader.releaseBlockedLoad()
        await blocked.value
        XCTAssertEqual(model.receiveDirectory, oldDirectory)
    }

    func testSupersededSavedBookmarkRollsBackToCurrentDirectory() async throws {
        let receiverFactory = TestReceiverFactory()
        let bookmarkStore = TestBookmarkStore()
        let model = try makeModel(
            receiverFactory: receiverFactory.make,
            bookmarkClient: bookmarkStore.client
        )
        let oldDirectory = temporaryDirectory(named: "old")
        let candidateDirectory = temporaryDirectory(named: "candidate")
        defer {
            try? FileManager.default.removeItem(at: oldDirectory)
            try? FileManager.default.removeItem(at: candidateDirectory)
        }

        await model.configureDirectory(oldDirectory).value
        bookmarkStore.reset()
        let oldService = try XCTUnwrap(receiverFactory.services.first)
        oldService.blockStop()

        let configuration = model.configureDirectory(
            candidateDirectory,
            startReceiverAfterConfiguration: false
        )
        await oldService.waitUntilStopRequested()
        let restart = model.restartReceiver()
        oldService.allowStop()
        await configuration.value
        await restart.value

        XCTAssertEqual(model.receiveDirectory, oldDirectory)
        XCTAssertEqual(model.status, .running)
        XCTAssertEqual(bookmarkStore.currentURL, oldDirectory)
        XCTAssertEqual(
            bookmarkStore.savedURLs,
            [candidateDirectory, oldDirectory]
        )
    }

    func testCancellationAfterBookmarkSaveRestoresRunningReceiver() async throws {
        let receiverFactory = TestReceiverFactory()
        let bookmarkStore = TestBookmarkStore()
        let directoryAccess = TestDirectoryAccess()
        let model = try makeModel(
            receiverFactory: receiverFactory.make,
            bookmarkClient: bookmarkStore.client,
            directoryAccessClient: directoryAccess.client
        )
        let oldDirectory = temporaryDirectory(named: "old")
        let candidateDirectory = temporaryDirectory(named: "candidate")
        defer {
            try? FileManager.default.removeItem(at: oldDirectory)
            try? FileManager.default.removeItem(at: candidateDirectory)
        }

        await model.configureDirectory(oldDirectory).value
        bookmarkStore.reset()
        directoryAccess.reset()
        let oldService = try XCTUnwrap(receiverFactory.services.first)
        oldService.blockStop()

        let configuration = model.configureDirectory(
            candidateDirectory,
            startReceiverAfterConfiguration: false
        )
        await oldService.waitUntilStopRequested()
        configuration.cancel()
        oldService.allowStop()
        await configuration.value

        XCTAssertEqual(model.receiveDirectory, oldDirectory)
        XCTAssertEqual(model.status, .running)
        XCTAssertEqual(receiverFactory.services.count, 2)
        XCTAssertEqual(bookmarkStore.currentURL, oldDirectory)
        XCTAssertEqual(
            bookmarkStore.savedURLs,
            [candidateDirectory, oldDirectory]
        )
        XCTAssertEqual(directoryAccess.startedURLs, [candidateDirectory])
        XCTAssertEqual(directoryAccess.stoppedURLs, [candidateDirectory])
    }

    func testLaunchFromBookmarkDoesNotPersistBookmarkAgain() async throws {
        let receiverFactory = TestReceiverFactory()
        let bookmarkStore = TestBookmarkStore()
        let directoryAccess = TestDirectoryAccess()
        let directory = temporaryDirectory(named: "launch")
        defer { try? FileManager.default.removeItem(at: directory) }
        bookmarkStore.resolvedURL = directory
        let model = try makeModel(
            receiverFactory: receiverFactory.make,
            bookmarkClient: bookmarkStore.client,
            directoryAccessClient: directoryAccess.client
        )

        await model.launchIfNeeded()

        XCTAssertEqual(model.receiveDirectory, directory)
        XCTAssertTrue(bookmarkStore.savedURLs.isEmpty)
        XCTAssertEqual(receiverFactory.services.count, 1)
        XCTAssertEqual(receiverFactory.services.first?.startCount, 1)
        XCTAssertEqual(model.status, .running)
    }

    private func makeModel(
        receiverFactory: AppModel.ReceiverServiceFactory? = nil,
        bookmarkClient: DirectoryBookmarkClient = .init(
            resolve: { nil },
            save: { _ in },
            clear: {}
        ),
        directoryAccessClient: DirectoryAccessClient = .init(
            start: { _ in true },
            stop: { _ in }
        ),
        libraryRecordsLoader: @escaping AppModel.LibraryRecordsLoader = {
            try $0.libraryRecords()
        }
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
                receiverServiceFactory: receiverFactory,
                bookmarkClient: bookmarkClient,
                directoryAccessClient: directoryAccessClient,
                libraryRecordsLoader: libraryRecordsLoader
            )
        }
        return AppModel(
            modelContainer: container,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            bookmarkClient: bookmarkClient,
            directoryAccessClient: directoryAccessClient,
            libraryRecordsLoader: libraryRecordsLoader
        )
    }

    private func makeRecord(
        filename: String,
        root: URL = URL(fileURLWithPath: "/tmp"),
        sizeBytes: Int64 = 1
    ) -> UploadRecord {
        UploadRecord(
            filename: filename,
            originalFilename: filename,
            kind: .photo,
            sizeBytes: sizeBytes,
            contentType: "image/jpeg",
            stableID: filename,
            dateModifiedMillis: nil,
            dateTakenMillis: nil,
            dateAddedMillis: nil,
            sourceIP: nil,
            receivedAt: Date(),
            fileURL: root.appendingPathComponent(filename)
        )
    }

    private func temporaryDirectory(named name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(name)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func waitForStatus(_ expected: ReceiverStatus, model: AppModel) async {
        for _ in 0..<100 where model.status != expected {
            await Task.yield()
        }
    }
}

@MainActor
private final class TestReceiverFactory {
    private(set) var services: [TestReceiverService] = []
    private var shouldBlockNextStart = false

    func make(
        repository: LibraryRepository,
        port: UInt16,
        eventHandler: @escaping ReceiverService.EventHandler
    ) -> any ReceiverServiceControlling {
        let service = TestReceiverService(eventHandler: eventHandler)
        if shouldBlockNextStart {
            shouldBlockNextStart = false
            service.blockStart()
        }
        services.append(service)
        return service
    }

    func blockNextStart() {
        shouldBlockNextStart = true
    }

    func waitForService(at index: Int) async -> TestReceiverService {
        while services.indices.contains(index) == false {
            await Task.yield()
        }
        return services[index]
    }
}

private final class TestReceiverService: ReceiverServiceControlling, @unchecked Sendable {
    private let lock = NSLock()
    private let eventHandler: ReceiverService.EventHandler
    private var stopGates: [CheckedContinuation<Void, Never>] = []
    private var stopRequestedContinuation: CheckedContinuation<Void, Never>?
    private var startGate: CheckedContinuation<UInt16, any Error>?
    private var startRequestedContinuation: CheckedContinuation<Void, Never>?
    private var shouldBlockStart = false
    private var didRequestStart = false
    private var shouldBlockStop = false
    private var didRequestStop = false
    private var storedStartCount = 0
    private var storedStopCount = 0
    private var storedPauseCount = 0
    private var storedResumeCount = 0

    init(eventHandler: @escaping ReceiverService.EventHandler) {
        self.eventHandler = eventHandler
    }

    var startCount: Int {
        lock.withLock { storedStartCount }
    }

    var stopCount: Int {
        lock.withLock { storedStopCount }
    }

    var pauseCount: Int {
        lock.withLock { storedPauseCount }
    }

    var resumeCount: Int {
        lock.withLock { storedResumeCount }
    }

    func pause() async {
        lock.withLock { storedPauseCount += 1 }
        eventHandler(.availabilityChanged(state: .pausing))
        eventHandler(.availabilityChanged(state: .paused))
    }

    func resume() async {
        lock.withLock { storedResumeCount += 1 }
        eventHandler(.availabilityChanged(state: .running))
    }

    func start() async throws -> UInt16 {
        let shouldBlock = lock.withLock {
            storedStartCount += 1
            didRequestStart = true
            let waiter = startRequestedContinuation
            startRequestedContinuation = nil
            waiter?.resume()
            return shouldBlockStart
        }
        guard shouldBlock else {
            return 8765
        }
        return try await withCheckedThrowingContinuation { continuation in
            let resumeImmediately = lock.withLock {
                if shouldBlockStart {
                    startGate = continuation
                    return false
                }
                return true
            }
            if resumeImmediately {
                continuation.resume(returning: 8765)
            }
        }
    }

    func stop() {
        let continuation = lock.withLock {
            storedStopCount += 1
            shouldBlockStart = false
            let continuation = startGate
            startGate = nil
            return continuation
        }
        continuation?.resume(returning: 8765)
    }

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

    func blockStart() {
        lock.withLock {
            shouldBlockStart = true
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

    func waitUntilStartRequested() async {
        if lock.withLock({ didRequestStart }) {
            return
        }
        await withCheckedContinuation { continuation in
            lock.withLock {
                if didRequestStart {
                    continuation.resume()
                } else {
                    startRequestedContinuation = continuation
                }
            }
        }
    }
}

@MainActor
private final class TestBookmarkStore {
    enum Failure: Error {
        case saveFailed
    }

    var resolvedURL: URL?
    private(set) var currentURL: URL?
    private(set) var savedURLs: [URL] = []
    private(set) var clearCount = 0
    private var shouldFailNextSave = false

    var client: DirectoryBookmarkClient {
        DirectoryBookmarkClient(
            resolve: { [weak self] in self?.resolvedURL },
            save: { [weak self] url in
                guard let self else { return }
                if self.shouldFailNextSave {
                    self.shouldFailNextSave = false
                    throw Failure.saveFailed
                }
                self.currentURL = url
                self.savedURLs.append(url)
            },
            clear: { [weak self] in
                self?.currentURL = nil
                self?.clearCount += 1
            }
        )
    }

    func reset() {
        savedURLs.removeAll()
        clearCount = 0
    }

    func failNextSave() {
        shouldFailNextSave = true
    }
}

@MainActor
private final class TestDirectoryAccess {
    private(set) var startedURLs: [URL] = []
    private(set) var stoppedURLs: [URL] = []

    var client: DirectoryAccessClient {
        DirectoryAccessClient(
            start: { [weak self] url in
                self?.startedURLs.append(url)
                return true
            },
            stop: { [weak self] url in self?.stoppedURLs.append(url) }
        )
    }

    func reset() {
        startedURLs.removeAll()
        stoppedURLs.removeAll()
    }
}

private actor TestLibraryLoader {
    private var recordsByPath: [String: [UploadRecord]] = [:]
    private var blockedPath: String?
    private var blockedRecords: [UploadRecord] = []
    private var blockedLoadStarted = false
    private var blockedLoadFinished = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var finishWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func setRecords(_ records: [UploadRecord], for directory: URL) {
        recordsByPath[directory.path] = records
    }

    func blockNextLoad(for directory: URL, records: [UploadRecord]) {
        blockedPath = directory.path
        blockedRecords = records
        blockedLoadStarted = false
        blockedLoadFinished = false
    }

    func load(_ repository: LibraryRepository) async throws -> [UploadRecord] {
        let path = await repository.rootURL.path
        if path == blockedPath {
            blockedPath = nil
            blockedLoadStarted = true
            startWaiters.forEach { $0.resume() }
            startWaiters.removeAll()
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
            blockedLoadFinished = true
            finishWaiters.forEach { $0.resume() }
            finishWaiters.removeAll()
            return blockedRecords
        }
        return recordsByPath[path] ?? []
    }

    func waitUntilBlockedLoadStarts() async {
        guard !blockedLoadStarted else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releaseBlockedLoad() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func waitUntilBlockedLoadFinishes() async {
        guard !blockedLoadFinished else { return }
        await withCheckedContinuation { continuation in
            finishWaiters.append(continuation)
        }
    }
}
