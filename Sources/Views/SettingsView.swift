import SwiftUI

struct SettingsView: View {
    @ObservedObject private var configManager = ConfigManager.shared
    
    var body: some View {
        Form {
            Section("同步设置") {
                Toggle("启用哈希比较", isOn: $configManager.config.enableHashComparison)
                    .help("使用文件哈希值进行精确比较，更准确但速度较慢")
                
                Picker("默认冲突处理", selection: $configManager.config.conflictResolution) {
                    ForEach(ConflictResolution.allCases, id: \.self) { resolution in
                        Text(resolution.description).tag(resolution)
                    }
                }
                
                Stepper("最大并发传输: \(configManager.config.maxConcurrentTransfers)", 
                       value: $configManager.config.maxConcurrentTransfers,
                       in: 1...10)
                    .help("同时传输的最大文件数")
            }
            
            Section("设备设置") {
                Toggle("连接时自动扫描", isOn: $configManager.config.autoScanOnConnect)
                    .help("设备连接时自动扫描文件")
                
                Toggle("显示隐藏文件", isOn: $configManager.config.showHiddenFiles)
            }
            
            Section("路径设置") {
                HStack {
                    Text("默认目标路径:")
                    TextField("", text: $configManager.config.defaultTargetPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("浏览...") {
                        selectDefaultPath()
                    }
                }
            }
            
            Section("关于") {
                HStack {
                    Text("版本:")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("架构:")
                    Spacer()
                    #if arch(arm64)
                    Text("Apple Silicon (M 系列)")
                        .foregroundColor(.secondary)
                    #elseif arch(x86_64)
                    Text("Intel")
                        .foregroundColor(.secondary)
                    #else
                    Text("Unknown")
                        .foregroundColor(.secondary)
                    #endif
                }
                
                Button("检查 ADB 安装") {
                    checkADBInstallation()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: configManager.config) { _ in
            configManager.save()
        }
    }
    
    private func selectDefaultPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            configManager.config.defaultTargetPath = url.path
            configManager.save()
        }
    }
    
    private func checkADBInstallation() {
        Task {
            do {
                _ = try await ADBManager.shared.scanDevices()
                let alert = NSAlert()
                alert.messageText = "ADB 已安装"
                alert.informativeText = "ADB 工具运行正常"
                alert.alertStyle = .informational
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "ADB 未安装或配置错误"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}
