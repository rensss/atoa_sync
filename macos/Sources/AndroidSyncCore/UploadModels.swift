import Foundation

public struct UploadMetadata: Equatable, Sendable {
    public let filename: String
    public let contentType: String?
    public let stableID: String?
    public let dateModifiedMillis: Int64?
    public let dateTakenMillis: Int64?
    public let dateAddedMillis: Int64?
    public let sourceIP: String?

    public init(
        filename: String,
        contentType: String? = nil,
        stableID: String? = nil,
        dateModifiedMillis: Int64? = nil,
        dateTakenMillis: Int64? = nil,
        dateAddedMillis: Int64? = nil,
        sourceIP: String? = nil
    ) {
        self.filename = filename
        self.contentType = contentType
        self.stableID = stableID
        self.dateModifiedMillis = dateModifiedMillis
        self.dateTakenMillis = dateTakenMillis
        self.dateAddedMillis = dateAddedMillis
        self.sourceIP = sourceIP
    }
}

public struct UploadRecord: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let filename: String
    public let originalFilename: String
    public let kind: UploadKind
    public let sizeBytes: Int64
    public let contentType: String?
    public let stableID: String?
    public let dateModifiedMillis: Int64?
    public let dateTakenMillis: Int64?
    public let dateAddedMillis: Int64?
    public let sourceIP: String?
    public let receivedAt: Date
    public let fileURL: URL
    public let deleted: Bool

    public init(
        id: UUID = UUID(),
        filename: String,
        originalFilename: String,
        kind: UploadKind,
        sizeBytes: Int64,
        contentType: String?,
        stableID: String?,
        dateModifiedMillis: Int64?,
        dateTakenMillis: Int64?,
        dateAddedMillis: Int64?,
        sourceIP: String?,
        receivedAt: Date,
        fileURL: URL,
        deleted: Bool = false
    ) {
        self.id = id
        self.filename = filename
        self.originalFilename = originalFilename
        self.kind = kind
        self.sizeBytes = sizeBytes
        self.contentType = contentType
        self.stableID = stableID
        self.dateModifiedMillis = dateModifiedMillis
        self.dateTakenMillis = dateTakenMillis
        self.dateAddedMillis = dateAddedMillis
        self.sourceIP = sourceIP
        self.receivedAt = receivedAt
        self.fileURL = fileURL
        self.deleted = deleted
    }

    func replacing(fileURL: URL, filename: String, deleted: Bool? = nil) -> UploadRecord {
        UploadRecord(
            id: id,
            filename: filename,
            originalFilename: originalFilename,
            kind: kind,
            sizeBytes: sizeBytes,
            contentType: contentType,
            stableID: stableID,
            dateModifiedMillis: dateModifiedMillis,
            dateTakenMillis: dateTakenMillis,
            dateAddedMillis: dateAddedMillis,
            sourceIP: sourceIP,
            receivedAt: receivedAt,
            fileURL: fileURL,
            deleted: deleted ?? self.deleted
        )
    }
}

public struct ManifestRecord: Codable, Hashable, Sendable {
    public let filename: String
    public let kind: String?
    public let sizeBytes: Int64
    public let path: String?
    public let time: String?
    public let stableID: String?
    public let dateModifiedMillis: Int64?
    public let dateTakenMillis: Int64?
    public let dateAddedMillis: Int64?
    public let contentType: String?
    public let sourceIP: String?
    public let deleted: Bool

    enum CodingKeys: String, CodingKey {
        case filename
        case kind
        case sizeBytes = "size_bytes"
        case path
        case time
        case stableID = "stable_id"
        case dateModifiedMillis = "date_modified_millis"
        case dateTakenMillis = "date_taken_millis"
        case dateAddedMillis = "date_added_millis"
        case contentType = "content_type"
        case sourceIP = "client_ip"
        case deleted
    }
}
