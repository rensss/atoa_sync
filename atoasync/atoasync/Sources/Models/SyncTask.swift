import Foundation
import Combine

class SyncTask: Identifiable, ObservableObject {
    let id: UUID
    @Published var status: SyncStatus
    @Published var progress: Double
    @Published var currentFile: String?
    @Published var processedFiles: Int
    @Published var totalFiles: Int
    @Published var bytesTransferred: Int64
    @Published var totalBytes: Int64
    @Published var speed: Double
    @Published var estimatedTimeRemaining: TimeInterval?
    @Published var error: Error?
    
    let files: [FileInfo]
    let sourceDevice: DeviceInfo
    let targetPath: String
    let conflictResolution: ConflictResolution
    let startTime: Date
    
    init(files: [FileInfo], sourceDevice: DeviceInfo, targetPath: String, conflictResolution: ConflictResolution) {
        self.id = UUID()
        self.status = .pending
        self.progress = 0.0
        self.processedFiles = 0
        self.totalFiles = files.count
        self.bytesTransferred = 0
        self.totalBytes = files.reduce(0) { $0 + $1.size }
        self.speed = 0.0
        self.files = files
        self.sourceDevice = sourceDevice
        self.targetPath = targetPath
        self.conflictResolution = conflictResolution
        self.startTime = Date()
    }
    
    var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    var formattedSpeed: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(speed)))/s"
    }
    
    var formattedTimeRemaining: String {
        guard let time = estimatedTimeRemaining, time.isFinite else {
            return "计算中..."
        }
        
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        if minutes > 0 {
            return "\(minutes) 分 \(seconds) 秒"
        } else {
            return "\(seconds) 秒"
        }
    }
    
    var formattedBytesTransferred: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        let transferred = formatter.string(fromByteCount: bytesTransferred)
        let total = formatter.string(fromByteCount: totalBytes)
        return "\(transferred) / \(total)"
    }
}

enum SyncStatus: String {
    case pending = "等待中"
    case running = "同步中"
    case paused = "已暂停"
    case completed = "已完成"
    case failed = "失败"
    case cancelled = "已取消"
}

enum ConflictResolution: String, CaseIterable, Codable {
    case overwrite = "覆盖"
    case skip = "跳过"
    case rename = "重命名"
    case askEachTime = "每次询问"
    
    var description: String {
        switch self {
        case .overwrite:
            return "覆盖现有文件"
        case .skip:
            return "跳过冲突文件"
        case .rename:
            return "自动重命名新文件"
        case .askEachTime:
            return "每次询问用户"
        }
    }
}
