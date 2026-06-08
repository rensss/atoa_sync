import Darwin
import Foundation
import Network

public enum ReceiverServiceEvent: Sendable {
    case started(port: UInt16)
    case stopped
    case uploadStarted(filename: String, expectedSize: Int64)
    case uploadStored(UploadRecord)
    case failed(message: String)
}

public enum ReceiverServiceError: LocalizedError {
    case unavailablePort

    public var errorDescription: String? {
        "The receiver could not determine its listening port."
    }
}

public final class ReceiverService: @unchecked Sendable {
    public typealias EventHandler = @Sendable (ReceiverServiceEvent) -> Void

    private let repository: LibraryRepository
    private let requestedPort: UInt16
    private let eventHandler: EventHandler
    private let queue = DispatchQueue(label: "com.androidsync.receiver", qos: .userInitiated)
    private var listener: NWListener?
    private var startContinuation: CheckedContinuation<UInt16, Error>?
    private var activeConnections = 0
    private var sessions: [UUID: ReceiverConnection] = [:]

    public init(
        repository: LibraryRepository,
        port: UInt16 = 8765,
        eventHandler: @escaping EventHandler = { _ in }
    ) {
        self.repository = repository
        self.requestedPort = port
        self.eventHandler = eventHandler
    }

    public func start() async throws -> UInt16 {
        let port = requestedPort == 0
            ? NWEndpoint.Port.any
            : NWEndpoint.Port(rawValue: requestedPort)!
        let listener = try NWListener(using: .tcp, on: port)
        self.listener = listener

        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.startContinuation = continuation
                listener.stateUpdateHandler = { [weak self] state in
                    self?.handle(listenerState: state)
                }
                listener.newConnectionHandler = { [weak self] connection in
                    self?.accept(connection)
                }
                listener.start(queue: self.queue)
            }
        }
    }

    public func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
            self.eventHandler(.stopped)
        }
    }

    public var uploadURL: String {
        let port = listener?.port?.rawValue ?? requestedPort
        return "http://\(SystemNetworkInfo.localIPv4Address()):\(port)/uploads/"
    }

    private func handle(listenerState state: NWListener.State) {
        switch state {
        case .ready:
            guard let port = listener?.port?.rawValue else {
                startContinuation?.resume(throwing: ReceiverServiceError.unavailablePort)
                startContinuation = nil
                return
            }
            startContinuation?.resume(returning: port)
            startContinuation = nil
            eventHandler(.started(port: port))
        case let .failed(error):
            startContinuation?.resume(throwing: error)
            startContinuation = nil
            eventHandler(.failed(message: error.localizedDescription))
        case .cancelled:
            startContinuation?.resume(throwing: CancellationError())
            startContinuation = nil
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        guard activeConnections < 4 else {
            let response = try? HTTPResponse.json(
                status: 503,
                reason: "Service Unavailable",
                object: ["error": "too many concurrent uploads"]
            )
            connection.start(queue: queue)
            connection.send(
                content: response?.encoded(),
                completion: .contentProcessed { _ in connection.cancel() }
            )
            return
        }
        activeConnections += 1
        let sessionID = UUID()
        let session = ReceiverConnection(
            connection: connection,
            repository: repository,
            queue: queue,
            uploadURL: { [weak self] in self?.uploadURL ?? "" },
            eventHandler: eventHandler,
            onClose: { [weak self] in
                guard let self else { return }
                self.activeConnections = max(0, self.activeConnections - 1)
                self.sessions.removeValue(forKey: sessionID)
            }
        )
        sessions[sessionID] = session
        session.start()
    }
}

private final class ReceiverConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let repository: LibraryRepository
    private let queue: DispatchQueue
    private let uploadURL: @Sendable () -> String
    private let eventHandler: ReceiverService.EventHandler
    private let onClose: @Sendable () -> Void

    private var buffer = Data()
    private var remainingBytes: Int64 = 0
    private var expectedSize: Int64 = 0
    private var uploadMetadata: UploadMetadata?
    private var temporaryURL: URL?
    private var fileHandle: FileHandle?
    private var closed = false

    init(
        connection: NWConnection,
        repository: LibraryRepository,
        queue: DispatchQueue,
        uploadURL: @escaping @Sendable () -> String,
        eventHandler: @escaping ReceiverService.EventHandler,
        onClose: @escaping @Sendable () -> Void
    ) {
        self.connection = connection
        self.repository = repository
        self.queue = queue
        self.uploadURL = uploadURL
        self.eventHandler = eventHandler
        self.onClose = onClose
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            if case let .failed(error) = state {
                self?.fail(status: 500, reason: "Connection Failed", message: error.localizedDescription)
            }
        }
        connection.start(queue: queue)
        receiveHeaders()
    }

    private func receiveHeaders() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1_024) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                self.buffer.append(data)
            }
            if let error {
                self.fail(status: 400, reason: "Bad Request", message: error.localizedDescription)
                return
            }
            do {
                guard let head = try HTTPRequestParser.extractHead(from: &self.buffer) else {
                    if isComplete {
                        self.fail(status: 400, reason: "Bad Request", message: "incomplete request headers")
                    } else {
                        self.receiveHeaders()
                    }
                    return
                }
                try self.handle(head)
            } catch let error as HTTPRouteError {
                self.respond(to: error)
            } catch {
                self.fail(status: 400, reason: "Bad Request", message: error.localizedDescription)
            }
        }
    }

    private func handle(_ head: HTTPRequestHead) throws {
        let sourceIP = Self.sourceIP(from: connection.endpoint)
        switch try ReceiverRouter.route(head, sourceIP: sourceIP) {
        case .root:
            sendJSON(
                status: 200,
                reason: "OK",
                object: [
                    "service": "Android Sync Receiver",
                    "status": "ok",
                    "upload_url": uploadURL()
                ]
            )
        case .health:
            sendJSON(status: 200, reason: "OK", object: ["status": "ok"])
        case .manifest:
            Task {
                do {
                    let records = try await repository.manifest()
                    queue.async {
                        do {
                            let encoded = try JSONEncoder().encode(records)
                            let uploads = try JSONSerialization.jsonObject(with: encoded)
                            self.sendJSON(
                                status: 200,
                                reason: "OK",
                                object: ["count": records.count, "uploads": uploads]
                            )
                        } catch {
                            self.fail(
                                status: 500,
                                reason: "Internal Server Error",
                                message: error.localizedDescription
                            )
                        }
                    }
                } catch {
                    queue.async {
                        self.fail(status: 500, reason: "Internal Server Error", message: error.localizedDescription)
                    }
                }
            }
        case let .upload(expectedSize, metadata):
            self.expectedSize = expectedSize
            remainingBytes = expectedSize
            uploadMetadata = metadata
            eventHandler(.uploadStarted(filename: metadata.filename, expectedSize: expectedSize))
            prepareUpload()
        case .notFound:
            fail(status: 404, reason: "Not Found", message: "not found")
        }
    }

    private func prepareUpload() {
        Task {
            do {
                let url = try await repository.makeTemporaryUploadURL()
                _ = FileManager.default.createFile(atPath: url.path, contents: nil)
                let handle = try FileHandle(forWritingTo: url)
                queue.async {
                    self.temporaryURL = url
                    self.fileHandle = handle
                    self.consumeBody(self.buffer, connectionComplete: false)
                    self.buffer.removeAll(keepingCapacity: false)
                }
            } catch {
                queue.async {
                    self.fail(status: 507, reason: "Insufficient Storage", message: error.localizedDescription)
                }
            }
        }
    }

    private func receiveBody() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1_024) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                self.fail(status: 500, reason: "Upload Failed", message: error.localizedDescription)
                return
            }
            self.consumeBody(data ?? Data(), connectionComplete: isComplete)
        }
    }

    private func consumeBody(_ data: Data, connectionComplete: Bool) {
        guard remainingBytes > 0 else {
            finishUpload()
            return
        }
        let writableCount = min(data.count, Int(remainingBytes))
        if writableCount > 0 {
            do {
                try fileHandle?.write(contentsOf: data.prefix(writableCount))
                remainingBytes -= Int64(writableCount)
            } catch {
                fail(status: 507, reason: "Insufficient Storage", message: error.localizedDescription)
                return
            }
        }
        if remainingBytes == 0 {
            finishUpload()
        } else if connectionComplete {
            fail(status: 400, reason: "Bad Request", message: "upload body ended early")
        } else {
            receiveBody()
        }
    }

    private func finishUpload() {
        guard
            let temporaryURL,
            let metadata = uploadMetadata
        else {
            fail(status: 500, reason: "Internal Server Error", message: "upload state is incomplete")
            return
        }
        do {
            try fileHandle?.close()
        } catch {
            fail(status: 500, reason: "Upload Failed", message: error.localizedDescription)
            return
        }
        fileHandle = nil

        Task {
            do {
                let record = try await repository.commitTemporaryUpload(
                    at: temporaryURL,
                    expectedSize: expectedSize,
                    metadata: metadata
                )
                queue.async {
                    self.eventHandler(.uploadStored(record))
                    self.sendJSON(
                        status: 201,
                        reason: "Created",
                        object: [
                            "status": "stored",
                            "filename": record.filename,
                            "kind": record.kind.rawValue,
                            "size_bytes": record.sizeBytes,
                            "path": record.fileURL.path,
                            "metadata_path": record.fileURL.appendingPathExtension("metadata.json").path
                        ]
                    )
                }
            } catch {
                queue.async {
                    self.fail(status: 500, reason: "Upload Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func respond(to error: HTTPRouteError) {
        switch error {
        case .forbiddenSource:
            fail(status: 403, reason: "Forbidden", message: "source address is not on a trusted local network")
        case .lengthRequired:
            fail(status: 411, reason: "Length Required", message: "Content-Length is required")
        case .invalidLength, .invalidFilename:
            fail(status: 400, reason: "Bad Request", message: "invalid upload request")
        case .unsupportedTransferEncoding:
            fail(status: 501, reason: "Not Implemented", message: "chunked uploads are not supported")
        }
    }

    private func sendJSON(status: Int, reason: String, object: Any) {
        do {
            send(try HTTPResponse.json(status: status, reason: reason, object: object))
        } catch {
            close()
        }
    }

    private func fail(status: Int, reason: String, message: String) {
        eventHandler(.failed(message: message))
        cleanupTemporaryFile()
        sendJSON(status: status, reason: reason, object: ["error": message])
    }

    private func send(_ response: HTTPResponse) {
        connection.send(content: response.encoded(), completion: .contentProcessed { [weak self] _ in
            self?.close()
        })
    }

    private func cleanupTemporaryFile() {
        try? fileHandle?.close()
        fileHandle = nil
        if let temporaryURL {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
        temporaryURL = nil
    }

    private func close() {
        guard !closed else { return }
        closed = true
        connection.cancel()
        onClose()
    }

    private static func sourceIP(from endpoint: NWEndpoint) -> String {
        if case let .hostPort(host, _) = endpoint {
            return String(describing: host)
        }
        return ""
    }
}

public enum SystemNetworkInfo {
    public static func localIPv4Address() -> String {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return "127.0.0.1"
        }
        defer { freeifaddrs(interfaces) }

        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = current {
            defer { current = interface.pointee.ifa_next }
            let address = interface.pointee.ifa_addr.pointee
            guard address.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.pointee.ifa_name)
            guard name != "lo0" else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                interface.pointee.ifa_addr,
                socklen_t(address.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                let bytes = host
                    .prefix { $0 != 0 }
                    .map { UInt8(bitPattern: $0) }
                return String(decoding: bytes, as: UTF8.self)
            }
        }
        return "127.0.0.1"
    }
}
