import Foundation
import AndroidSyncCore
@testable import AndroidSyncMac

enum TestItems {
    static func item(
        kind: UploadKind = .photo,
        receivedAt: Date = Date(),
        sizeBytes: Int64 = 10,
        removed: Bool = false
    ) -> MediaItemEntity {
        let record = UploadRecord(
            id: UUID(),
            filename: "f",
            originalFilename: "f",
            kind: kind,
            sizeBytes: sizeBytes,
            contentType: nil,
            stableID: nil,
            dateModifiedMillis: nil,
            dateTakenMillis: nil,
            dateAddedMillis: nil,
            sourceIP: nil,
            receivedAt: receivedAt,
            fileURL: URL(fileURLWithPath: "/tmp/f"),
            deleted: removed
        )
        return MediaItemEntity(record: record)
    }

    static func record(sizeBytes: Int64 = 10) -> UploadRecord {
        item(sizeBytes: sizeBytes).uploadRecord
    }
}
