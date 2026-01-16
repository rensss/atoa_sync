import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var selectedTab = 0
    
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
                if viewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Button(action: viewModel.scanDevices) {
                    Label("刷新设备", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning)
                
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
        .onAppear {
            viewModel.scanDevices()
        }
    }
}

struct Sidebar: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var selectedTab: Int
    
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
    let selectedTab: Int
    
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
                EmptyView()
            }
        }
    }
}
