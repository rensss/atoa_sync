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
    /// - 支持 HTTP/HTTPS（通过 /device/info 获取 JSON）和 FTP（尝试与 FTP 服务器建立连接，若成功则视为连接成功）
    func connect(
        host: String,
        port: Int = 8080,
        wifiProtocol: WiFiProtocol = .http,
        username: String? = nil,
        password: String? = nil
    ) async throws -> WiFiDeviceInfo {
        // 对于 FTP 使用不同的连接方式
        if wifiProtocol == .ftp {
            // FTP URL (支持带凭据或匿名)
            var credentialPrefix = ""
            if let user = username, !user.isEmpty {
                // 将用户名和密码进行 URL 编码
                let encodedUser = user.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? user
                if let pass = password, !pass.isEmpty {
                    let encodedPass = pass.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? pass
                    credentialPrefix = "\(encodedUser):\(encodedPass)@"
                } else {
                    credentialPrefix = "\(encodedUser)@"
                }
            }
            
            let ftpURLString = "ftp://\(credentialPrefix)\(host):\(port)/"
            guard let url = URL(string: ftpURLString) else {
                throw WiFiError.invalidURL
            }
            
            do {
                // 尝试 download，这通常可用于检测 FTP 服务器是否可访问/认证成功
                let (_, response) = try await urlSession.download(from: url)
                
                // 部分 FTP 服务器对 URLSession 返回的 response 可能不是 HTTPURLResponse，但只要没有抛错则认为连接成功
                let device = WiFiDeviceInfo(
                    id: UUID(),
                    host: host,
                    port: port,
                    connectionProtocol: wifiProtocol,
                    name: "FTP:\(host)",
                    model: "",
                    androidVersion: "",
                    isConnected: true
                )
                
                await MainActor.run {
                    if !connectedDevices.contains(where: { $0.host == host && $0.port == port }) {
                        connectedDevices.append(device)
                    }
                }
                
                LogManager.shared.log("Wi-Fi FTP 设备已连接: \(device.displayName) (\(host):\(port))", level: .info, category: "WiFi")
                return device
            } catch {
                // 特殊处理 FTP 常见错误
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .cannotFindHost:
                        throw WiFiError.serverError("找不到主机：请确认 IP 地址是否正确")
                    case .timedOut:
                        throw WiFiError.serverError("连接超时：请检查端口或网络连通性")
                    case .userAuthenticationRequired:
                        throw WiFiError.authenticationRequired
                    default:
                        throw WiFiError.serverError(urlError.localizedDescription)
                    }
                } else {
                    throw WiFiError.serverError(error.localizedDescription)
                }
            }
        }
        
        // 非 FTP（HTTP/HTTPS）按原来的流程：请求 /device/info
        let baseURL = "\(wifiProtocol.scheme)://\(host):\(port)"
        
        guard let infoURL = URL(string: "\(baseURL)/device/info") else {
            throw WiFiError.invalidURL
        }
        
        do {
            let (data, response) = try await urlSession.data(from: infoURL)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WiFiError.requestFailed
            }
            
            guard httpResponse.statusCode == 200 else {
                // 把服务器返回体包含到错误中，便于调试
                let body = String(data: data, encoding: .utf8) ?? "<no body>"
                throw WiFiError.serverError("HTTP \(httpResponse.statusCode): \(body)")
            }
            
            // 解析设备信息
            let decoder = JSONDecoder()
            let deviceResponse = try decoder.decode(WiFiDeviceResponse.self, from: data)
            
            let device = WiFiDeviceInfo(
                id: UUID(),
                host: host,
                port: port,
                connectionProtocol: wifiProtocol,
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
        } catch {
            // 更友好地映射 URLError 到 WiFiError，便于 UI 显示明确原因
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    throw WiFiError.serverError("网络不可用：请检查 Mac 与设备是否在同一网络")
                case .timedOut:
                    throw WiFiError.serverError("连接超时：设备响应过慢或端口被阻止")
                case .cannotFindHost:
                    throw WiFiError.serverError("找不到主机：请确认 IP 地址是否正确")
                case .cannotConnectToHost, .networkConnectionLost:
                    throw WiFiError.serverError("无法连接到设备：端口可能未打开或被防火墙/路由器阻止")
                case .resourceUnavailable:
                    throw WiFiError.serverError("资源不可用：设备可能未运行文件服务器或服务器暂时不可用")
                default:
                    throw WiFiError.serverError(urlError.localizedDescription)
                }
            } else if let wifiErr = error as? WiFiError {
                throw wifiErr
            } else {
                throw WiFiError.serverError(error.localizedDescription)
            }
        }
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
        let baseURL = "\(device.connectionProtocol.scheme)://\(device.host):\(device.port)"
        
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
        let baseURL = "\(device.connectionProtocol.scheme)://\(device.host):\(device.port)"
        
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
        } else if let username = username {
            ftpURL += "\(username)@"
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
    let connectionProtocol: WiFiProtocol
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
            return "需要身份验证（FTP 登录失败）"
        case .serverError(let message):
            return message
        }
    }
}
