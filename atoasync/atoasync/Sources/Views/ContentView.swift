import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var selectedTab: Int = 0
    @State private var showADBSetupGuide = false
    @State private var showWiFiConnectionSheet = false
    
    var body: some View {
        HSplitView {
            // 左侧边栏
            SidebarView(viewModel: viewModel, selectedTab: $selectedTab)
                .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
            
            // 右侧主内容区
            VStack(spacing: 0) {
                // 顶部工具栏
                ToolbarView(
                    viewModel: viewModel,
                    showADBSetupGuide: $showADBSetupGuide,
                    showWiFiConnectionSheet: $showWiFiConnectionSheet
                )
                
                Divider()
                
                // 主内容
                MainContentView(viewModel: viewModel, selectedTab: selectedTab)
            }
            .frame(minWidth: 600)
        }
        .frame(minWidth: 900, minHeight: 600)
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
            ADBManager.shared.reloadADBPath()
            viewModel.scanDevices()
        }
    }
    
    private func checkADBInstallation() {
        ADBManager.shared.reloadADBPath()
        if ADBManager.shared.isADBInstalled {
            viewModel.scanDevices()
        } else {
            showADBSetupGuide = true
        }
    }
}

// MARK: - 顶部工具栏

struct ToolbarView: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var showADBSetupGuide: Bool
    @Binding var showWiFiConnectionSheet: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧标题
            Text("AtoA Sync")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // ADB 状态指示器
            ADBStatusIndicator(showSetupGuide: $showADBSetupGuide)
            
            Divider()
                .frame(height: 20)
            
            // 扫描进度
            if viewModel.isScanning {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("扫描中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 刷新设备按钮
            ToolbarButton(
                title: "刷新设备",
                icon: "arrow.clockwise",
                tooltip: "刷新已连接的 Android 设备列表",
                isDisabled: viewModel.isScanning || !ADBManager.shared.isADBInstalled
            ) {
                viewModel.scanDevices()
            }
            
            // Wi-Fi 连接按钮
            ToolbarButton(
                title: "Wi-Fi",
                icon: "wifi",
                tooltip: "通过 Wi-Fi 无线连接 Android 设备\n（需先用 USB 配对）",
                isDisabled: false
            ) {
                showWiFiConnectionSheet = true
            }
            
            // 扫描文件按钮
            ToolbarButton(
                title: "扫描文件",
                icon: "doc.text.magnifyingglass",
                tooltip: viewModel.selectedDevice == nil
                    ? "请先选择一个设备"
                    : "扫描设备和本地目录的文件\n进行差异比对",
                isDisabled: viewModel.selectedDevice == nil || viewModel.isScanning
            ) {
                viewModel.scanFiles()
            }
            
            // 开始同步按钮
            ToolbarButton(
                title: "开始同步",
                icon: "arrow.down.circle.fill",
                tooltip: viewModel.selectedFiles.isEmpty
                    ? "请先扫描文件并选择要同步的文件"
                    : "将选中的 \(viewModel.selectedFiles.count) 个文件\n从设备同步到本地",
                isDisabled: viewModel.selectedFiles.isEmpty || viewModel.isSyncing,
                isPrimary: true
            ) {
                viewModel.startSync()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - ADB 状态指示器

struct ADBStatusIndicator: View {
    @Binding var showSetupGuide: Bool
    @State private var isHovering = false
    
    var body: some View {
        Group {
            if ADBManager.shared.isADBInstalled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("ADB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                .help("ADB 已安装并正常工作")
            } else {
                Button {
                    showSetupGuide = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("ADB")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("ADB 未安装 - 点击查看安装指南")
            }
        }
    }
}

// MARK: - 工具栏按钮

struct ToolbarButton: View {
    let title: String
    let icon: String
    let tooltip: String
    let isDisabled: Bool
    var isPrimary: Bool = false
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(buttonBackground)
            .foregroundColor(buttonForeground)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isPrimary ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(tooltip)
    }
    
    private var buttonBackground: Color {
        if isPrimary {
            return Color.accentColor.opacity(isHovering ? 0.9 : 0.8)
        } else if isHovering {
            return Color(nsColor: .controlBackgroundColor)
        } else {
            return Color.clear
        }
    }
    
    private var buttonForeground: Color {
        if isPrimary {
            return .white
        } else {
            return .primary
        }
    }
}

// MARK: - 侧边栏

struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(SidebarItem.allCases) { item in
                        SidebarRow(item: item, isSelected: selectedTab == item.rawValue)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedTab = item.rawValue
                                }
                            }
                    }
                } header: {
                    Text("功能")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    if viewModel.devices.isEmpty {
                        HStack {
                            Image(systemName: "iphone.slash")
                                .foregroundColor(.secondary)
                            Text("暂无设备连接")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(viewModel.devices) { device in
                            DeviceRowView(
                                device: device,
                                isSelected: viewModel.selectedDevice?.id == device.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedDevice = device
                                selectedTab = 0
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("已连接设备")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.devices.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 侧边栏项目枚举

enum SidebarItem: Int, CaseIterable, Identifiable {
    case sync = 0
    case tasks = 1
    case history = 2
    case filters = 3
    case logs = 4
    case settings = 5
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .sync: return "设备同步"
        case .tasks: return "同步任务"
        case .history: return "同步历史"
        case .filters: return "过滤规则"
        case .logs: return "日志"
        case .settings: return "设置"
        }
    }
    
    var icon: String {
        switch self {
        case .sync: return "iphone.and.arrow.forward"
        case .tasks: return "list.bullet.rectangle"
        case .history: return "clock.arrow.circlepath"
        case .filters: return "line.3.horizontal.decrease.circle"
        case .logs: return "doc.text"
        case .settings: return "gear"
        }
    }
}

// MARK: - 侧边栏行

struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 20)
            
            Text(item.title)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .primary : .primary.opacity(0.8))
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - 设备行

struct DeviceRowView: View {
    let device: DeviceInfo
    let isSelected: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "iphone")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Circle()
                    .fill(device.isConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: 2)
            }
            .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                
                Text(device.model)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(device.connectionType.rawValue)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - 主内容区

struct MainContentView: View {
    @ObservedObject var viewModel: MainViewModel
    let selectedTab: Int
    
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
