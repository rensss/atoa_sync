import Foundation
import Combine

/// 同步历史管理器 - 记录所有同步操作历史
class SyncHistoryManager: ObservableObject {
    static let shared = SyncHistoryManager()
    
    @Published var history: [SyncHistoryEntry] = []
    
    private let maxHistoryCount = 100
    private let historyFileURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("AtoASync", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        self.historyFileURL = appDirectory.appendingPathComponent("sync_history.json")
        loadHistory()
    }
    
    // MARK: - 添加历史记录
    
    func addEntry(
        deviceName: String,
        deviceSerial: String,
        filesCount: Int,
        totalBytes: Int64,
        targetPath: String,
        status: SyncHistoryStatus,
        duration: TimeInterval,
        errorMessage: String? = nil
    ) {
        let entry = SyncHistoryEntry(
            deviceName: deviceName,
            deviceSerial: deviceSerial,
            filesCount: filesCount,
            totalBytes: totalBytes,
            targetPath: targetPath,
            status: status,
            duration: duration,
            errorMessage: errorMessage
        )
        
        history.insert(entry, at: 0)
        
        // 限制历史记录数量
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        saveHistory()
        
        LogManager.shared.log(
            "添加同步历史: \(deviceName), \(filesCount) 文件, \(status.rawValue)",
            level: .info,
            category: "History"
        )
    }
    
    func addFromTask(_ task: SyncTask, duration: TimeInterval) {
        addEntry(
            deviceName: task.sourceDevice.displayName,
            deviceSerial: task.sourceDevice.serialNumber,
            filesCount: task.processedFiles,
            totalBytes: task.bytesTransferred,
            targetPath: task.targetPath,
            status: task.status == .completed ? .success : (task.status == .cancelled ? .cancelled : .failed),
            duration: duration,
            errorMessage: task.error?.localizedDescription
        )
    }
    
    // MARK: - 查询历史
    
    func getHistory(for deviceSerial: String? = nil, limit: Int? = nil) -> [SyncHistoryEntry] {
        var result = history
        
        if let serial = deviceSerial {
            result = result.filter { $0.deviceSerial == serial }
        }
        
        if let limit = limit {
            result = Array(result.prefix(limit))
        }
        
        return result
    }
    
    func getStatistics() -> SyncStatistics {
        let totalSyncs = history.count
        let successfulSyncs = history.filter { $0.status == .success }.count
        let failedSyncs = history.filter { $0.status == .failed }.count
        let totalFiles = history.reduce(0) { $0 + $1.filesCount }
        let totalBytes = history.reduce(0) { $0 + $1.totalBytes }
        let totalDuration = history.reduce(0) { $0 + $1.duration }
        
        return SyncStatistics(
            totalSyncs: totalSyncs,
            successfulSyncs: successfulSyncs,
            failedSyncs: failedSyncs,
            totalFiles: totalFiles,
            totalBytes: totalBytes,
            totalDuration: totalDuration
        )
    }
    
    // MARK: - 清理历史
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
        LogManager.shared.log("已清除同步历史", level: .info, category: "History")
    }
    
    func clearOldHistory(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        history = history.filter { $0.timestamp > cutoffDate }
        saveHistory()
    }
    
    // MARK: - 持久化
    
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            history = try decoder.decode([SyncHistoryEntry].self, from: data)
        } catch {
            LogManager.shared.log("加载同步历史失败: \(error.localizedDescription)", level: .error, category: "History")
        }
    }
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(history)
            try data.write(to: historyFileURL)
        } catch {
            LogManager.shared.log("保存同步历史失败: \(error.localizedDescription)", level: .error, category: "History")
        }
    }
    
    // MARK: - 导出
    
    func exportHistory() -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let exportURL = tempDirectory.appendingPathComponent("sync_history_\(Date().timeIntervalSince1970).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(history)
            try data.write(to: exportURL)
            return exportURL
        } catch {
            LogManager.shared.log("导出同步历史失败: \(error.localizedDescription)", level: .error, category: "History")
            return nil
        }
    }
}

// MARK: - 同步历史条目

struct SyncHistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let deviceName: String
    let deviceSerial: String
    let filesCount: Int
    let totalBytes: Int64
    let targetPath: String
    let status: SyncHistoryStatus
    let duration: TimeInterval
    let errorMessage: String?
    
    init(
        deviceName: String,
        deviceSerial: String,
        filesCount: Int,
        totalBytes: Int64,
        targetPath: String,
        status: SyncHistoryStatus,
        duration: TimeInterval,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.deviceName = deviceName
        self.deviceSerial = deviceSerial
        self.filesCount = filesCount
        self.totalBytes = totalBytes
        self.targetPath = targetPath
        self.status = status
        self.duration = duration
        self.errorMessage = errorMessage
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes) 分 \(seconds) 秒"
        } else {
            return "\(seconds) 秒"
        }
    }
    
    var formattedBytes: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
}

enum SyncHistoryStatus: String, Codable {
    case success = "成功"
    case failed = "失败"
    case cancelled = "已取消"
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "minus.circle.fill"
        }
    }
}

// MARK: - 同步统计

struct SyncStatistics {
    let totalSyncs: Int
    let successfulSyncs: Int
    let failedSyncs: Int
    let totalFiles: Int
    let totalBytes: Int64
    let totalDuration: TimeInterval
    
    var successRate: Double {
        guard totalSyncs > 0 else { return 0 }
        return Double(successfulSyncs) / Double(totalSyncs) * 100
    }
    
    var formattedTotalBytes: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
    
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分钟"
        } else {
            return "\(minutes) 分钟"
        }
    }
}
