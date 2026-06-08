import AndroidSyncCore
import Foundation
import SwiftData

@Model
final class MediaItemEntity {
    @Attribute(.unique) var id: UUID
    var filename: String
    var originalFilename: String
    var kindRaw: String
    var sizeBytes: Int64
    var contentType: String?
    var stableID: String?
    var dateModifiedMillis: Int64?
    var dateTakenMillis: Int64?
    var dateAddedMillis: Int64?
    var sourceIP: String?
    var receivedAt: Date
    var filePath: String
    var deleted: Bool

    init(id: UUID = UUID(), record: UploadRecord) {
        self.id = id
        filename = record.filename
        originalFilename = record.originalFilename
        kindRaw = record.kind.rawValue
        sizeBytes = record.sizeBytes
        contentType = record.contentType
        stableID = record.stableID
        dateModifiedMillis = record.dateModifiedMillis
        dateTakenMillis = record.dateTakenMillis
        dateAddedMillis = record.dateAddedMillis
        sourceIP = record.sourceIP
        receivedAt = record.receivedAt
        filePath = record.fileURL.path
        deleted = record.deleted
    }

    var kind: UploadKind {
        UploadKind(rawValue: kindRaw) ?? .file
    }

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    var uploadRecord: UploadRecord {
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
            deleted: deleted
        )
    }

    func update(from record: UploadRecord) {
        filename = record.filename
        originalFilename = record.originalFilename
        kindRaw = record.kind.rawValue
        sizeBytes = record.sizeBytes
        contentType = record.contentType
        stableID = record.stableID
        dateModifiedMillis = record.dateModifiedMillis
        dateTakenMillis = record.dateTakenMillis
        dateAddedMillis = record.dateAddedMillis
        sourceIP = record.sourceIP
        receivedAt = record.receivedAt
        filePath = record.fileURL.path
        deleted = record.deleted
    }
}
