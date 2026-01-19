import Foundation
import Combine

class ADBManager: ObservableObject {
    static let shared = ADBManager()
    
    @Published var devices: [DeviceInfo] = []
    @Published var isScanning: Bool = false
    @Published private(set) var adbPath: String?
    
    private let queue = DispatchQueue(label: "com.atoa.sync.adb", qos: .userInitiated)
    
    private init() {
        self.adbPath = Self.findADBPath()
    }
    
    /// 重新检测 ADB 路径并更新
    @discardableResult
    func reloadADBPath() -> String? {
        let newPath = Self.findADBPath()
        DispatchQueue.main.async {
            self.adbPath = newPath
        }
        return newPath
    }
    
    private static func findADBPath() -> String? {
        let possiblePaths = [
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
            NSString(string: "~/Library/Android/sdk/platform-tools/adb").expandingTildeInPath,
            NSString(string: "~/Android/sdk/platform-tools/adb").expandingTildeInPath,
            // Homebrew on Intel Mac
            "/usr/local/Caskroom/android-platform-tools/latest/platform-tools/adb",
            // Homebrew on Apple Silicon
            "/opt/homebrew/Caskroom/android-platform-tools/latest/platform-tools/adb"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // 尝试使用 shell 来获取完整的 PATH 环境
        if let path = findADBUsingShell() {
            return path
        }
        
        return nil
    }
    
    private static func findADBUsingShell() -> String? {
        // 尝试使用 /bin/zsh -l -c 来获取完整的 shell 环境
        let shells = ["/bin/zsh", "/bin/bash"]
        
        for shell in shells {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["-l", "-c", "which adb"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !path.isEmpty,
                       FileManager.default.fileExists(atPath: path) {
                        return path
                    }
                }
            } catch {
                continue
            }
        }
        
        // 回退：直接使用 /usr/bin/which
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["adb"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // 忽略错误
        }
        
        return nil
    }
    
    var isADBInstalled: Bool {
        return adbPath != nil
    }
    
    var adbInstallationStatus: ADBInstallationStatus {
        if let path = adbPath {
            return .installed(path: path)
        } else {
            return .notInstalled
        }
    }
    
    /// 测试 ADB 是否正常工作
    func testADBConnection() async -> ADBTestResult {
        guard let adbPath = adbPath else {
            return .notInstalled
        }
        
        // 检查文件是否存在且可执行
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: adbPath) else {
            return .fileNotFound(path: adbPath)
        }
        
        guard fileManager.isExecutableFile(atPath: adbPath) else {
            return .notExecutable(path: adbPath)
        }
        
        // 尝试运行 adb version
        do {
            let output = try await executeCommand(arguments: ["version"])
            if output.contains("Android Debug Bridge") {
                return .working(version: parseADBVersion(from: output))
            } else {
                return .unexpectedOutput
            }
        } catch {
            return .executionError(error.localizedDescription)
        }
    }
    
    private func parseADBVersion(from output: String) -> String {
        // 解析类似 "Android Debug Bridge version 1.0.41" 的输出
        let lines = output.components(separatedBy: .newlines)
        if let versionLine = lines.first(where: { $0.contains("version") }) {
            return versionLine.trimmingCharacters(in: .whitespaces)
        }
        return "Unknown version"
    }
    
    func scanDevices() async throws -> [DeviceInfo] {
        guard let _ = adbPath else {
            throw ADBError.adbNotFound
        }
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
        guard let adbPath = adbPath else {
            throw ADBError.adbNotFound
        }
        
        print("[ADBManager] executeCommand: \(adbPath) \(arguments.joined(separator: " "))")
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                // 通过 shell 运行，正确处理符号链接
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                
                // 构建命令字符串，正确转义参数
                let command = ([adbPath] + arguments)
                    .map { arg in
                        if arg.contains(" ") || arg.contains("\"") || arg.contains("'") {
                            return "'\(arg.replacingOccurrences(of: "'", with: "'\\''"))'"
                        }
                        return arg
                    }
                    .joined(separator: " ")
                
                process.arguments = ["-c", command]
                
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
// MARK: - ADB 安装状态

enum ADBInstallationStatus {
    case installed(path: String)
    case notInstalled
    
    var isInstalled: Bool {
        if case .installed = self {
            return true
        }
        return false
    }
}

enum ADBTestResult {
    case working(version: String)
    case notInstalled
    case fileNotFound(path: String)
    case notExecutable(path: String)
    case unexpectedOutput
    case executionError(String)
    
    var isWorking: Bool {
        if case .working = self {
            return true
        }
        return false
    }
    
    var statusMessage: String {
        switch self {
        case .working(let version):
            return "✅ ADB 正常工作\n\(version)"
        case .notInstalled:
            return "❌ 未检测到 ADB"
        case .fileNotFound(let path):
            return "❌ ADB 文件不存在: \(path)"
        case .notExecutable(let path):
            return "❌ ADB 文件不可执行: \(path)"
        case .unexpectedOutput:
            return "⚠️ ADB 输出异常"
        case .executionError(let message):
            return "❌ 执行错误: \(message)"
        }
    }
}

// MARK: - ADB 安装指南

struct ADBInstallationGuide {
    
    static let homebrewInstallCommand = "brew install android-platform-tools"
    
    static let manualDownloadURL = URL(string: "https://developer.android.com/tools/releases/platform-tools")!
    
    static let installationSteps: [InstallationStep] = [
        InstallationStep(
            title: "方式一：使用 Homebrew 安装（推荐）",
            steps: [
                "1. 打开终端（Terminal）",
                "2. 如果未安装 Homebrew，先运行：",
                "   /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
                "3. 安装 ADB：",
                "   brew install android-platform-tools",
                "4. 验证安装：",
                "   adb version"
            ],
            command: homebrewInstallCommand
        ),
        InstallationStep(
            title: "方式二：从官网下载",
            steps: [
                "1. 访问 Android 官方下载页面",
                "2. 下载 macOS 版本的 Platform Tools",
                "3. 解压到任意位置（如 ~/Android/platform-tools）",
                "4. 将 ADB 添加到 PATH：",
                "   echo 'export PATH=$PATH:~/Android/platform-tools' >> ~/.zshrc",
                "5. 重新打开终端或运行 source ~/.zshrc"
            ],
            command: nil
        ),
        InstallationStep(
            title: "方式三：安装 Android Studio",
            steps: [
                "1. 下载并安装 Android Studio",
                "2. 打开 Android Studio > Preferences > Appearance & Behavior > System Settings > Android SDK",
                "3. 选择 SDK Tools 标签页",
                "4. 勾选 Android SDK Platform-Tools",
                "5. 点击 Apply 安装"
            ],
            command: nil
        )
    ]
    
    static let searchedPaths: [String] = [
        "/usr/local/bin/adb",
        "/opt/homebrew/bin/adb",
        "~/Library/Android/sdk/platform-tools/adb",
        "~/Android/sdk/platform-tools/adb",
        "/usr/local/Caskroom/android-platform-tools/latest/platform-tools/adb",
        "/opt/homebrew/Caskroom/android-platform-tools/latest/platform-tools/adb"
    ]
    
    /// 获取展开后的实际路径列表
    static var expandedSearchPaths: [String] {
        searchedPaths.map { path in
            NSString(string: path).expandingTildeInPath
        }
    }
    
    struct InstallationStep: Identifiable {
        let id = UUID()
        let title: String
        let steps: [String]
        let command: String?
    }
}

