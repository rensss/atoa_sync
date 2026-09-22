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
        let eventRecorder = ReceiverEventRecorder()
        let service = ReceiverService(repository: repository, port: 0, eventHandler: eventRecorder.append)
        let port = try await service.start()
        defer { service.stop() }

        let baseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)"))
        let (healthData, healthResponse) = try await URLSession.shared.data(
            from: baseURL.appendingPathComponent("health")
        )
        XCTAssertEqual((healthResponse as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(
            (try JSONSerialization.jsonObject(with: healthData) as? [String: Any])?["status"] as? String,
            "ok"
        )

        var uploadRequest = URLRequest(
            url: baseURL.appendingPathComponent("uploads/Network.jpg")
        )
        uploadRequest.httpMethod = "PUT"
        uploadRequest.httpBody = Data("network photo".utf8)
        uploadRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("image:network", forHTTPHeaderField: "X-Android-Sync-Id")
        uploadRequest.setValue("13", forHTTPHeaderField: "X-Android-Sync-Batch-Total-Bytes")
        let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
        XCTAssertEqual((uploadResponse as? HTTPURLResponse)?.statusCode, 201)
        XCTAssertEqual(
            (try JSONSerialization.jsonObject(with: uploadData) as? [String: Any])?["status"] as? String,
            "stored"
        )
        XCTAssertEqual(eventRecorder.uploadStartedBatchTotalBytes, [13])

        let (manifestData, manifestResponse) = try await URLSession.shared.data(
            from: baseURL.appendingPathComponent("manifest.json")
        )
        XCTAssertEqual((manifestResponse as? HTTPURLResponse)?.statusCode, 200)
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as! [String: Any]
        XCTAssertEqual(manifest["count"] as? Int, 1)
        let uploads = manifest["uploads"] as! [[String: Any]]
        XCTAssertEqual(uploads[0]["stable_id"] as? String, "image:network")
    }

    func testHealthReportsControlStateAndEpoch() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ReceiverService(repository: LibraryRepository(rootURL: root), port: 0)
        let port = try await service.start()
        defer { service.stop() }

        let (data, response) = try await URLSession.shared.data(
            from: XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/health"))
        )
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let health = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(health["status"] as? String, "ok")
        XCTAssertEqual(health["receiver_state"] as? String, "running")
        XCTAssertEqual(health["pause_epoch"] as? Int, 0)
    }

    func testPauseKeepsHealthAvailableRejectsNewUploadsAndResumeKeepsPort() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ReceiverService(repository: LibraryRepository(rootURL: root), port: 0)
        let port = try await service.start()
        defer { service.stop() }
        let baseURL = try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)"))

        await service.pause()
        let (pausedData, pausedResponse) = try await URLSession.shared.data(
            from: baseURL.appendingPathComponent("health")
        )
        XCTAssertEqual((pausedResponse as? HTTPURLResponse)?.statusCode, 200)
        let pausedHealth = try JSONSerialization.jsonObject(with: pausedData) as! [String: Any]
        XCTAssertEqual(pausedHealth["receiver_state"] as? String, "paused")
        XCTAssertEqual(pausedHealth["pause_epoch"] as? Int, 1)

        var pausedUpload = URLRequest(url: baseURL.appendingPathComponent("uploads/Rejected.jpg"))
        pausedUpload.httpMethod = "PUT"
        pausedUpload.httpBody = Data("body".utf8)
        let (rejectionData, rejectionResponse) = try await URLSession.shared.data(for: pausedUpload)
        XCTAssertEqual((rejectionResponse as? HTTPURLResponse)?.statusCode, 503)
        let rejection = try JSONSerialization.jsonObject(with: rejectionData) as! [String: Any]
        XCTAssertEqual(rejection["error_code"] as? String, "receiver_paused")
        XCTAssertTrue(try incomingContents(at: root).isEmpty)

        await service.resume()
        let (resumedData, resumedResponse) = try await URLSession.shared.data(
            from: baseURL.appendingPathComponent("health")
        )
        XCTAssertEqual((resumedResponse as? HTTPURLResponse)?.statusCode, 200)
        let resumedHealth = try JSONSerialization.jsonObject(with: resumedData) as! [String: Any]
        XCTAssertEqual(resumedHealth["receiver_state"] as? String, "running")
        XCTAssertEqual(resumedHealth["pause_epoch"] as? Int, 1)

        var resumedUpload = URLRequest(url: baseURL.appendingPathComponent("uploads/Accepted.jpg"))
        resumedUpload.httpMethod = "PUT"
        resumedUpload.httpBody = Data("body".utf8)
        let (_, acceptedResponse) = try await URLSession.shared.data(for: resumedUpload)
        XCTAssertEqual((acceptedResponse as? HTTPURLResponse)?.statusCode, 201)
    }

    func testRestartAfterPauseReportsRunningHealth() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = ReceiverService(repository: LibraryRepository(rootURL: root), port: 0)
        _ = try await service.start()
        await service.pause()
        await service.stopAndWait()
        let port = try await service.start()
        defer { service.stop() }

        let (data, response) = try await URLSession.shared.data(
            from: XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/health"))
        )
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let health = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(health["receiver_state"] as? String, "running")
        XCTAssertEqual(health["pause_epoch"] as? Int, 1)
    }

    func testPauseInterruptsUploadAndRemovesTemporaryFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let uploadStarted = expectation(description: "upload started")
        let uploadInterrupted = expectation(description: "upload interrupted")
        let eventRecorder = ReceiverEventRecorder()
        let repository = LibraryRepository(rootURL: root)
        let service = ReceiverService(repository: repository, port: 0) { event in
            eventRecorder.append(event)
            if case .uploadStarted = event { uploadStarted.fulfill() }
            if case .uploadInterrupted = event { uploadInterrupted.fulfill() }
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
            if case .ready = state { connected.fulfill() }
        }
        connection.start(queue: DispatchQueue(label: "ReceiverServiceTests.pause-client"))
        await fulfillment(of: [connected], timeout: 2)

        let requestHead = [
            "PUT /uploads/Paused.jpg HTTP/1.1",
            "Host: 127.0.0.1",
            "Content-Type: image/jpeg",
            "Content-Length: 1048576",
            "X-Android-Sync-Id: image:paused",
            "Connection: close",
        ].joined(separator: "\r\n") + "\r\n\r\n"
        connection.send(
            content: Data((requestHead + "partial").utf8),
            completion: NWConnection.SendCompletion.contentProcessed { _ in }
        )

        await fulfillment(of: [uploadStarted], timeout: 2)
        try await waitForIncomingFile(at: root)
        await service.pause()
        await fulfillment(of: [uploadInterrupted], timeout: 2)
        connection.cancel()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(eventRecorder.uploadInterruptions.map(\.filename), ["Paused.jpg"])
        XCTAssertTrue(eventRecorder.uploadFailures.isEmpty)
        XCTAssertTrue(try incomingContents(at: root).isEmpty)
        let manifest = try await repository.manifest()
        XCTAssertTrue(manifest.isEmpty)
    }

    func testPauseAfterCommitStartsFinishesStoredUpload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let commitEntered = expectation(description: "repository commit entered")
        let uploadStored = expectation(description: "upload stored")
        let eventRecorder = ReceiverEventRecorder()
        let commitGate = AsyncTestGate()
        let repository = LibraryRepository(
            rootURL: root,
            hooks: LibraryRepositoryHooks(afterFileMove: {
                commitEntered.fulfill()
                await commitGate.wait()
            })
        )
        let service = ReceiverService(repository: repository, port: 0) { event in
            eventRecorder.append(event)
            if case .uploadStored = event { uploadStored.fulfill() }
        }
        let port = try await service.start()
        defer { service.stop() }

        var request = URLRequest(
            url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/uploads/CommitDuringPause.jpg"))
        )
        request.httpMethod = "PUT"
        request.httpBody = Data("complete body".utf8)
        let responseTask = Task { try await URLSession.shared.data(for: request) }

        await fulfillment(of: [commitEntered], timeout: 2)
        await service.pause()
        let (healthData, _) = try await URLSession.shared.data(
            from: XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/health"))
        )
        let health = try JSONSerialization.jsonObject(with: healthData) as! [String: Any]
        XCTAssertEqual(health["receiver_state"] as? String, "paused")

        await commitGate.open()
        let (_, response) = try await responseTask.value
        await fulfillment(of: [uploadStored], timeout: 2)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 201)
        XCTAssertEqual(eventRecorder.uploadStores.count, 1)
        XCTAssertEqual(try storedFiles(at: root).map(\.lastPathComponent), ["CommitDuringPause.jpg"])
        let manifest = try await repository.manifest()
        XCTAssertEqual(manifest.count, 1)
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

    func testCancelledPeerRemovesTemporaryFileAndEmitsUploadFailure() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let uploadStarted = expectation(description: "upload started")
        let uploadFailed = expectation(description: "upload failed")
        let eventRecorder = ReceiverEventRecorder()
        let repository = LibraryRepository(rootURL: root)
        let service = ReceiverService(repository: repository, port: 0) { event in
            eventRecorder.append(event)
            if case .uploadStarted = event {
                uploadStarted.fulfill()
            }
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
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                connected.fulfill()
            }
        }
        connection.start(queue: DispatchQueue(label: "ReceiverServiceTests.cancel-client"))
        await fulfillment(of: [connected], timeout: 2)

        let body = Data("partial".utf8)
        let requestHead = [
            "PUT /uploads/Cancelled.jpg HTTP/1.1",
            "Host: 127.0.0.1",
            "Content-Type: image/jpeg",
            "Content-Length: \(body.count + 1_024)",
            "X-Android-Sync-Id: image:cancelled",
            "Connection: close",
        ].joined(separator: "\r\n") + "\r\n\r\n"
        connection.send(
            content: Data(requestHead.utf8) + body,
            completion: .contentProcessed { _ in }
        )

        await fulfillment(of: [uploadStarted], timeout: 2)
        try await waitForIncomingFile(at: root)
        connection.cancel()

        await fulfillment(of: [uploadFailed], timeout: 2)
        XCTAssertEqual(eventRecorder.uploadFailures.count, 1)
        XCTAssertEqual(eventRecorder.uploadFailures.first?.filename, "Cancelled.jpg")
        XCTAssertTrue(try incomingContents(at: root).isEmpty)
        let manifest = try await repository.manifest()
        XCTAssertTrue(manifest.isEmpty)
    }

    func testRepositoryCommitFailureCleansTemporaryFileAndEmitsOneUploadFailure() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let uploadFailed = expectation(description: "upload failed")
        let eventRecorder = ReceiverEventRecorder()
        let repository = LibraryRepository(
            rootURL: root,
            hooks: LibraryRepositoryHooks(
                beforeLogReplace: {
                    throw InjectedReceiverStorageFailure()
                }
            )
        )
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
        XCTAssertTrue(try storedFiles(at: root).isEmpty)
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

    func testStopWaitsForCommitAndEmitsStoredBeforeStopped() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let commitEntered = expectation(description: "repository commit entered")
        let stopRequested = expectation(description: "receiver stop requested")
        let uploadStored = expectation(description: "upload stored")
        let stopped = expectation(description: "receiver stopped")
        let commitGate = AsyncTestGate()
        let eventRecorder = ReceiverEventRecorder()
        let repository = LibraryRepository(
            rootURL: root,
            hooks: LibraryRepositoryHooks(
                afterFileMove: {
                    commitEntered.fulfill()
                    await commitGate.wait()
                }
            )
        )
        let service = ReceiverService(repository: repository, port: 0) { event in
            eventRecorder.append(event)
            if case .uploadStored = event {
                uploadStored.fulfill()
            }
            if case .stopped = event {
                stopped.fulfill()
            }
        }
        let port = try await service.start()

        var request = URLRequest(
            url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/uploads/CommitRace.jpg"))
        )
        request.httpMethod = "PUT"
        request.httpBody = Data("complete body".utf8)
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let responseTask = Task {
            try? await URLSession.shared.data(for: request)
        }

        await fulfillment(of: [commitEntered], timeout: 2)
        service.stop {
            stopRequested.fulfill()
        }
        await fulfillment(of: [stopRequested], timeout: 2)

        XCTAssertTrue(eventRecorder.uploadStores.isEmpty)
        XCTAssertFalse(eventRecorder.containsStopped)
        XCTAssertEqual(try storedFiles(at: root).map(\.lastPathComponent), ["CommitRace.jpg"])

        await commitGate.open()
        await fulfillment(of: [uploadStored, stopped], timeout: 2)
        _ = await responseTask.value

        XCTAssertEqual(eventRecorder.terminalEventNames, ["stored", "stopped"])
        XCTAssertTrue(try incomingContents(at: root).isEmpty)
        XCTAssertEqual(try storedFiles(at: root).map(\.lastPathComponent), ["CommitRace.jpg"])
        let manifest = try await repository.manifest()
        XCTAssertEqual(manifest.map(\.filename), ["CommitRace.jpg"])
    }

    func testStopAndWaitIsIdempotentAndServiceCanRestart() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let eventRecorder = ReceiverEventRecorder()
        let service = ReceiverService(
            repository: LibraryRepository(rootURL: root),
            port: 0,
            eventHandler: eventRecorder.append
        )

        _ = try await service.start()
        await service.stopAndWait()
        XCTAssertEqual(eventRecorder.stoppedCount, 1)

        let repeatedStopCompleted = expectation(description: "repeated stop completed")
        Task {
            await service.stopAndWait()
            repeatedStopCompleted.fulfill()
        }
        await fulfillment(of: [repeatedStopCompleted], timeout: 0.5)
        XCTAssertEqual(eventRecorder.stoppedCount, 1)

        _ = try await service.start()
        await service.stopAndWait()
        XCTAssertEqual(eventRecorder.stoppedCount, 2)
    }

    func testConcurrentStopAndWaitCallsCompleteWithOneStoppedEvent() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let commitEntered = expectation(description: "repository commit entered")
        let commitGate = AsyncTestGate()
        let eventRecorder = ReceiverEventRecorder()
        let service = ReceiverService(
            repository: LibraryRepository(
                rootURL: root,
                hooks: LibraryRepositoryHooks(
                    afterFileMove: {
                        commitEntered.fulfill()
                        await commitGate.wait()
                    }
                )
            ),
            port: 0,
            eventHandler: eventRecorder.append
        )
        let port = try await service.start()

        var request = URLRequest(
            url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/uploads/ConcurrentStop.jpg"))
        )
        request.httpMethod = "PUT"
        request.httpBody = Data("complete body".utf8)
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let responseTask = Task {
            try? await URLSession.shared.data(for: request)
        }
        await fulfillment(of: [commitEntered], timeout: 2)

        let stopRequestsQueued = expectation(description: "stop requests queued")
        stopRequestsQueued.expectedFulfillmentCount = 2
        let stopsCompleted = expectation(description: "concurrent stops completed")
        stopsCompleted.expectedFulfillmentCount = 2

        for _ in 0..<2 {
            Task {
                await service.stopAndWait {
                    stopRequestsQueued.fulfill()
                }
                stopsCompleted.fulfill()
            }
        }

        await fulfillment(of: [stopRequestsQueued], timeout: 0.5)
        XCTAssertFalse(eventRecorder.containsStopped)

        await commitGate.open()
        await fulfillment(of: [stopsCompleted], timeout: 2)
        _ = await responseTask.value

        XCTAssertEqual(eventRecorder.stoppedCount, 1)
    }

    func testStopAndWaitBeforeStartAndAfterStopDoesNotSuspend() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let eventRecorder = ReceiverEventRecorder()
        let service = ReceiverService(
            repository: LibraryRepository(rootURL: root),
            port: 0,
            eventHandler: eventRecorder.append
        )
        let idleStopCompleted = expectation(description: "idle stop completed")
        Task {
            await service.stopAndWait()
            idleStopCompleted.fulfill()
        }
        await fulfillment(of: [idleStopCompleted], timeout: 0.5)
        XCTAssertEqual(eventRecorder.stoppedCount, 0)

        _ = try await service.start()
        await service.stopAndWait()

        let stoppedStopCompleted = expectation(description: "stopped stop completed")
        Task {
            await service.stopAndWait()
            stoppedStopCompleted.fulfill()
        }
        await fulfillment(of: [stoppedStopCompleted], timeout: 0.5)
        XCTAssertEqual(eventRecorder.stoppedCount, 1)
    }

    func testCancelledConnectionLifecycleRejectsPendingReceiveCallbacks() {
        var lifecycle = ReceiverConnectionLifecycle()

        XCTAssertTrue(lifecycle.acceptsNetworkCallbacks)
        XCTAssertEqual(lifecycle.requestStop(), .closeNow)
        XCTAssertFalse(lifecycle.acceptsNetworkCallbacks)
        XCTAssertFalse(lifecycle.beginCommit())
    }

    func testListenerFailureStopsSessionsOnceAndAllowsRestartAfterCleanup() {
        var lifecycle = ReceiverServiceLifecycle()

        XCTAssertTrue(lifecycle.beginStart())
        XCTAssertTrue(lifecycle.beginListenerFailure())
        XCTAssertFalse(lifecycle.beginListenerFailure())
        XCTAssertEqual(
            lifecycle.finishStop(sessionsAreEmpty: false),
            .notReady
        )
        XCTAssertFalse(lifecycle.beginStart())
        XCTAssertEqual(
            lifecycle.finishStop(sessionsAreEmpty: true),
            .finished(emitStopped: false)
        )
        XCTAssertTrue(lifecycle.beginStart())
    }

    func testPauseCompletionIsNotPublishedAfterListenerFailure() {
        var lifecycle = ReceiverServiceLifecycle()

        XCTAssertTrue(lifecycle.beginStart())
        XCTAssertTrue(lifecycle.canPublishPauseCompletion)
        XCTAssertTrue(lifecycle.beginListenerFailure())
        XCTAssertFalse(lifecycle.canPublishPauseCompletion)
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

    private func storedFiles(at root: URL) throws -> [URL] {
        let photosURL = root.appendingPathComponent("photos", isDirectory: true)
        guard FileManager.default.fileExists(atPath: photosURL.path) else {
            return []
        }
        return try FileManager.default.subpathsOfDirectory(atPath: photosURL.path)
            .map { photosURL.appendingPathComponent($0) }
            .filter { url in
                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                return values.isRegularFile == true
                    && !url.lastPathComponent.hasSuffix(".metadata.json")
            }
    }
}

private final class ReceiverEventRecorder: @unchecked Sendable {
    struct UploadFailure {
        let filename: String
        let message: String
    }

    struct UploadInterruption {
        let id: UUID
        let filename: String
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

    var uploadInterruptions: [UploadInterruption] {
        lock.withLock {
            events.compactMap { event in
                guard case let .uploadInterrupted(id, filename) = event else {
                    return nil
                }
                return UploadInterruption(id: id, filename: filename)
            }
        }
    }

    var uploadStartedBatchTotalBytes: [Int64] {
        lock.withLock {
            events.compactMap { event in
                guard case let .uploadStarted(_, _, _, _, _, batchTotalBytes) = event else {
                    return nil
                }
                return batchTotalBytes
            }
        }
    }

    var uploadStores: [UploadRecord] {
        lock.withLock {
            events.compactMap { event in
                guard case let .uploadStored(_, record) = event else {
                    return nil
                }
                return record
            }
        }
    }

    var containsStopped: Bool {
        lock.withLock {
            events.contains { event in
                if case .stopped = event {
                    return true
                }
                return false
            }
        }
    }

    var stoppedCount: Int {
        lock.withLock {
            events.reduce(into: 0) { count, event in
                if case .stopped = event {
                    count += 1
                }
            }
        }
    }

    var terminalEventNames: [String] {
        lock.withLock {
            events.compactMap { event in
                switch event {
                case .uploadStored:
                    return "stored"
                case .uploadFailed:
                    return "failed"
                case .stopped:
                    return "stopped"
                default:
                    return nil
                }
            }
        }
    }

    func append(_ event: ReceiverServiceEvent) {
        lock.withLock {
            events.append(event)
        }
    }
}

private actor AsyncTestGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}

private struct InjectedReceiverStorageFailure: Error {}
