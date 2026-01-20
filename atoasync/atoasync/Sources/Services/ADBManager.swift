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
            "/usr/local/Caskroom/android-platform-tools/latest/platform-tools/adb",
            "/opt/homebrew/Caskroom/android-platform-tools/latest/platform-tools/adb"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        if let path = findADBUsingShell() {
            return path
        }
        
        return nil
    }
    
    private static func findADBUsingShell() -> String? {
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
        } catch {}
        
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
    
    func testADBConnection() async -> ADBTestResult {
        guard let adbPath = adbPath else {
            return .notInstalled
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: adbPath) else {
            return .fileNotFound(path: adbPath)
        }
        
        guard fileManager.isExecutableFile(atPath: adbPath) else {
            return .notExecutable(path: adbPath)
        }
        
        do {
            let output = try await executeCommand(arguments: ["version"])
            if output.contains("Android Debug Bridge") {
                return .working(version: parseADBVersion(from: output))
            } else {
                return .unexpectedOutput
            }
        } catch is CancellationError {
            return .executionError("操作已取消")
        } catch {
            return .executionError(error.localizedDescription)
        }
    }
    
    private func parseADBVersion(from output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        if let versionLine = lines.first(where: { $0.contains("version") }) {
            return versionLine.trimmingCharacters(in: .whitespaces)
        }
        return "Unknown version"
    }
    
    func scanDevices() async throws -> [DeviceInfo] {
        guard adbPath != nil else {
            throw ADBError.adbNotFound
        }
        await MainActor.run { isScanning = true }
        defer { Task { @MainActor in isScanning = false } }
        
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
    
    // MARK: - 路径解析
    
    func resolvePath(serialNumber: String, path: String) async throws -> String {
        let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "readlink", "-f", path])
        let resolved = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return resolved.isEmpty ? path : resolved
    }
    
    func listFiles(serialNumber: String, path: String) async throws -> [FileInfo] {
        var actualPath = path
        let resolvedPath = try await resolvePath(serialNumber: serialNumber, path: path)
        if !resolvedPath.isEmpty && resolvedPath != path {
            actualPath = resolvedPath
        }
        
        let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "ls", "-la", actualPath])
        
        if output.contains("No such file or directory") || output.contains("Permission denied") {
            throw ADBError.commandFailed(output)
        }
        
        return parseFileListFromLs(output: output, basePath: actualPath, currentDir: actualPath)
    }
    
    func listFilesRecursive(serialNumber: String, path: String, maxDepth: Int = 5) async throws -> [FileInfo] {
        var actualPath = path
        let resolvedPath = try await resolvePath(serialNumber: serialNumber, path: path)
        if !resolvedPath.isEmpty && resolvedPath != path {
            actualPath = resolvedPath
        }
        
        let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "ls", "-laR", actualPath], timeout: 300)
        return parseFileListFromLsRecursive(output: output, basePath: actualPath)
    }
    
    func pullFile(serialNumber: String, remotePath: String, localPath: String) async throws {
        _ = try await executeCommand(arguments: ["-s", serialNumber, "pull", remotePath, localPath], timeout: 300)
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
    
    func getDirectorySize(serialNumber: String, remotePath: String) async throws -> Int64 {
        do {
            let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "du", "-sb", remotePath], timeout: 120)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = trimmed.split(separator: "\t", maxSplits: 1)
            if let sizeStr = components.first, let size = Int64(sizeStr) {
                return size
            }
        } catch {
            // fallthrough
        }
        
        do {
            let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "du", "-sk", remotePath], timeout: 120)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = trimmed.split(separator: "\t", maxSplits: 1)
            if let sizeStr = components.first, let sizeKB = Int64(sizeStr) {
                return sizeKB * 1024
            }
        } catch {
            // fallthrough
        }
        
        let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "du", "-s", remotePath], timeout: 120)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: "\t", maxSplits: 1)
        if let sizeStr = components.first, let size = Int64(sizeStr) {
            return size * 1024
        }
        
        throw ADBError.invalidOutput
    }
    
    func getDirectorySizes(serialNumber: String, remotePaths: [String]) async -> [String: Int64] {
        var results: [String: Int64] = [:]
        
        await withTaskGroup(of: (String, Int64?).self) { group in
            for path in remotePaths {
                group.addTask {
                    do {
                        let size = try await self.getDirectorySize(serialNumber: serialNumber, remotePath: path)
                        return (path, size)
                    } catch {
                        return (path, nil)
                    }
                }
            }
            
            for await (path, size) in group {
                if let size = size {
                    results[path] = size
                }
            }
        }
        
        return results
    }
    
    // MARK: - 解析 ls 输出
    
    private func parseFileListFromLs(output: String, basePath: String, currentDir: String) -> [FileInfo] {
        var files: [FileInfo] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if Task.isCancelled { break }
            
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("total ") { continue }
            
            guard let firstChar = trimmed.first, "dlcbsp-".contains(firstChar) else { continue }
            if trimmed.hasPrefix("l") { continue }
            
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 7 else { continue }
            
            let permissions = String(components[0])
            let isDirectory = permissions.hasPrefix("d")
            let lastComponent = String(components.last ?? "")
            if lastComponent == "." || lastComponent == ".." { continue }
            
            guard let fileInfo = parseFileLine(components: components, currentDir: currentDir, basePath: basePath, isDirectory: isDirectory) else {
                continue
            }
            
            files.append(fileInfo)
        }
        
        return files
    }
    
    private func parseFileListFromLsRecursive(output: String, basePath: String) -> [FileInfo] {
        var files: [FileInfo] = []
        var currentDir = basePath
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            if Task.isCancelled { break }
            
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed.hasSuffix(":") && !trimmed.contains(" ") {
                currentDir = String(trimmed.dropLast())
                continue
            }
            
            if trimmed.hasPrefix("total ") { continue }
            guard let firstChar = trimmed.first, "dlcbsp-".contains(firstChar) else { continue }
            if trimmed.hasPrefix("l") { continue }
            
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 7 else { continue }
            
            let permissions = String(components[0])
            let isDirectory = permissions.hasPrefix("d")
            
            let lastComponent = String(components.last ?? "")
            if lastComponent == "." || lastComponent == ".." { continue }
            
            guard let fileInfo = parseFileLine(components: components, currentDir: currentDir, basePath: basePath, isDirectory: isDirectory) else {
                continue
            }
            files.append(fileInfo)
        }
        
        return files
    }
    
    private func parseFileLine(components: [String.SubSequence], currentDir: String, basePath: String, isDirectory: Bool) -> FileInfo? {
        var sizeIndex = -1
        for i in 3..<min(6, components.count) {
            let comp = String(components[i])
            if Int64(comp) != nil, i + 1 < components.count {
                let nextComp = String(components[i + 1])
                if nextComp.contains("-") || isMonthAbbreviation(nextComp) {
                    sizeIndex = i
                    break
                }
            }
        }
        
        guard sizeIndex > 0 else { return nil }
        guard let size = Int64(components[sizeIndex]) else { return nil }
        
        var fileNameStartIndex = sizeIndex + 3
        if fileNameStartIndex < components.count {
            let possibleTimezone = String(components[fileNameStartIndex])
            if (possibleTimezone.hasPrefix("+") || possibleTimezone.hasPrefix("-")),
               possibleTimezone.count == 5,
               Int(possibleTimezone.dropFirst()) != nil {
                fileNameStartIndex += 1
            }
        }
        
        guard fileNameStartIndex < components.count else { return nil }
        
        var fileName = components[fileNameStartIndex...].joined(separator: " ")
        if let arrowRange = fileName.range(of: " -> ") {
            fileName = String(fileName[..<arrowRange.lowerBound])
        }
        
        if fileName.isEmpty || fileName == "." || fileName == ".." { return nil }
        
        let fullPath = "\(currentDir)/\(fileName)"
        let dateStr = "\(components[sizeIndex + 1]) \(components[sizeIndex + 2])"
        let modified = parseAndroidDate(dateStr)
        
        var relativePath = fullPath.replacingOccurrences(of: basePath, with: "")
        if relativePath.isEmpty {
            relativePath = "/"
        } else if !relativePath.hasPrefix("/") {
            relativePath = "/" + relativePath
        }
        
        return FileInfo(
            path: fullPath,
            relativePath: relativePath,
            size: size,
            modified: modified,
            isDirectory: isDirectory
        )
    }
    
    private func isMonthAbbreviation(_ str: String) -> Bool {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return months.contains(str)
    }
    
    private func parseAndroidDate(_ dateStr: String) -> Date {
        let formatters: [DateFormatter] = {
            let formats = [
                "yyyy-MM-dd HH:mm",
                "yyyy-MM-dd HH:mm:ss",
                "MMM dd HH:mm",
                "MMM dd yyyy",
                "MMM  d HH:mm",
                "MMM  d yyyy",
                "yyyy-MM-dd"
            ]
            return formats.map { format in
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                return formatter
            }
        }()
        
        for formatter in formatters {
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        
        return Date()
    }
    
    // MARK: - 可取消（立即 terminate/kill）的命令执行
    
    private func executeCommand(arguments: [String], timeout: TimeInterval = 60) async throws -> String {
        if Task.isCancelled { throw CancellationError() }
        guard let adbPath = adbPath else { throw ADBError.adbNotFound }
        
        let resolvedPath: String
        do {
            let url = URL(fileURLWithPath: adbPath)
            resolvedPath = url.resolvingSymlinksInPath().path
        } catch {
            resolvedPath = adbPath
        }
        
        // 共享引用：让取消处理能拿到正在运行的 Process
        final class ProcessBox: @unchecked Sendable {
            let lock = NSLock()
            var process: Process?
        }
        let box = ProcessBox()
        
        let runTask = Task.detached(priority: .userInitiated) { () throws -> String in
            try await withCheckedThrowingContinuation { continuation in
                self.queue.async {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: resolvedPath)
                    process.arguments = arguments
                    
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    
                    box.lock.lock()
                    box.process = process
                    box.lock.unlock()
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        
                        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        
                        let output = String(data: outputData, encoding: .utf8) ?? ""
                        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                        
                        if process.terminationStatus != 0 {
                            // 如果是被我们 terminate/kill，视作取消
                            if process.terminationStatus == 143 || process.terminationStatus == 137 {
                                continuation.resume(throwing: CancellationError())
                            } else {
                                continuation.resume(throwing: ADBError.commandFailed(errorOutput.isEmpty ? output : errorOutput))
                            }
                            return
                        }
                        
                        continuation.resume(returning: output)
                    } catch {
                        // 如果在 run 之前就被取消并 terminate，也可能走到这里
                        continuation.resume(throwing: ADBError.executionFailed(error.localizedDescription))
                    }
                }
            }
        }
        
        // timeout/取消 监控：任何一个先发生都要结束进程并返回
        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await withTaskCancellationHandler {
                    try await runTask.value
                } onCancel: {
                    // 立即 terminate，必要时 kill
                    box.lock.lock()
                    let p = box.process
                    box.lock.unlock()
                    
                    guard let p else { return }
                    if p.isRunning {
                        p.terminate()
                        // 给一点时间让它退出，不退出就 kill
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
                            if p.isRunning {
                                kill(p.processIdentifier, SIGKILL)
                            }
                        }
                    }
                }
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                
                // 超时也 terminate/kill
                box.lock.lock()
                let p = box.process
                box.lock.unlock()
                
                if let p, p.isRunning {
                    p.terminate()
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
                        if p.isRunning {
                            kill(p.processIdentifier, SIGKILL)
                        }
                    }
                }
                
                throw ADBError.commandFailed("命令执行超时（\(Int(timeout))秒）")
            }
            
            let result = try await group.next()!
            group.cancelAll()
            runTask.cancel()
            return result
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

enum ADBInstallationStatus {
    case installed(path: String)
    case notInstalled
    
    var isInstalled: Bool {
        if case .installed = self { return true }
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
        if case .working = self { return true }
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
    
    static var expandedSearchPaths: [String] {
        searchedPaths.map { NSString(string: $0).expandingTildeInPath }
    }
    
    struct InstallationStep: Identifiable {
        let id = UUID()
        let title: String
        let steps: [String]
        let command: String?
    }
}

