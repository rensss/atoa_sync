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
        // 先尝试解析符号链接（/sdcard 通常是 /storage/self/primary 的符号链接）
        var actualPath = path
        
        // 检查路径是否是符号链接
        let checkOutput = try await executeCommand(arguments: ["-s", serialNumber, "shell", "readlink", "-f", path])
        let resolvedPath = checkOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resolvedPath.isEmpty && resolvedPath != path {
            print("[ADBManager] 路径 \(path) 是符号链接，解析为: \(resolvedPath)")
            actualPath = resolvedPath
        }
        
        // 使用 ls -la 列出目录内容（不使用 -R 递归，因为可能太慢）
        // 对于大目录，先列出第一层
        let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "ls", "-la", actualPath])
        
        print("[ADBManager] ls 输出前 1000 字符: \(String(output.prefix(1000)))")
        
        // 检查是否有错误信息
        if output.contains("No such file or directory") || output.contains("Permission denied") {
            print("[ADBManager] 访问路径失败: \(output)")
            throw ADBError.commandFailed(output)
        }
        
        let files = parseFileListFromLs(output: output, basePath: actualPath, currentDir: actualPath)
        print("[ADBManager] 解析到 \(files.count) 个文件/目录")
        
        return files
    }
    
    /// 递归列出文件（用于需要完整文件列表的场景）
    func listFilesRecursive(serialNumber: String, path: String, maxDepth: Int = 5) async throws -> [FileInfo] {
        // 先解析符号链接
        var actualPath = path
        let checkOutput = try await executeCommand(arguments: ["-s", serialNumber, "shell", "readlink", "-f", path])
        let resolvedPath = checkOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !resolvedPath.isEmpty && resolvedPath != path {
            actualPath = resolvedPath
        }
        
        // 使用 ls -laR 递归列出
        let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "ls", "-laR", actualPath])
        
        print("[ADBManager] ls -laR 输出前 500 字符: \(String(output.prefix(500)))")
        
        let files = parseFileListFromLsRecursive(output: output, basePath: actualPath)
        print("[ADBManager] 递归解析到 \(files.count) 个文件/目录")
        
        return files
    }
    
    /// 执行 Android shell 命令（命令作为单个字符串）
    private func executeShellCommand(serialNumber: String, command: String) async throws -> String {
        return try await executeCommand(arguments: ["-s", serialNumber, "shell", command])
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
    
    /// 获取文件夹大小（使用 du 命令）
    /// - Parameters:
    ///   - serialNumber: 设备序列号
    ///   - remotePath: 远程路径
    /// - Returns: 文件夹大小（字节）
    func getDirectorySize(serialNumber: String, remotePath: String) async throws -> Int64 {
        // 使用 du -sb 获取目录总大小（字节）
        // -s: 只显示总计
        // -b: 以字节为单位（某些 Android 设备可能不支持 -b，需要回退）
        do {
            let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "du", "-sb", remotePath], timeout: 120)
            
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = trimmed.split(separator: "\t", maxSplits: 1)
            
            if let sizeStr = components.first, let size = Int64(sizeStr) {
                return size
            }
        } catch {
            print("[ADBManager] du -sb 失败，尝试 du -sk: \(error.localizedDescription)")
        }
        
        // 回退方案：使用 du -sk（KB 单位）
        do {
            let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "du", "-sk", remotePath], timeout: 120)
            
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = trimmed.split(separator: "\t", maxSplits: 1)
            
            if let sizeStr = components.first, let sizeKB = Int64(sizeStr) {
                return sizeKB * 1024 // 转换为字节
            }
        } catch {
            print("[ADBManager] du -sk 也失败: \(error.localizedDescription)")
        }
        
        // 最后回退：使用 du -s（可能是 KB 或块）
        let output = try await executeCommand(arguments: ["-s", serialNumber, "shell", "du", "-s", remotePath], timeout: 120)
        
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: "\t", maxSplits: 1)
        
        if let sizeStr = components.first, let size = Int64(sizeStr) {
            // 假设是 KB
            return size * 1024
        }
        
        throw ADBError.invalidOutput
    }
    
    /// 批量获取多个目录的大小
    /// - Parameters:
    ///   - serialNumber: 设备序列号
    ///   - remotePaths: 远程路径列表
    /// - Returns: 路径到大小的映射
    func getDirectorySizes(serialNumber: String, remotePaths: [String]) async -> [String: Int64] {
        var results: [String: Int64] = [:]
        
        await withTaskGroup(of: (String, Int64?).self) { group in
            for path in remotePaths {
                group.addTask {
                    do {
                        let size = try await self.getDirectorySize(serialNumber: serialNumber, remotePath: path)
                        return (path, size)
                    } catch {
                        print("[ADBManager] 获取目录大小失败 \(path): \(error.localizedDescription)")
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
    
    /// 解析 ls -la 命令输出的文件列表（非递归，单层目录）
    /// Android ls -l 输出格式示例:
    /// drwxrwx--x  5 root sdcard_rw 4096 2024-01-15 10:30 DCIM
    /// -rw-rw----  1 root sdcard_rw 1234567 2024-01-15 10:30 photo.jpg
    /// lrwxrwxrwx  1 root root      21 2024-01-15 10:30 sdcard -> /storage/self/primary
    private func parseFileListFromLs(output: String, basePath: String, currentDir: String) -> [FileInfo] {
        var files: [FileInfo] = []
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }
            
            // 跳过 "total" 行
            if trimmed.hasPrefix("total ") {
                continue
            }
            
            // 必须以权限字符串开头 (d/l/-/c/b 等)
            guard let firstChar = trimmed.first,
                  "dlcbsp-".contains(firstChar) else {
                print("[ADBManager] 跳过非文件行: \(trimmed)")
                continue
            }
            
            // 跳过符号链接 (以 'l' 开头)
            if trimmed.hasPrefix("l") {
                print("[ADBManager] 跳过符号链接: \(trimmed)")
                continue
            }
            
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            
            guard components.count >= 7 else {
                print("[ADBManager] 跳过列数不足的行 (\(components.count) 列): \(trimmed)")
                continue
            }
            
            let permissions = String(components[0])
            let isDirectory = permissions.hasPrefix("d")
            
            // 跳过 . 和 .. 目录
            let lastComponent = String(components.last ?? "")
            if lastComponent == "." || lastComponent == ".." {
                continue
            }
            
            // 解析文件信息
            guard let fileInfo = parseFileLine(components: components, currentDir: currentDir, basePath: basePath, isDirectory: isDirectory) else {
                continue
            }
            
            files.append(fileInfo)
        }
        
        print("[ADBManager] parseFileListFromLs: 解析到 \(files.count) 个文件/目录")
        return files
    }
    
    /// 解析 ls -laR 命令输出的文件列表（递归）
    private func parseFileListFromLsRecursive(output: String, basePath: String) -> [FileInfo] {
        var files: [FileInfo] = []
        var currentDir = basePath
        
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }
            
            // 检测目录行，格式如: "/storage/self/primary/DCIM:"
            if trimmed.hasSuffix(":") && !trimmed.contains(" ") {
                currentDir = String(trimmed.dropLast())
                continue
            }
            
            // 跳过 "total" 行
            if trimmed.hasPrefix("total ") {
                continue
            }
            
            // 必须以权限字符串开头 (d/l/-/c/b 等)
            guard let firstChar = trimmed.first,
                  "dlcbsp-".contains(firstChar) else {
                continue
            }
            
            // 跳过符号链接 (以 'l' 开头)
            if trimmed.hasPrefix("l") {
                continue
            }
            
            let components = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            
            guard components.count >= 7 else {
                continue
            }
            
            let permissions = String(components[0])
            let isDirectory = permissions.hasPrefix("d")
            
            // 跳过 . 和 .. 目录
            let lastComponent = String(components.last ?? "")
            if lastComponent == "." || lastComponent == ".." {
                continue
            }
            
            // 解析文件信息
            guard let fileInfo = parseFileLine(components: components, currentDir: currentDir, basePath: basePath, isDirectory: isDirectory) else {
                continue
            }
            
            files.append(fileInfo)
        }
        
        print("[ADBManager] parseFileListFromLsRecursive: 解析到 \(files.count) 个文件/目录")
        return files
    }
    
    /// 解析单行文件信息
    private func parseFileLine(components: [String.SubSequence], currentDir: String, basePath: String, isDirectory: Bool) -> FileInfo? {
        // 查找大小字段：从第3个开始找第一个纯数字字段
        var sizeIndex = -1
        for i in 3..<min(6, components.count) {
            let comp = String(components[i])
            if let _ = Int64(comp), i + 1 < components.count {
                let nextComp = String(components[i + 1])
                if nextComp.contains("-") || isMonthAbbreviation(nextComp) {
                    sizeIndex = i
                    break
                }
            }
        }
        
        guard sizeIndex > 0 else {
            return nil
        }
        
        guard let size = Int64(components[sizeIndex]) else {
            return nil
        }
        
        // 确定文件名开始位置
        var fileNameStartIndex = sizeIndex + 3
        
        // 检查是否有时区字段
        if fileNameStartIndex < components.count {
            let possibleTimezone = String(components[fileNameStartIndex])
            if possibleTimezone.hasPrefix("+") || possibleTimezone.hasPrefix("-") {
                if possibleTimezone.count == 5, Int(possibleTimezone.dropFirst()) != nil {
                    fileNameStartIndex += 1
                }
            }
        }
        
        guard fileNameStartIndex < components.count else {
            return nil
        }
        
        // 提取文件名
        var fileName = components[fileNameStartIndex...].joined(separator: " ")
        
        // 移除符号链接目标部分
        if let arrowRange = fileName.range(of: " -> ") {
            fileName = String(fileName[..<arrowRange.lowerBound])
        }
        
        if fileName.isEmpty || fileName == "." || fileName == ".." {
            return nil
        }
        
        let fullPath = "\(currentDir)/\(fileName)"
        
        // 解析日期
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
    
    /// 检查是否是英文月份缩写
    private func isMonthAbbreviation(_ str: String) -> Bool {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return months.contains(str)
    }
    
    /// 解析 Android 日期格式
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
    
    private func executeCommand(arguments: [String], timeout: TimeInterval = 60) async throws -> String {
        guard let adbPath = adbPath else {
            throw ADBError.adbNotFound
        }
        
        // 解析符号链接，获取真实路径
        let resolvedPath: String
        do {
            let url = URL(fileURLWithPath: adbPath)
            resolvedPath = url.resolvingSymlinksInPath().path
        } catch {
            resolvedPath = adbPath
        }
        
        print("[ADBManager] executeCommand: \(resolvedPath) \(arguments.joined(separator: " "))")
        
        return try await withThrowingTaskGroup(of: String.self) { group in
            // 添加执行任务
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    self.queue.async {
                        let process = Process()
                        
                        process.executableURL = URL(fileURLWithPath: resolvedPath)
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
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw ADBError.commandFailed("命令执行超时（\(Int(timeout))秒）")
            }
            
            // 返回第一个完成的结果（成功或失败）
            let result = try await group.next()!
            group.cancelAll()
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

