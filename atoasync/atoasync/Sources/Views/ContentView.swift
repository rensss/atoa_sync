import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var selectedTab: Int? = 0
    @State private var showADBNotInstalledAlert = false
    
    var body: some View {
        NavigationView {
            Sidebar(viewModel: viewModel, selectedTab: $selectedTab)
                .frame(minWidth: 200, maxWidth: 250)
            
            MainContent(viewModel: viewModel, selectedTab: selectedTab)
                .frame(minWidth: 600)
        }
        .navigationTitle("AtoA Sync")
        .toolbar {
            ToolbarItemGroup {
                // ADB 状态指示器
                if ADBManager.shared.isADBInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .help("ADB 已安装")
                } else {
                    Button {
                        showADBNotInstalledAlert = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                    .help("ADB 未安装")
                }
                
                Divider()
                
                if viewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Button(action: viewModel.scanDevices) {
                    Label("刷新设备", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning || !ADBManager.shared.isADBInstalled)
                
                Button(action: viewModel.scanFiles) {
                    Label("扫描文件", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(viewModel.selectedDevice == nil || viewModel.isScanning)
                
                Button(action: viewModel.startSync) {
                    Label("开始同步", systemImage: "arrow.down.circle.fill")
                }
                .disabled(viewModel.selectedFiles.isEmpty || viewModel.isSyncing)
            }
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .alert("ADB 未安装", isPresented: $showADBNotInstalledAlert) {
            Button("打开安装指南") {
                if let url = URL(string: "https://developer.android.com/tools/releases/platform-tools") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("使用 Homebrew 安装") {
                copyHomebrewCommand()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("未检测到 ADB 工具。\n\n您可以通过以下方式安装：\n1. 使用 Homebrew: brew install --cask android-platform-tools\n2. 从 Android 官网下载 Platform Tools")
        }
        .onAppear {
            checkADBInstallation()
        }
    }
    
    private func checkADBInstallation() {
        if ADBManager.shared.isADBInstalled {
            viewModel.scanDevices()
        } else {
            showADBNotInstalledAlert = true
        }
    }
    
    private func copyHomebrewCommand() {
        let command = "brew install --cask android-platform-tools"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        
        // 打开终端
        if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSWorkspace.shared.open(terminalURL)
        }
    }
}

struct Sidebar: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var selectedTab: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedTab) {
                Section("功能") {
                    NavigationLink(tag: 0, selection: $selectedTab) {
                        EmptyView()
                    } label: {
                        Label("设备同步", systemImage: "iphone.and.arrow.forward")
                    }
                    
                    NavigationLink(tag: 1, selection: $selectedTab) {
                        EmptyView()
                    } label: {
                        Label("同步任务", systemImage: "list.bullet.rectangle")
                    }
                    
                    NavigationLink(tag: 2, selection: $selectedTab) {
                        EmptyView()
                    } label: {
                        Label("日志", systemImage: "doc.text")
                    }
                    
                    NavigationLink(tag: 3, selection: $selectedTab) {
                        EmptyView()
                    } label: {
                        Label("设置", systemImage: "gear")
                    }
                }
                
                Section("已连接设备") {
                    ForEach(viewModel.devices) { device in
                        DeviceRow(device: device, isSelected: viewModel.selectedDevice?.id == device.id)
                            .onTapGesture {
                                viewModel.selectedDevice = device
                            }
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
    }
}

struct DeviceRow: View {
    let device: DeviceInfo
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "iphone")
                .foregroundColor(device.isConnected ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.system(size: 13))
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text(device.model)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if device.isConnected {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MainContent: View {
    @ObservedObject var viewModel: MainViewModel
    let selectedTab: Int?
    
    var body: some View {
        Group {
            switch selectedTab {
            case 0:
                SyncView(viewModel: viewModel)
            case 1:
                TasksView()
            case 2:
                LogsView()
            case 3:
                SettingsView()
            default:
                SyncView(viewModel: viewModel)
            }
        }
    }
}
