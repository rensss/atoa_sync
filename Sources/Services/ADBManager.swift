import Foundation

class ADBManager: ObservableObject {
    static let shared = ADBManager()
    
    @Published var devices: [DeviceInfo] = []
    @Published var isScanning: Bool = false
    
    private let adbPath: String
    private let queue = DispatchQueue(label: "com.atoa.sync.adb", qos: .userInitiated)
    
    private init() {
        self.adbPath = Self.findADBPath()
    }
    
    private static func findADBPath() -> String {
        let possiblePaths = [
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
            "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb",
            "/Users/\(NSUserName())/Android/sdk/platform-tools/adb"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return "adb"
    }
    
    func scanDevices() async throws -> [DeviceInfo] {
        await MainActor.run {
            isScanning = true
        }
        
        defer {
            Task { @MainActor in
                isScanning = false
            }
        }
        
        let output = try await executeCommand(arguments: ["devices", "-l"])
        let lines = output.components(separatedBy: .newlines)
        
        var foundDevices: [DeviceInfo] = []
        
        for line in lines {
            if line.isEmpty || line.contains("List of devices") {
                continue
            }
            
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 2, components[1] == "device" else {
                continue
            }
            
            let serialNumber = String(components[0])
            
            let model = try? await getDeviceProperty(serialNumber: serialNumber, property: "ro.product.model")
            let androidVersion = try? await getDeviceProperty(serialNumber: serialNumber, property: "ro.build.version.release")
            let deviceName = try? await getDeviceProperty(serialNumber: serialNumber, property: "ro.product.name")
            
            let device = DeviceInfo(
                serialNumber: serialNumber,
                name: deviceName ?? "",
                model: model ?? "Unknown",
                androidVersion: androidVersion ?? "Unknown",
                isConnected: true,
                connectionType: .usb
            )
            
            foundDevices.append(device)
        }
        
        await MainActor.run {
            self.devices = foundDevices
        }
        
        return foundDevices
    }
    
    func getDeviceProperty(serialNumber: String, property: String) async throws -> String {
        let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "getprop", property])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func listFiles(serialNumber: String, path: String) async throws -> [FileInfo] {
        let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "ls", "-lR", path])
        return parseFileList(output: output, basePath: path)
    }
    
    func pullFile(serialNumber: String, remotePath: String, localPath: String) async throws {
        _ = try await executeCommand(arguments: ["-s", serialNumber, "pull", remotePath, localPath])
    }
    
    func getFileInfo(serialNumber: String, remotePath: String) async throws -> FileInfo? {
        let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "stat", "-c", "%s %Y", remotePath])
        
        let components = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard components.count >= 2,
              let size = Int64(components[0]),
              let timestamp = TimeInterval(components[1]) else {
            return nil
        }
        
        let modified = Date(timeIntervalSince1970: timestamp)
        
        return FileInfo(
            path: remotePath,
            relativePath: remotePath,
            size: size,
            modified: modified,
            isDirectory: false
        )
    }
    
    private func parseFileList(output: String, basePath: String) -> [FileInfo] {
        var files: [FileInfo] = []
        var currentDir = basePath
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if line.isEmpty {
                continue
            }
            
            if line.hasSuffix(":") {
                currentDir = String(line.dropLast())
                continue
            }
            
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 8 else {
                continue
            }
            
            let permissions = String(components[0])
            let isDirectory = permissions.hasPrefix("d")
            
            guard let size = Int64(components[4]) else {
                continue
            }
            
            let fileName = components[7...].joined(separator: " ")
            let fullPath = "\(currentDir)/\(fileName)"
            
            let dateStr = "\(components[5]) \(components[6])"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            let modified = dateFormatter.date(from: dateStr) ?? Date()
            
            let file = FileInfo(
                path: fullPath,
                relativePath: fullPath.replacingOccurrences(of: basePath, with: ""),
                size: size,
                modified: modified,
                isDirectory: isDirectory
            )
            
            files.append(file)
        }
        
        return files
    }
    
    private func executeCommand(arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: self.adbPath)
                process.arguments = arguments
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    if process.terminationStatus != 0 {
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: ADBError.commandFailed(errorMessage))
                        return
                    }
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: ADBError.executionFailed(error.localizedDescription))
                }
            }
        }
    }
}

enum ADBError: LocalizedError {
    case adbNotFound
    case commandFailed(String)
    case executionFailed(String)
    case deviceNotFound
    case invalidOutput
    
    var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return "未找到 ADB 工具，请确保已安装 Android SDK Platform Tools"
        case .commandFailed(let message):
            return "ADB 命令执行失败: \(message)"
        case .executionFailed(let message):
            return "执行失败: \(message)"
        case .deviceNotFound:
            return "未找到设备"
        case .invalidOutput:
            return "无效的输出格式"
        }
    }
}
