import Foundation
import CryptoKit

struct FileInfo: Identifiable, Hashable, Codable {
    let id: UUID
    let path: String
    let relativePath: String
    let size: Int64
    let modified: Date
    var hash: String?
    let isDirectory: Bool
    
    init(path: String, relativePath: String, size: Int64, modified: Date, hash: String? = nil, isDirectory: Bool = false) {
        self.id = UUID()
        self.path = path
        self.relativePath = relativePath
        self.size = size
        self.modified = modified
        self.hash = hash
        self.isDirectory = isDirectory
    }
    
    static func calculateHash(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func calculateHashForLargeFile(at fileURL: URL) throws -> String {
        let bufferSize = 1024 * 1024
        
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            throw FileError.cannotOpenFile
        }
        
        defer {
            try? fileHandle.close()
        }
        
        var hasher = SHA256()
        
        while autoreleasepool(invoking: {
            let data = fileHandle.readData(ofLength: bufferSize)
            if data.count > 0 {
                hasher.update(data: data)
                return true
            } else {
                return false
            }
        }) { }
        
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modified)
    }
}

enum FileError: LocalizedError {
    case cannotOpenFile
    case cannotReadFile
    case hashCalculationFailed
    
    var errorDescription: String? {
        switch self {
        case .cannotOpenFile:
            return "无法打开文件"
        case .cannotReadFile:
            return "无法读取文件"
        case .hashCalculationFailed:
            return "哈希计算失败"
        }
    }
}
