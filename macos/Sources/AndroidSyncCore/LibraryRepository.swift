import Foundation

public enum LibraryRepositoryError: LocalizedError {
    case missingFile
    case invalidLog

    public var errorDescription: String? {
        switch self {
        case .missingFile:
            return "The received file no longer exists."
        case .invalidLog:
            return "The upload log could not be encoded."
        }
    }
}

public enum UploadStorageError: Error, Equatable {
    case sizeMismatch(expected: Int64, actual: Int64)
}

public actor LibraryRepository {
    public typealias TrashHandler = @Sendable (URL) throws -> Void

    public let rootURL: URL
    private let fileManager: FileManager
    private let now: @Sendable () -> Date

    public init(
        rootURL: URL,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.now = now
    }

    public func store(data: Data, metadata: UploadMetadata) throws -> UploadRecord {
        let temporaryURL = try makeTemporaryUploadURL()
        do {
            try data.write(to: temporaryURL)
            return try commitTemporaryUpload(
                at: temporaryURL,
                expectedSize: Int64(data.count),
                metadata: metadata
            )
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    public func makeTemporaryUploadURL() throws -> URL {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let incomingDirectory = rootURL.appendingPathComponent(".incoming", isDirectory: true)
        try fileManager.createDirectory(at: incomingDirectory, withIntermediateDirectories: true)
        return incomingDirectory.appendingPathComponent("\(UUID().uuidString).part")
    }

    public func commitTemporaryUpload(
        at temporaryURL: URL,
        expectedSize: Int64,
        metadata: UploadMetadata
    ) throws -> UploadRecord {
        let values = try temporaryURL.resourceValues(forKeys: [.fileSizeKey])
        let actualSize = Int64(values.fileSize ?? 0)
        guard actualSize == expectedSize else {
            try? fileManager.removeItem(at: temporaryURL)
            throw UploadStorageError.sizeMismatch(expected: expectedSize, actual: actualSize)
        }

        let filename = try FilePolicy.safeFilename(from: metadata.filename)
        let kind = FilePolicy.kind(filename: filename, contentType: metadata.contentType)
        let receivedAt = now()
        let month = Self.monthString(from: receivedAt)
        let targetDirectory = rootURL
            .appendingPathComponent(kind.rawValue, isDirectory: true)
            .appendingPathComponent(month, isDirectory: true)
        try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let targetURL = uniqueURL(for: targetDirectory.appendingPathComponent(filename))
        try fileManager.moveItem(at: temporaryURL, to: targetURL)

        if let millis = metadata.dateModifiedMillis {
            try fileManager.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: TimeInterval(millis) / 1_000)],
                ofItemAtPath: targetURL.path
            )
        }

        let record = UploadRecord(
            filename: targetURL.lastPathComponent,
            originalFilename: filename,
            kind: kind,
            sizeBytes: actualSize,
            contentType: metadata.contentType,
            stableID: metadata.stableID,
            dateModifiedMillis: metadata.dateModifiedMillis,
            dateTakenMillis: metadata.dateTakenMillis,
            dateAddedMillis: metadata.dateAddedMillis,
            sourceIP: metadata.sourceIP,
            receivedAt: receivedAt,
            fileURL: targetURL
        )
        try writeSidecar(for: record)
        try appendLog(for: record, status: "stored")
        return record
    }

    public func rename(_ record: UploadRecord, to rawFilename: String) throws -> UploadRecord {
        guard fileManager.fileExists(atPath: record.fileURL.path) else {
            throw LibraryRepositoryError.missingFile
        }
        let filename = try FilePolicy.safeFilename(from: rawFilename)
        let requestedURL = record.fileURL.deletingLastPathComponent().appendingPathComponent(filename)
        let destinationURL = uniqueURL(for: requestedURL)
        let oldSidecar = sidecarURL(for: record.fileURL)
        let newSidecar = sidecarURL(for: destinationURL)

        try fileManager.moveItem(at: record.fileURL, to: destinationURL)
        if fileManager.fileExists(atPath: oldSidecar.path) {
            try fileManager.moveItem(at: oldSidecar, to: newSidecar)
        }

        let renamed = record.replacing(
            fileURL: destinationURL,
            filename: destinationURL.lastPathComponent
        )
        try writeSidecar(for: renamed)
        try appendLog(for: renamed, status: "stored")
        return renamed
    }

    public func delete(
        _ record: UploadRecord,
        trash: TrashHandler
    ) throws {
        guard fileManager.fileExists(atPath: record.fileURL.path) else {
            throw LibraryRepositoryError.missingFile
        }

        let sidecar = sidecarURL(for: record.fileURL)
        try trash(record.fileURL)
        if fileManager.fileExists(atPath: sidecar.path) {
            try trash(sidecar)
        }
        try appendLog(
            for: record.replacing(
                fileURL: record.fileURL,
                filename: record.filename,
                deleted: true
            ),
            status: "deleted"
        )
    }

    public func manifest() throws -> [ManifestRecord] {
        let logURL = rootURL.appendingPathComponent("uploads.jsonl")
        guard fileManager.fileExists(atPath: logURL.path) else {
            return []
        }
        let contents = try String(contentsOf: logURL, encoding: .utf8)
        var byStableID: [String: ManifestRecord] = [:]
        var fallback: [ManifestRecord] = []

        for line in contents.split(whereSeparator: \.isNewline) {
            guard
                let data = String(line).data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let status = json["status"] as? String,
                status == "stored" || status == "deleted",
                let filename = json["filename"] as? String
            else {
                continue
            }

            let record = ManifestRecord(
                filename: filename,
                kind: json["kind"] as? String,
                sizeBytes: Self.int64(json["size_bytes"]) ?? 0,
                path: json["path"] as? String,
                time: json["time"] as? String,
                stableID: json["stable_id"] as? String,
                dateModifiedMillis: Self.int64(json["date_modified_millis"]),
                dateTakenMillis: Self.int64(json["date_taken_millis"]),
                dateAddedMillis: Self.int64(json["date_added_millis"]),
                contentType: json["content_type"] as? String,
                sourceIP: json["client_ip"] as? String,
                deleted: status == "deleted" || (json["deleted"] as? Bool == true)
            )
            if let stableID = record.stableID, !stableID.isEmpty {
                byStableID[stableID] = record
            } else if !record.deleted {
                fallback.append(record)
            }
        }
        return Array(byStableID.values) + fallback
    }

    public func libraryRecords() throws -> [UploadRecord] {
        try manifest().map { manifestRecord in
            let fileURL = URL(
                fileURLWithPath: manifestRecord.path
                    ?? rootURL.appendingPathComponent(manifestRecord.filename).path
            )
            let sidecar = readSidecar(at: sidecarURL(for: fileURL))
            let kind = UploadKind(rawValue: manifestRecord.kind ?? "")
                ?? FilePolicy.kind(
                    filename: manifestRecord.filename,
                    contentType: sidecar["content_type"] as? String ?? manifestRecord.contentType
                )
            let receivedAt = Self.date(from: manifestRecord.time) ?? .distantPast
            let fileExists = fileManager.fileExists(atPath: fileURL.path)

            return UploadRecord(
                filename: manifestRecord.filename,
                originalFilename: sidecar["original_filename"] as? String
                    ?? manifestRecord.filename,
                kind: kind,
                sizeBytes: manifestRecord.sizeBytes,
                contentType: sidecar["content_type"] as? String ?? manifestRecord.contentType,
                stableID: manifestRecord.stableID,
                dateModifiedMillis: manifestRecord.dateModifiedMillis,
                dateTakenMillis: manifestRecord.dateTakenMillis,
                dateAddedMillis: manifestRecord.dateAddedMillis,
                sourceIP: sidecar["source_ip"] as? String ?? manifestRecord.sourceIP,
                receivedAt: receivedAt,
                fileURL: fileURL,
                deleted: manifestRecord.deleted || !fileExists
            )
        }
        .sorted { $0.receivedAt > $1.receivedAt }
    }

    private func uniqueURL(for requestedURL: URL) -> URL {
        guard fileManager.fileExists(atPath: requestedURL.path) else {
            return requestedURL
        }
        let directory = requestedURL.deletingLastPathComponent()
        let fileExtension = requestedURL.pathExtension
        let stem = requestedURL.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let suffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
            let candidate = directory.appendingPathComponent("\(stem)-\(index)\(suffix)")
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func writeSidecar(for record: UploadRecord) throws {
        var json: [String: Any] = [
            "filename": record.filename,
            "original_filename": record.originalFilename,
            "kind": record.kind.rawValue,
            "size_bytes": record.sizeBytes,
            "path": record.fileURL.path
        ]
        json["content_type"] = record.contentType
        json["stable_id"] = record.stableID
        json["date_modified_millis"] = record.dateModifiedMillis
        json["date_taken_millis"] = record.dateTakenMillis
        json["date_added_millis"] = record.dateAddedMillis
        json["source_ip"] = record.sourceIP
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: sidecarURL(for: record.fileURL), options: .atomic)
    }

    private func appendLog(for record: UploadRecord, status: String) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        var json: [String: Any] = [
            "time": Self.timestampString(from: record.receivedAt),
            "filename": record.filename,
            "kind": record.kind.rawValue,
            "size_bytes": record.sizeBytes,
            "status": status,
            "path": record.fileURL.path
        ]
        json["client_ip"] = record.sourceIP
        json["content_type"] = record.contentType
        json["stable_id"] = record.stableID
        json["date_modified_millis"] = record.dateModifiedMillis
        json["date_taken_millis"] = record.dateTakenMillis
        json["date_added_millis"] = record.dateAddedMillis
        if record.deleted {
            json["deleted"] = true
        }
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        guard var line = String(data: data, encoding: .utf8) else {
            throw LibraryRepositoryError.invalidLog
        }
        line.append("\n")

        let logURL = rootURL.appendingPathComponent("uploads.jsonl")
        if !fileManager.fileExists(atPath: logURL.path) {
            try Data().write(to: logURL)
        }
        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.utf8))
        try handle.close()
    }

    private func sidecarURL(for fileURL: URL) -> URL {
        fileURL.appendingPathExtension("metadata.json")
    }

    private func readSidecar(at url: URL) -> [String: Any] {
        guard
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return json
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let string = value as? String {
            return Int64(string)
        }
        return nil
    }

    private static func monthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func date(from text: String?) -> Date? {
        guard let text else { return nil }
        if let date = ISO8601DateFormatter().date(from: text) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: text)
    }
}
