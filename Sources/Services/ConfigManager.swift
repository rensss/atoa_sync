import Foundation

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var config: AppConfig
    
    private let configFileURL: URL
    private let cacheFileURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("AtoASync", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        self.configFileURL = appDirectory.appendingPathComponent("config.json")
        self.cacheFileURL = appDirectory.appendingPathComponent("cache.json")
        
        if let loadedConfig = Self.loadConfig(from: configFileURL) {
            self.config = loadedConfig
        } else {
            self.config = AppConfig()
        }
    }
    
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: configFileURL)
        } catch {
            LogManager.shared.log("保存配置失败: \(error.localizedDescription)", level: .error)
        }
    }
    
    private static func loadConfig(from url: URL) -> AppConfig? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            LogManager.shared.log("加载配置失败: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
    
    func saveCache(_ cache: SyncCache) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(cache)
            try data.write(to: cacheFileURL)
        } catch {
            LogManager.shared.log("保存缓存失败: \(error.localizedDescription)", level: .error)
        }
    }
    
    func loadCache() -> SyncCache? {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(SyncCache.self, from: data)
        } catch {
            LogManager.shared.log("加载缓存失败: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
    
    func updateLastSyncPath(_ path: String, for deviceSerial: String) {
        config.lastSyncPaths[deviceSerial] = path
        save()
    }
    
    func getLastSyncPath(for deviceSerial: String) -> String? {
        return config.lastSyncPaths[deviceSerial]
    }
}

struct AppConfig: Codable {
    var defaultTargetPath: String
    var conflictResolution: ConflictResolution
    var enableHashComparison: Bool
    var maxConcurrentTransfers: Int
    var lastSyncPaths: [String: String]
    var autoScanOnConnect: Bool
    var showHiddenFiles: Bool
    
    init() {
        self.defaultTargetPath = FileManager.default.homeDirectoryForCurrentUser.path
        self.conflictResolution = .askEachTime
        self.enableHashComparison = false
        self.maxConcurrentTransfers = 3
        self.lastSyncPaths = [:]
        self.autoScanOnConnect = true
        self.showHiddenFiles = false
    }
}

struct SyncCache: Codable {
    var deviceCaches: [String: DeviceCache]
    var lastUpdated: Date
    
    init() {
        self.deviceCaches = [:]
        self.lastUpdated = Date()
    }
}

struct DeviceCache: Codable {
    let deviceSerial: String
    var files: [String: CachedFileInfo]
    var lastSyncDate: Date
    
    init(deviceSerial: String) {
        self.deviceSerial = deviceSerial
        self.files = [:]
        self.lastSyncDate = Date()
    }
}

struct CachedFileInfo: Codable {
    let path: String
    let size: Int64
    let modified: Date
    let hash: String?
    
    init(from fileInfo: FileInfo) {
        self.path = fileInfo.path
        self.size = fileInfo.size
        self.modified = fileInfo.modified
        self.hash = fileInfo.hash
    }
    
    func toFileInfo(relativePath: String) -> FileInfo {
        return FileInfo(
            path: path,
            relativePath: relativePath,
            size: size,
            modified: modified,
            hash: hash
        )
    }
}
