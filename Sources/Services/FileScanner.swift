import Foundation

class FileScanner {
    static let shared = FileScanner()
    
    private let queue = DispatchQueue(label: "com.atoa.sync.scanner", qos: .userInitiated)
    private let fileManager = FileManager.default
    
    private init() {}
    
    func scanLocalDirectory(at path: String, calculateHash: Bool = false, progressHandler: ((Int) -> Void)? = nil) async throws -> [FileInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    var files: [FileInfo] = []
                    let baseURL = URL(fileURLWithPath: path)
                    
                    guard let enumerator = self.fileManager.enumerator(
                        at: baseURL,
                        includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else {
                        continuation.resume(throwing: ScanError.cannotAccessDirectory)
                        return
                    }
                    
                    var processedCount = 0
                    
                    for case let fileURL as URL in enumerator {
                        do {
                            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                            
                            let isDirectory = resourceValues.isDirectory ?? false
                            
                            if !isDirectory {
                                let size = Int64(resourceValues.fileSize ?? 0)
                                let modified = resourceValues.contentModificationDate ?? Date()
                                let relativePath = fileURL.path.replacingOccurrences(of: baseURL.path, with: "")
                                
                                var hash: String?
                                if calculateHash {
                                    hash = try? self.calculateHash(for: fileURL, size: size)
                                }
                                
                                let fileInfo = FileInfo(
                                    path: fileURL.path,
                                    relativePath: relativePath,
                                    size: size,
                                    modified: modified,
                                    hash: hash,
                                    isDirectory: false
                                )
                                
                                files.append(fileInfo)
                                
                                processedCount += 1
                                if processedCount % 100 == 0 {
                                    DispatchQueue.main.async {
                                        progressHandler?(processedCount)
                                    }
                                }
                            }
                        } catch {
                            continue
                        }
                    }
                    
                    continuation.resume(returning: files)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func scanAndroidDevice(serialNumber: String, path: String, progressHandler: ((Int) -> Void)? = nil) async throws -> [FileInfo] {
        return try await ADBManager.shared.listFiles(serialNumber: serialNumber, path: path)
    }
    
    private func calculateHash(for fileURL: URL, size: Int64) throws -> String {
        if size > 100 * 1024 * 1024 {
            return try FileInfo.calculateHashForLargeFile(at: fileURL)
        } else {
            return try FileInfo.calculateHash(for: fileURL)
        }
    }
    
    func getFileAttributes(at path: String) throws -> FileInfo {
        let url = URL(fileURLWithPath: path)
        let attributes = try fileManager.attributesOfItem(atPath: path)
        
        let size = attributes[.size] as? Int64 ?? 0
        let modified = attributes[.modificationDate] as? Date ?? Date()
        let isDirectory = attributes[.type] as? FileAttributeType == .typeDirectory
        
        return FileInfo(
            path: path,
            relativePath: url.lastPathComponent,
            size: size,
            modified: modified,
            isDirectory: isDirectory
        )
    }
    
    func filterFiles(_ files: [FileInfo], by searchText: String) -> [FileInfo] {
        guard !searchText.isEmpty else {
            return files
        }
        
        return files.filter { file in
            file.relativePath.localizedCaseInsensitiveContains(searchText) ||
            file.path.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func filterFiles(_ files: [FileInfo], by fileTypes: Set<FileType>) -> [FileInfo] {
        guard !fileTypes.isEmpty else {
            return files
        }
        
        return files.filter { file in
            fileTypes.contains(FileType.from(path: file.path))
        }
    }
    
    func groupFilesByDirectory(_ files: [FileInfo]) -> [String: [FileInfo]] {
        var grouped: [String: [FileInfo]] = [:]
        
        for file in files {
            let directory = (file.relativePath as NSString).deletingLastPathComponent
            if grouped[directory] == nil {
                grouped[directory] = []
            }
            grouped[directory]?.append(file)
        }
        
        return grouped
    }
}

enum FileType: String, CaseIterable {
    case image = "图片"
    case video = "视频"
    case audio = "音频"
    case document = "文档"
    case archive = "压缩文件"
    case code = "代码"
    case other = "其他"
    
    static func from(path: String) -> FileType {
        let ext = (path as NSString).pathExtension.lowercased()
        
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "heic", "webp", "svg":
            return .image
        case "mp4", "mov", "avi", "mkv", "flv", "wmv", "m4v":
            return .video
        case "mp3", "m4a", "wav", "flac", "aac", "ogg", "wma":
            return .audio
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf":
            return .document
        case "zip", "rar", "7z", "tar", "gz", "bz2":
            return .archive
        case "swift", "java", "py", "js", "ts", "cpp", "c", "h", "html", "css", "xml", "json":
            return .code
        default:
            return .other
        }
    }
    
    var icon: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        case .document:
            return "doc.text"
        case .archive:
            return "archivebox"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .other:
            return "doc"
        }
    }
}

enum ScanError: LocalizedError {
    case cannotAccessDirectory
    case permissionDenied
    case deviceNotConnected
    
    var errorDescription: String? {
        switch self {
        case .cannotAccessDirectory:
            return "无法访问目录"
        case .permissionDenied:
            return "权限被拒绝"
        case .deviceNotConnected:
            return "设备未连接"
        }
    }
}
