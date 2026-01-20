import Foundation

import Foundation
import Combine

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [LogEntry] = []
    
    private let maxLogs = 1000
    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.atoa.sync.logger", qos: .utility)
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("AtoASync", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        self.logFileURL = appDirectory.appendingPathComponent("logs.txt")
    }
    
    func log(_ message: String, level: LogLevel = .info, category: String = "General") {
        let entry = LogEntry(message: message, level: level, category: category)
        
        Task { @MainActor in
            self.logs.append(entry)
            
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
        }
        
        queue.async {
            self.writeToFile(entry: entry)
        }
        
        #if DEBUG
        print("[\(Date.now)] [\(level.rawValue)] [\(category)] \(message)")
        #endif
    }
    
    private func writeToFile(entry: LogEntry) {
        let logString = entry.formattedString + "\n"
        
        guard let data = logString.data(using: .utf8) else {
            return
        }
        
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: logFileURL)
        }
    }
    
    func clearLogs() {
        Task { @MainActor in
            self.logs.removeAll()
        }
        
        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func exportLogs() -> URL? {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else {
            return nil
        }
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let exportURL = tempDirectory.appendingPathComponent("atoa_sync_logs_\(Date().timeIntervalSince1970).txt")
        
        try? FileManager.default.copyItem(at: logFileURL, to: exportURL)
        
        return exportURL
    }
    
    func filterLogs(by level: LogLevel? = nil, category: String? = nil, searchText: String? = nil) -> [LogEntry] {
        var filtered = logs
        
        if let level = level {
            filtered = filtered.filter { $0.level == level }
        }
        
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }
        
        if let searchText = searchText, !searchText.isEmpty {
            filtered = filtered.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel
    let category: String
    
    init(message: String, level: LogLevel, category: String) {
        self.timestamp = Date()
        self.message = message
        self.level = level
        self.category = category
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    var formattedString: String {
        return "[\(formattedTimestamp)] [\(level.rawValue)] [\(category)] \(message)"
    }
}

enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var icon: String {
        switch self {
        case .debug:
            return "ant.circle"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .critical:
            return "exclamationmark.octagon"
        }
    }
}
