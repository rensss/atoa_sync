import SwiftUI

struct ADBSetupGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var testResult: ADBTestResult?
    @State private var isTesting = false
    @State private var selectedTab = 0
    @State private var detectedADBPath: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部状态
            headerView
            
            Divider()
            
            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 当前状态
                    statusSection
                    
                    Divider()
                    
                    // 安装指南
                    installationGuideSection
                    
                    Divider()
                    
                    // 检测路径说明
                    detectedPathsSection
                }
                .padding()
            }
            
            Divider()
            
            // 底部操作
            footerView
        }
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            Task {
                await runTest()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver")
                .font(.largeTitle)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text("ADB 设置向导")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Android Debug Bridge (ADB) 是连接 Android 设备的必要工具")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 关闭按钮
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前状态")
                .font(.headline)
            
            HStack(spacing: 12) {
                statusIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if let result = testResult {
                        Text(result.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let path = detectedADBPath {
                        Text("路径: \(path)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await runTest()
                    }
                }) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 80)
                    } else {
                        Label("重新检测", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isTesting)
            }
            .padding()
            .background(statusBackgroundColor)
            .cornerRadius(8)
        }
    }
    
    private var statusIcon: some View {
        Group {
            if isTesting {
                ProgressView()
            } else if testResult?.isWorking == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title)
            }
        }
    }
    
    private var statusTitle: String {
        if isTesting {
            return "正在检测..."
        } else if testResult?.isWorking == true {
            return "ADB 已正确安装"
        } else {
            return "ADB 未安装或配置错误"
        }
    }
    
    private var statusBackgroundColor: Color {
        if testResult?.isWorking == true {
            return Color.green.opacity(0.1)
        } else {
            return Color.red.opacity(0.1)
        }
    }
    
    // MARK: - Installation Guide
    
    private var installationGuideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("安装指南")
                .font(.headline)
            
            ForEach(Array(ADBInstallationGuide.installationSteps.enumerated()), id: \.element.id) { index, step in
                installationStepView(step: step, index: index)
            }
        }
    }
    
    private func installationStepView(step: ADBInstallationGuide.InstallationStep, index: Int) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(step.steps, id: \.self) { stepText in
                    Text(stepText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                if let command = step.command {
                    HStack {
                        Text(command)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(4)
                            .textSelection(.enabled)
                        
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(command, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .help("复制命令")
                        
                        Button(action: {
                            openTerminalWithCommand(command)
                        }) {
                            Image(systemName: "terminal")
                        }
                        .help("在终端中打开")
                    }
                    .padding(.top, 4)
                }
                
                if index == 1 {
                    Button(action: {
                        NSWorkspace.shared.open(ADBInstallationGuide.manualDownloadURL)
                    }) {
                        Label("打开下载页面", systemImage: "safari")
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 8)
        } label: {
            Text(step.title)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Detected Paths Section
    
    private var detectedPathsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("检测路径")
                .font(.headline)
            
            Text("应用会在以下路径搜索 ADB：")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(ADBInstallationGuide.searchedPaths, id: \.self) { path in
                    HStack {
                        Image(systemName: pathExists(path) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(pathExists(path) ? .green : .secondary)
                            .font(.caption)
                        
                        Text(path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(pathExists(path) ? .primary : .secondary)
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            Text("提示：也会通过 which adb 命令搜索系统 PATH 中的 ADB")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func pathExists(_ path: String) -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expandedPath)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        HStack {
            Button("打开终端") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
            }
            
            Spacer()
            
            Button("关闭") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            if testResult?.isWorking == true {
                Button("完成") {
                    // 关闭窗口的逻辑由父视图处理
                    NotificationCenter.default.post(name: .adbSetupCompleted, object: nil)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func runTest() async {
        isTesting = true
        
        // 重新查找 ADB 路径（每次都重新检测）
        let (path, result) = await findAndTestADB()
        
        await MainActor.run {
            detectedADBPath = path
            testResult = result
            isTesting = false
        }
    }
    
    /// 重新搜索 ADB 路径并测试
    private func findAndTestADB() async -> (String?, ADBTestResult) {
        // 使用展开后的实际路径列表
        let possiblePaths = ADBInstallationGuide.expandedSearchPaths
        
        // 先尝试 which 命令，因为它会使用用户的 PATH 环境变量
        if let whichPath = findADBUsingWhich() {
            // 解析符号链接
            let resolvedPath = resolveSymlink(whichPath) ?? whichPath
            let result = await testADBAt(path: resolvedPath)
            if result.isWorking {
                return (resolvedPath, result)
            }
        }
        
        // 检查预设路径
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                // 解析符号链接
                let resolvedPath = resolveSymlink(path) ?? path
                let result = await testADBAt(path: resolvedPath)
                if result.isWorking {
                    return (resolvedPath, result)
                }
            }
        }
        
        return (nil, .notInstalled)
    }
    
    /// 解析符号链接
    private func resolveSymlink(_ path: String) -> String? {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            
            if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                let resolvedPath = try fileManager.destinationOfSymbolicLink(atPath: path)
                
                if !resolvedPath.hasPrefix("/") {
                    let parentDir = (path as NSString).deletingLastPathComponent
                    let absolutePath = (parentDir as NSString).appendingPathComponent(resolvedPath)
                    return (absolutePath as NSString).standardizingPath
                }
                
                return resolvedPath
            }
            
            return path
        } catch {
            // 尝试使用 realpath
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/realpath")
            process.arguments = [path]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let resolvedPath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !resolvedPath.isEmpty {
                        return resolvedPath
                    }
                }
            } catch {}
            
            return nil
        }
    }
    
    private func findADBUsingWhich() -> String? {
        // 尝试使用 /bin/zsh -l -c 来获取完整的 shell 环境
        // 这样可以读取用户的 .zshrc 或 .bash_profile 中配置的 PATH
        let shells = ["/bin/zsh", "/bin/bash"]
        
        for shell in shells {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell)
            // -l: login shell, -c: command
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
        
        // 回退：直接使用 /usr/bin/which（可能不包含用户自定义 PATH）
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
    
    private func testADBAt(path: String) async -> ADBTestResult {
        print("[ADBSetupGuide] Testing ADB at: \(path)")
        
        // 检查文件是否存在
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            print("[ADBSetupGuide] File does not exist: \(path)")
            return .fileNotFound(path: path)
        }
        
        // 跳过 isExecutableFile 检查，直接尝试运行
        // 因为 isExecutableFile 对某些路径可能返回 false
        print("[ADBSetupGuide] File exists, attempting to run...")
        
        // 尝试运行 adb version
        do {
            let output = try await runProcess(executablePath: path, arguments: ["version"])
            print("[ADBSetupGuide] ADB output: \(output.prefix(100))...")
            
            if output.contains("Android Debug Bridge") {
                let version = parseADBVersion(from: output)
                return .working(version: version)
            } else {
                return .unexpectedOutput
            }
        } catch {
            print("[ADBSetupGuide] Error running ADB: \(error)")
            return .executionError(error.localizedDescription)
        }
    }
    
    private func runProcess(executablePath: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // 方法1：直接运行（可能对符号链接有问题）
                // 方法2：通过 shell 运行，这样可以正确处理符号链接
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                
                // 构建命令字符串
                let command = ([executablePath] + arguments)
                    .map { arg in
                        // 转义特殊字符
                        if arg.contains(" ") || arg.contains("\"") {
                            return "\"\(arg.replacingOccurrences(of: "\"", with: "\\\""))\""
                        }
                        return arg
                    }
                    .joined(separator: " ")
                
                process.arguments = ["-c", command]
                
                print("[ADBSetupGuide] Running: /bin/zsh -c '\(command)'")
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    
                    print("[ADBSetupGuide] Exit code: \(process.terminationStatus)")
                    
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        let message = errorOutput.isEmpty ? "Exit code: \(process.terminationStatus)" : errorOutput
                        print("[ADBSetupGuide] Error: \(message)")
                        continuation.resume(throwing: NSError(
                            domain: "ADBTest",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: message]
                        ))
                    }
                } catch {
                    print("[ADBSetupGuide] Process exception: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func parseADBVersion(from output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        if let versionLine = lines.first(where: { $0.contains("version") }) {
            return versionLine.trimmingCharacters(in: .whitespaces)
        }
        return "Unknown version"
    }
    
    private func openTerminalWithCommand(_ command: String) {
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let adbSetupCompleted = Notification.Name("adbSetupCompleted")
}

// MARK: - Preview

#Preview {
    ADBSetupGuideView()
}
