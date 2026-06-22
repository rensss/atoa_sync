import Foundation
import XCTest
@testable import AndroidSyncCore

final class LibraryRepositoryTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testStorePreservesBytesMetadataAndModifiedTime() async throws {
        let repository = LibraryRepository(
            rootURL: temporaryDirectory,
            now: { Date(timeIntervalSince1970: 1_780_488_600) }
        )
        let metadata = UploadMetadata(
            filename: "IMG_0001.jpg",
            contentType: "image/jpeg",
            stableID: "image:42",
            dateModifiedMillis: 1_780_482_600_000,
            dateTakenMillis: 1_780_479_000_000,
            dateAddedMillis: 1_780_478_000_000,
            sourceIP: "192.168.1.20"
        )

        let record = try await repository.store(data: Data("photo bytes".utf8), metadata: metadata)

        XCTAssertEqual(record.kind, .photo)
        XCTAssertEqual(record.sizeBytes, 11)
        XCTAssertEqual(try Data(contentsOf: record.fileURL), Data("photo bytes".utf8))
        XCTAssertEqual(
            Int(try record.fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate!.timeIntervalSince1970),
            1_780_482_600
        )

        let sidecar = record.fileURL.appendingPathExtension("metadata.json")
        let sidecarJSON = try JSONSerialization.jsonObject(with: Data(contentsOf: sidecar)) as! [String: Any]
        XCTAssertEqual(sidecarJSON["stable_id"] as? String, "image:42")
        XCTAssertEqual(sidecarJSON["date_taken_millis"] as? Int, 1_780_479_000_000)

        let log = try String(contentsOf: temporaryDirectory.appendingPathComponent("uploads.jsonl"))
        XCTAssertTrue(log.contains("\"status\":\"stored\""))
        XCTAssertTrue(log.contains("\"stable_id\":\"image:42\""))
    }

    func testStoreUsesIncrementingNameForCollision() async throws {
        let repository = LibraryRepository(rootURL: temporaryDirectory)
        let metadata = UploadMetadata(filename: "same.jpg", contentType: "image/jpeg")

        let first = try await repository.store(data: Data([1]), metadata: metadata)
        let second = try await repository.store(data: Data([2]), metadata: metadata)

        XCTAssertEqual(first.fileURL.lastPathComponent, "same.jpg")
        XCTAssertEqual(second.fileURL.lastPathComponent, "same-2.jpg")
    }

    func testRenameMovesFileAndSidecarWithoutChangingStableID() async throws {
        let repository = LibraryRepository(rootURL: temporaryDirectory)
        let original = try await repository.store(
            data: Data([1, 2, 3]),
            metadata: UploadMetadata(
                filename: "before.jpg",
                contentType: "image/jpeg",
                stableID: "image:rename"
            )
        )

        let renamed = try await repository.rename(original, to: "after.jpg")

        XCTAssertFalse(FileManager.default.fileExists(atPath: original.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: renamed.fileURL.appendingPathExtension("metadata.json").path
        ))
        XCTAssertEqual(renamed.stableID, "image:rename")
    }

    func testDeleteMovesFileAndSidecarAndKeepsManifestTombstone() async throws {
        let repository = LibraryRepository(rootURL: temporaryDirectory)
        let original = try await repository.store(
            data: Data([1, 2, 3]),
            metadata: UploadMetadata(
                filename: "delete.jpg",
                contentType: "image/jpeg",
                stableID: "image:deleted"
            )
        )
        let trashDirectory = temporaryDirectory.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)

        try await repository.delete(original) { source in
            let destination = trashDirectory.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.moveItem(at: source, to: destination)
        }

        let manifest = try await repository.manifest()
        XCTAssertEqual(manifest.count, 1)
        XCTAssertEqual(manifest[0].stableID, "image:deleted")
        XCTAssertTrue(manifest[0].deleted)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: trashDirectory.appendingPathComponent("delete.jpg").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: trashDirectory.appendingPathComponent("delete.jpg.metadata.json").path
        ))
    }

    func testDeleteMissingFileRecordsTombstoneWithoutError() async throws {
        let repository = LibraryRepository(rootURL: temporaryDirectory)
        let original = try await repository.store(
            data: Data([1, 2, 3]),
            metadata: UploadMetadata(
                filename: "missing.jpg",
                contentType: "image/jpeg",
                stableID: "image:missing"
            )
        )
        try FileManager.default.removeItem(at: original.fileURL)
        try FileManager.default.removeItem(at: original.fileURL.appendingPathExtension("metadata.json"))

        let trashedURLs = LockedValue<[URL]>([])
        try await repository.delete(original) { source in
            trashedURLs.update { $0.append(source) }
        }

        let manifest = try await repository.manifest()
        XCTAssertTrue(trashedURLs.value.isEmpty)
        XCTAssertEqual(manifest.count, 1)
        XCTAssertEqual(manifest[0].stableID, "image:missing")
        XCTAssertTrue(manifest[0].deleted)
    }

    func testDeleteAlreadyDeletedRecordIsNoOp() async throws {
        let repository = LibraryRepository(rootURL: temporaryDirectory)
        let original = try await repository.store(
            data: Data([1, 2, 3]),
            metadata: UploadMetadata(
                filename: "already-deleted.jpg",
                contentType: "image/jpeg",
                stableID: "image:already-deleted"
            )
        )
        let deleted = original.replacing(
            fileURL: original.fileURL,
            filename: original.filename,
            deleted: true
        )

        let trashCallCount = LockedValue(0)
        try await repository.delete(deleted) { _ in
            trashCallCount.update { $0 += 1 }
        }

        let manifest = try await repository.manifest()
        XCTAssertEqual(trashCallCount.value, 0)
        XCTAssertEqual(manifest.count, 1)
        XCTAssertEqual(manifest[0].stableID, "image:already-deleted")
        XCTAssertFalse(manifest[0].deleted)
    }

    func testLoadsLegacyPythonJSONLRecords() async throws {
        let log = """
        {"time":"2026-06-03T10:30:00","client_ip":"192.168.1.9","filename":"legacy.jpg","kind":"photos","size_bytes":3,"status":"stored","stable_id":"image:legacy","path":"\(temporaryDirectory.path)/photos/2026-06/legacy.jpg"}
        """
        try log.write(
            to: temporaryDirectory.appendingPathComponent("uploads.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let repository = LibraryRepository(rootURL: temporaryDirectory)
        let manifest = try await repository.manifest()

        XCTAssertEqual(manifest.count, 1)
        XCTAssertEqual(manifest[0].stableID, "image:legacy")
        XCTAssertEqual(manifest[0].filename, "legacy.jpg")
        XCTAssertFalse(manifest[0].deleted)
    }

    func testCommitTemporaryUploadRejectsTruncatedBodyAndCleansPartFile() async throws {
        let repository = LibraryRepository(rootURL: temporaryDirectory)
        let temporaryURL = try await repository.makeTemporaryUploadURL()
        try Data([1, 2]).write(to: temporaryURL)

        do {
            _ = try await repository.commitTemporaryUpload(
                at: temporaryURL,
                expectedSize: 3,
                metadata: UploadMetadata(filename: "short.mp4", contentType: "video/mp4")
            )
            XCTFail("Expected a truncated upload error")
        } catch let error as UploadStorageError {
            XCTAssertEqual(error, .sizeMismatch(expected: 3, actual: 2))
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))
        let manifest = try await repository.manifest()
        XCTAssertTrue(manifest.isEmpty)
    }

    func testStoreDoesNotOverwriteOrphanedSidecar() async throws {
        let orphanedSidecar = temporaryDirectory
            .appendingPathComponent("photos/2026-06/orphan.jpg.metadata.json")
        try FileManager.default.createDirectory(
            at: orphanedSidecar.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let originalSidecar = Data("existing sidecar".utf8)
        try originalSidecar.write(to: orphanedSidecar)
        let repository = LibraryRepository(
            rootURL: temporaryDirectory,
            now: { Date(timeIntervalSince1970: 1_780_488_600) }
        )

        let record = try await repository.store(
            data: Data([1, 2, 3]),
            metadata: UploadMetadata(filename: "orphan.jpg", contentType: "image/jpeg")
        )

        XCTAssertEqual(record.filename, "orphan-2.jpg")
        XCTAssertEqual(try Data(contentsOf: orphanedSidecar), originalSidecar)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: record.fileURL.appendingPathExtension("metadata.json").path
        ))
    }

    func testLogReplacementFailurePreservesPreviousLogAndRollsBackNewArtifacts() async throws {
        let baselineRepository = LibraryRepository(rootURL: temporaryDirectory)
        _ = try await baselineRepository.store(
            data: Data([1]),
            metadata: UploadMetadata(
                filename: "baseline.jpg",
                contentType: "image/jpeg",
                stableID: "image:baseline"
            )
        )
        let logURL = temporaryDirectory.appendingPathComponent("uploads.jsonl")
        let originalLog = try Data(contentsOf: logURL)
        let repository = LibraryRepository(
            rootURL: temporaryDirectory,
            hooks: LibraryRepositoryHooks(
                beforeLogReplace: {
                    throw InjectedStorageFailure()
                }
            )
        )

        do {
            _ = try await repository.store(
                data: Data([2]),
                metadata: UploadMetadata(
                    filename: "rollback.jpg",
                    contentType: "image/jpeg",
                    stableID: "image:rollback"
                )
            )
            XCTFail("Expected injected log replacement failure")
        } catch is InjectedStorageFailure {
            // Expected.
        }

        XCTAssertEqual(try Data(contentsOf: logURL), originalLog)
        XCTAssertFalse(try allPaths().contains { $0.contains("rollback.jpg") })
        XCTAssertFalse(try allPaths().contains { $0.contains(".uploads-log-") })
        let manifest = try await repository.manifest()
        XCTAssertEqual(manifest.map(\.stableID), ["image:baseline"])
    }

    func testLibraryRecordsRebuildsStoredAndDeletedItemsFromLog() async throws {
        let photoDirectory = temporaryDirectory
            .appendingPathComponent("photos/2026-06", isDirectory: true)
        try FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
        let photoURL = photoDirectory.appendingPathComponent("kept.jpg")
        try Data([1, 2, 3]).write(to: photoURL)

        let log = """
        {"time":"2026-06-03T10:30:00","client_ip":"192.168.1.9","filename":"kept.jpg","kind":"photos","size_bytes":3,"status":"stored","stable_id":"image:kept","path":"\(photoURL.path)"}
        {"time":"2026-06-03T10:31:00","client_ip":"192.168.1.9","filename":"gone.jpg","kind":"photos","size_bytes":4,"status":"stored","stable_id":"image:gone","path":"\(photoDirectory.appendingPathComponent("gone.jpg").path)"}
        {"time":"2026-06-03T10:32:00","client_ip":"192.168.1.9","filename":"gone.jpg","kind":"photos","size_bytes":4,"status":"deleted","stable_id":"image:gone","path":"\(photoDirectory.appendingPathComponent("gone.jpg").path)","deleted":true}
        """
        try log.write(
            to: temporaryDirectory.appendingPathComponent("uploads.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let repository = LibraryRepository(rootURL: temporaryDirectory)
        let records = try await repository.libraryRecords()

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.first(where: { $0.stableID == "image:kept" })?.deleted, false)
        XCTAssertEqual(records.first(where: { $0.stableID == "image:gone" })?.deleted, true)
    }

    private func allPaths() throws -> [String] {
        try FileManager.default.subpathsOfDirectory(atPath: temporaryDirectory.path)
    }
}

private struct InjectedStorageFailure: Error {}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    init(_ value: Value) {
        storedValue = value
    }

    var value: Value {
        lock.withLock { storedValue }
    }

    func update(_ body: (inout Value) -> Void) {
        lock.withLock {
            body(&storedValue)
        }
    }
}
