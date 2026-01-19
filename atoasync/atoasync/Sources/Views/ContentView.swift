import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var selectedTab: Int? = 0
    @State private var showADBSetupGuide = false
    @State private var showWiFiConnectionSheet = false
    
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
                        showADBSetupGuide = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                    .help("ADB 未安装 - 点击查看安装指南")
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
                
                Button {
                    showWiFiConnectionSheet = true
                } label: {
                    Label("Wi-Fi 连接", systemImage: "wifi")
                }
                .help("通过 Wi-Fi 连接安卓设备")
                
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
            Button("查看 ADB 设置") {
                showADBSetupGuide = true
            }
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .sheet(isPresented: $showADBSetupGuide) {
            ADBSetupGuideView()
                .frame(width: 600, height: 700)
        }
        .sheet(isPresented: $showWiFiConnectionSheet) {
            WiFiConnectionView()
        }
        .onAppear {
            checkADBInstallation()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scanDevices)) { _ in
            viewModel.scanDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scanFiles)) { _ in
            viewModel.scanFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: .startSync)) { _ in
            viewModel.startSync()
        }
        .onReceive(NotificationCenter.default.publisher(for: .adbSetupCompleted)) { _ in
            showADBSetupGuide = false
            // 刷新 ADB 路径后再扫描设备
            ADBManager.shared.reloadADBPath()
            viewModel.scanDevices()
        }
    }
    
    private func checkADBInstallation() {
        // 每次检查时都刷新 ADB 路径
        ADBManager.shared.reloadADBPath()
        if ADBManager.shared.isADBInstalled {
            viewModel.scanDevices()
        } else {
            showADBSetupGuide = true
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
                        Label("同步历史", systemImage: "clock.arrow.circlepath")
                    }
                    
                    NavigationLink(tag: 3, selection: $selectedTab) {
                        EmptyView()
                    } label: {
                        Label("过滤规则", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    
                    NavigationLink(tag: 4, selection: $selectedTab) {
                        EmptyView()
                    } label: {
                        Label("日志", systemImage: "doc.text")
                    }
                    
                    NavigationLink(tag: 5, selection: $selectedTab) {
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
                SyncHistoryView()
            case 3:
                FilterRulesView()
            case 4:
                LogsView()
            case 5:
                SettingsView()
            default:
                SyncView(viewModel: viewModel)
            }
        }
    }
}
