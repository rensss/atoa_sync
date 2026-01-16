import Foundation
import Combine

/// Wi-Fi 连接管理器 - 通过 HTTP/FTP 连接安卓设备
class WiFiManager: ObservableObject {
    static let shared = WiFiManager()
    
    @Published var connectedDevices: [WiFiDeviceInfo] = []
    @Published var isScanning: Bool = false
    
    private var urlSession: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - 设备发现与连接
    
    /// 连接到 Wi-Fi 设备
    func connect(host: String, port: Int = 8080, protocol: WiFiProtocol = .http) async throws -> WiFiDeviceInfo {
        let baseURL = "\(`protocol`.scheme)://\(host):\(port)"
        
        // 验证连接
        let infoURL = URL(string: "\(baseURL)/device/info")!
        let (data, response) = try await urlSession.data(from: infoURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WiFiError.connectionFailed
        }
        
        // 解析设备信息
        let decoder = JSONDecoder()
        let deviceResponse = try decoder.decode(WiFiDeviceResponse.self, from: data)
        
        let device = WiFiDeviceInfo(
            id: UUID(),
            host: host,
            port: port,
            protocol: `protocol`,
            name: deviceResponse.name,
            model: deviceResponse.model,
            androidVersion: deviceResponse.androidVersion,
            isConnected: true
        )
        
        await MainActor.run {
            if !connectedDevices.contains(where: { $0.host == host && $0.port == port }) {
                connectedDevices.append(device)
            }
        }
        
        LogManager.shared.log("Wi-Fi 设备已连接: \(device.displayName) (\(host):\(port))", level: .info, category: "WiFi")
        
        return device
    }
    
    /// 断开设备连接
    func disconnect(device: WiFiDeviceInfo) {
        Task { @MainActor in
            connectedDevices.removeAll { $0.id == device.id }
        }
        LogManager.shared.log("Wi-Fi 设备已断开: \(device.displayName)", level: .info, category: "WiFi")
    }
    
    // MARK: - 文件操作
    
    /// 获取文件列表
    func listFiles(device: WiFiDeviceInfo, path: String) async throws -> [FileInfo] {
        let baseURL = "\(device.protocol.scheme)://\(device.host):\(device.port)"
        
        var components = URLComponents(string: "\(baseURL)/files/list")!
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        
        let (data, response) = try await urlSession.data(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WiFiError.requestFailed
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let fileListResponse = try decoder.decode(WiFiFileListResponse.self, from: data)
        
        return fileListResponse.files.map { entry in
            FileInfo(
                path: entry.path,
                relativePath: entry.relativePath,
                size: entry.size,
                modified: entry.modified,
                hash: entry.hash,
                isDirectory: entry.isDirectory
            )
        }
    }
    
    /// 下载文件
    func downloadFile(
        device: WiFiDeviceInfo,
        remotePath: String,
        localPath: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        let baseURL = "\(device.protocol.scheme)://\(device.host):\(device.port)"
        
        var components = URLComponents(string: "\(baseURL)/files/download")!
        components.queryItems = [URLQueryItem(name: "path", value: remotePath)]
        
        let (tempURL, response) = try await urlSession.download(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WiFiError.downloadFailed
        }
        
        // 创建目标目录
        let localURL = URL(fileURLWithPath: localPath)
        let directory = localURL.deletingLastPathComponent()
        
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        // 移动文件到目标位置
        if FileManager.default.fileExists(atPath: localPath) {
            try FileManager.default.removeItem(atPath: localPath)
        }
        
        try FileManager.default.moveItem(at: tempURL, to: localURL)
    }
    
    /// 批量下载文件（带进度）
    func downloadFiles(
        device: WiFiDeviceInfo,
        files: [FileInfo],
        targetBasePath: String,
        progressHandler: ((Int, Int, String) -> Void)? = nil
    ) async throws {
        for (index, file) in files.enumerated() {
            let localPath = URL(fileURLWithPath: targetBasePath)
                .appendingPathComponent(file.relativePath)
                .path
            
            progressHandler?(index + 1, files.count, file.relativePath)
            
            try await downloadFile(
                device: device,
                remotePath: file.path,
                localPath: localPath
            )
        }
    }
    
    // MARK: - FTP 支持
    
    /// 通过 FTP 下载文件
    func downloadViaFTP(
        host: String,
        port: Int,
        username: String?,
        password: String?,
        remotePath: String,
        localPath: String
    ) async throws {
        var ftpURL = "ftp://"
        
        if let username = username, let password = password {
            ftpURL += "\(username):\(password)@"
        }
        
        ftpURL += "\(host):\(port)\(remotePath)"
        
        guard let url = URL(string: ftpURL) else {
            throw WiFiError.invalidURL
        }
        
        let (tempURL, _) = try await urlSession.download(from: url)
        
        let localURL = URL(fileURLWithPath: localPath)
        let directory = localURL.deletingLastPathComponent()
        
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        if FileManager.default.fileExists(atPath: localPath) {
            try FileManager.default.removeItem(atPath: localPath)
        }
        
        try FileManager.default.moveItem(at: tempURL, to: localURL)
    }
}

// MARK: - Wi-Fi 数据模型

struct WiFiDeviceInfo: Identifiable, Equatable {
    let id: UUID
    let host: String
    let port: Int
    let `protocol`: WiFiProtocol
    let name: String
    let model: String
    let androidVersion: String
    var isConnected: Bool
    
    var displayName: String {
        return name.isEmpty ? model : name
    }
    
    var connectionString: String {
        return "\(host):\(port)"
    }
    
    func toDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            serialNumber: "\(host):\(port)",
            name: name,
            model: model,
            androidVersion: androidVersion,
            isConnected: isConnected,
            connectionType: .wifi
        )
    }
}

enum WiFiProtocol: String, CaseIterable {
    case http = "HTTP"
    case https = "HTTPS"
    case ftp = "FTP"
    
    var scheme: String {
        switch self {
        case .http:
            return "http"
        case .https:
            return "https"
        case .ftp:
            return "ftp"
        }
    }
    
    var defaultPort: Int {
        switch self {
        case .http:
            return 8080
        case .https:
            return 8443
        case .ftp:
            return 21
        }
    }
}

// MARK: - Wi-Fi 响应模型

struct WiFiDeviceResponse: Codable {
    let name: String
    let model: String
    let androidVersion: String
    let totalStorage: Int64?
    let availableStorage: Int64?
}

struct WiFiFileListResponse: Codable {
    let files: [WiFiFileEntry]
}

struct WiFiFileEntry: Codable {
    let path: String
    let relativePath: String
    let size: Int64
    let modified: Date
    let hash: String?
    let isDirectory: Bool
}

// MARK: - Wi-Fi 错误

enum WiFiError: LocalizedError {
    case connectionFailed
    case requestFailed
    case downloadFailed
    case invalidURL
    case authenticationRequired
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "无法连接到设备"
        case .requestFailed:
            return "请求失败"
        case .downloadFailed:
            return "下载失败"
        case .invalidURL:
            return "无效的 URL"
        case .authenticationRequired:
            return "需要身份验证"
        case .serverError(let message):
            return "服务器错误: \(message)"
        }
    }
}
