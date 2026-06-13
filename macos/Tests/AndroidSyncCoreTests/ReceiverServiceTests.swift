import Foundation
import Network
import XCTest
@testable import AndroidSyncCore

final class ReceiverServiceTests: XCTestCase {
    func testHealthUploadAndManifestOverRealHTTP() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repository = LibraryRepository(rootURL: root)
        let service = ReceiverService(repository: repository, port: 0)
        let port = try await service.start()
        defer { service.stop() }

        let baseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)"))
        let (healthData, healthResponse) = try await URLSession.shared.data(
            from: baseURL.appendingPathComponent("health")
        )
        XCTAssertEqual((healthResponse as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(
            (try JSONSerialization.jsonObject(with: healthData) as? [String: String])?["status"],
            "ok"
        )

        var uploadRequest = URLRequest(
            url: baseURL.appendingPathComponent("uploads/Network.jpg")
        )
        uploadRequest.httpMethod = "PUT"
        uploadRequest.httpBody = Data("network photo".utf8)
        uploadRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("image:network", forHTTPHeaderField: "X-Android-Sync-Id")
        let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
        XCTAssertEqual((uploadResponse as? HTTPURLResponse)?.statusCode, 201)
        XCTAssertEqual(
            (try JSONSerialization.jsonObject(with: uploadData) as? [String: Any])?["status"] as? String,
            "stored"
        )

        let (manifestData, manifestResponse) = try await URLSession.shared.data(
            from: baseURL.appendingPathComponent("manifest.json")
        )
        XCTAssertEqual((manifestResponse as? HTTPURLResponse)?.statusCode, 200)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as! [String: Any]
        XCTAssertEqual(manifest["count"] as? Int, 1)
        let uploads = manifest["uploads"] as! [[String: Any]]
        XCTAssertEqual(uploads[0]["stable_id"] as? String, "image:network")
    }

    func testInterruptedUploadRemovesTemporaryFileAndEmitsUploadFailure() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let uploadFailed = expectation(description: "upload failed")
        let eventRecorder = ReceiverEventRecorder()
        let repository = LibraryRepository(rootURL: root)
        let service = ReceiverService(repository: repository, port: 0) { event in
            eventRecorder.append(event)
            if case .uploadFailed = event {
                uploadFailed.fulfill()
            }
        }
        let port = try await service.start()
        defer { service.stop() }

        let connection = NWConnection(
            host: NWEndpoint.Host("127.0.0.1"),
            port: try XCTUnwrap(NWEndpoint.Port(rawValue: port)),
            using: .tcp
        )
        let connected = expectation(description: "connected")
        connection.stateUpdateHandler = { (state: NWConnection.State) in
            if case .ready = state {
                connected.fulfill()
            }
        }
        connection.start(queue: DispatchQueue(label: "ReceiverServiceTests.client"))
        await fulfillment(of: [connected], timeout: 2)

        let body = Data("short".utf8)
        let requestHead = [
            "PUT /uploads/Interrupted.jpg HTTP/1.1",
            "Host: 127.0.0.1",
            "Content-Type: image/jpeg",
            "Content-Length: \(body.count + 128)",
            "X-Android-Sync-Id: image:interrupted",
            "Connection: close",
        ].joined(separator: "\r\n") + "\r\n\r\n"
        let request = Data(requestHead.utf8) + body
        var parserBuffer = request
        let parsedHead = try XCTUnwrap(HTTPRequestParser.extractHead(from: &parserBuffer))
        XCTAssertEqual(parsedHead.target, "/uploads/Interrupted.jpg")
        XCTAssertEqual(parserBuffer, body)
        connection.send(
            content: request,
            completion: .contentProcessed { error in
                guard error == nil else {
                    connection.cancel()
                    return
                }
                connection.send(
                    content: nil,
                    contentContext: .finalMessage,
                    isComplete: true,
                    completion: .contentProcessed { _ in }
                )
            }
        )

        await fulfillment(of: [uploadFailed], timeout: 3)
        connection.cancel()
        try await Task.sleep(for: .milliseconds(100))

        let failure = try XCTUnwrap(eventRecorder.uploadFailures.first)
        XCTAssertEqual(failure.filename, "Interrupted.jpg")
        XCTAssertFalse(failure.message.isEmpty)
        XCTAssertEqual(eventRecorder.uploadFailures.count, 1)

        let incomingURL = root.appendingPathComponent(".incoming", isDirectory: true)
        let incomingContents = try FileManager.default.contentsOfDirectory(
            at: incomingURL,
            includingPropertiesForKeys: nil
        )
        let manifest = try await repository.manifest()
        let libraryRecords = try await repository.libraryRecords()
        XCTAssertTrue(incomingContents.isEmpty)
        XCTAssertTrue(manifest.isEmpty)
        XCTAssertTrue(libraryRecords.isEmpty)
    }

    func testRepositoryCommitFailureCleansTemporaryFileAndEmitsOneUploadFailure() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let receivedAt = try XCTUnwrap(
            Calendar(identifier: .gregorian).date(
                from: DateComponents(
                    timeZone: TimeZone(secondsFromGMT: 0),
                    year: 2025,
                    month: 1,
                    day: 15
                )
            )
        )
        let targetDirectory = root
            .appendingPathComponent(UploadKind.photo.rawValue, isDirectory: true)
            .appendingPathComponent("2025-01", isDirectory: true)
        try FileManager.default.createDirectory(
            at: targetDirectory.appendingPathComponent(
                "Commit.jpg.metadata.json",
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let uploadFailed = expectation(description: "upload failed")
        let eventRecorder = ReceiverEventRecorder()
        let repository = LibraryRepository(rootURL: root, now: { receivedAt })
        let service = ReceiverService(repository: repository, port: 0) { event in
            eventRecorder.append(event)
            if case .uploadFailed = event {
                uploadFailed.fulfill()
            }
        }
        let port = try await service.start()
        defer { service.stop() }

        var request = URLRequest(
            url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/uploads/Commit.jpg"))
        )
        request.httpMethod = "PUT"
        request.httpBody = Data("complete body".utf8)
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 500)
        await fulfillment(of: [uploadFailed], timeout: 2)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(eventRecorder.uploadFailures.count, 1)
        XCTAssertEqual(eventRecorder.uploadFailures.first?.filename, "Commit.jpg")
        XCTAssertTrue(try incomingContents(at: root).isEmpty)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: targetDirectory.appendingPathComponent("Commit.jpg").path
            )
        )
        let manifest = try await repository.manifest()
        XCTAssertTrue(manifest.isEmpty)
    }

    func testStoppingReceiverCleansActiveUploadWithoutReportingUploadFailure() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let uploadStarted = expectation(description: "upload started")
        let stopped = expectation(description: "receiver stopped")
        let eventRecorder = ReceiverEventRecorder()
        let repository = LibraryRepository(rootURL: root)
        let service = ReceiverService(repository: repository, port: 0) { event in
            eventRecorder.append(event)
            if case .uploadStarted = event {
                uploadStarted.fulfill()
            }
            if case .stopped = event {
                stopped.fulfill()
            }
        }
        let port = try await service.start()

        let connection = NWConnection(
            host: NWEndpoint.Host("127.0.0.1"),
            port: try XCTUnwrap(NWEndpoint.Port(rawValue: port)),
            using: .tcp
        )
        let connected = expectation(description: "connected")
        connection.stateUpdateHandler = { (state: NWConnection.State) in
            if case .ready = state {
                connected.fulfill()
            }
        }
        connection.start(queue: DispatchQueue(label: "ReceiverServiceTests.stop-client"))
        await fulfillment(of: [connected], timeout: 2)

        let body = Data("partial".utf8)
        let requestHead = [
            "PUT /uploads/Stopped.jpg HTTP/1.1",
            "Host: 127.0.0.1",
            "Content-Type: image/jpeg",
            "Content-Length: \(body.count + 128)",
            "Connection: close",
        ].joined(separator: "\r\n") + "\r\n\r\n"
        connection.send(
            content: Data(requestHead.utf8) + body,
            completion: .contentProcessed { _ in }
        )
        await fulfillment(of: [uploadStarted], timeout: 2)
        try await waitForIncomingFile(at: root)

        service.stop()
        await fulfillment(of: [stopped], timeout: 2)
        connection.cancel()

        XCTAssertTrue(try incomingContents(at: root).isEmpty)
        XCTAssertTrue(eventRecorder.uploadFailures.isEmpty)
        let manifest = try await repository.manifest()
        XCTAssertTrue(manifest.isEmpty)
    }

    private func incomingContents(at root: URL) throws -> [URL] {
        let incomingURL = root.appendingPathComponent(".incoming", isDirectory: true)
        guard FileManager.default.fileExists(atPath: incomingURL.path) else {
            return []
        }
        return try FileManager.default.contentsOfDirectory(
            at: incomingURL,
            includingPropertiesForKeys: nil
        )
    }

    private func waitForIncomingFile(at root: URL) async throws {
        for _ in 0..<100 {
            if try !incomingContents(at: root).isEmpty {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("temporary upload file was not created")
    }
}

private final class ReceiverEventRecorder: @unchecked Sendable {
    struct UploadFailure {
        let filename: String
        let message: String
    }

    private let lock = NSLock()
    private var events: [ReceiverServiceEvent] = []

    var uploadFailures: [UploadFailure] {
        lock.withLock {
            events.compactMap { event in
                guard case let .uploadFailed(_, filename, message) = event else {
                    return nil
                }
                return UploadFailure(filename: filename, message: message)
            }
        }
    }

    func append(_ event: ReceiverServiceEvent) {
        lock.withLock {
            events.append(event)
        }
    }
}
