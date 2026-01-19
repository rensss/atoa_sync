import SwiftUI
import Combine

struct SyncView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedDiffType: DiffType = .all
    @State private var viewMode: ViewMode = .ready
    
    enum ViewMode {
        case ready       // 准备扫描
        case browse      // 浏览设备文件
        case diff        // 差异比对结果
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部配置栏
            ConfigurationBar(viewModel: viewModel, onBrowse: {
                viewMode = .browse
            })
            
            Divider()
            
            // 主内容区
            if viewModel.selectedDevice == nil {
                // 未选择设备
                NoDeviceSelectedView()
            } else if viewModel.targetPath.isEmpty {
                // 未设置目标路径
                NoTargetPathView(viewModel: viewModel)
            } else if viewModel.isScanning {
                // 扫描中
                ScanningView(progress: viewModel.scanProgress)
            } else if viewModel.isComparing {
                // 比对中
                ComparingView()
            } else if viewModel.isLoadingDirectory {
                // 加载目录中
                LoadingDirectoryView()
            } else if viewModel.isBrowsingMode {
                // 浏览模式：显示设备文件
                DeviceBrowserView(viewModel: viewModel)
            } else if let diff = viewModel.filteredDiffResult {
                // 显示差异结果
                VStack(spacing: 0) {
                    FilterBar(
                        searchText: $viewModel.searchText,
                        selectedDiffType: $selectedDiffType,
                        selectedFileTypes: $viewModel.selectedFileTypes
                    )
                    
                    Divider()
                    
                    DiffResultView(
                        diffResult: diff,
                        selectedDiffType: selectedDiffType,
                        selectedFiles: $viewModel.selectedFiles,
                        onToggleSelection: viewModel.toggleFileSelection,
                        onDirectoryTap: { file in
                            viewModel.enterDirectory(file)
                        }
                    )
                }
            } else {
                // 引导用户开始扫描
                ReadyToScanView(viewModel: viewModel)
            }
            
            Divider()
            
            // 底部状态栏
            StatusBar(viewModel: viewModel)
        }
    }
}

// MARK: - 加载目录视图

struct LoadingDirectoryView: View {
    @State private var loadingText = "正在加载目录..."
    @State private var dots = ""
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(loadingText + dots)
                .font(.headline)
            
            Text("如果目录包含大量文件，加载可能需要较长时间")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { _ in
            if dots.count >= 3 {
                dots = ""
            } else {
                dots += "."
            }
        }
    }
}

// MARK: - 设备文件浏览视图

struct DeviceBrowserView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 路径导航栏
            PathNavigationBar(viewModel: viewModel)
            
            Divider()
            
            // 文件列表
            if viewModel.deviceFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("目录为空")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.deviceFiles) { file in
                        BrowserFileRow(
                            file: file,
                            directorySize: viewModel.directorySizes[file.path],
                            isSelected: viewModel.selectedFiles.contains(file.id),
                            onToggleSelection: {
                                viewModel.toggleFileSelection(file.id)
                            }
                        ) {
                            if file.isDirectory {
                                viewModel.enterDirectory(file)
                            }
                        }
                    }
                }
            }
            
            // 底部选择状态栏
            if !viewModel.selectedFiles.isEmpty {
                Divider()
                BrowserSelectionBar(viewModel: viewModel)
            }
        }
    }
}

// MARK: - 浏览模式选择状态栏

struct BrowserSelectionBar: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack {
            // 选中数量
            Text("已选择 \(viewModel.selectedFiles.count) 个项目")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.accentColor)
            
            // 选中大小
            let selectedSize = calculateSelectedSize()
            Text("(\(formatBytes(selectedSize)))")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // 全选按钮
            Button("全选") {
                for file in viewModel.deviceFiles {
                    viewModel.selectedFiles.insert(file.id)
                }
            }
            .buttonStyle(.borderless)
            
            // 取消全选按钮
            Button("取消全选") {
                for file in viewModel.deviceFiles {
                    viewModel.selectedFiles.remove(file.id)
                }
            }
            .buttonStyle(.borderless)
            
            Divider()
                .frame(height: 16)
            
            // 同步按钮
            Button {
                viewModel.startBrowserSync()
            } label: {
                Label("同步选中", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSyncing || viewModel.targetPath.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func calculateSelectedSize() -> Int64 {
        var totalSize: Int64 = 0
        for file in viewModel.deviceFiles {
            if viewModel.selectedFiles.contains(file.id) {
                if file.isDirectory {
                    // 使用已计算的目录大小
                    if let dirSize = viewModel.directorySizes[file.path] {
                        totalSize += dirSize
                    }
                } else {
                    totalSize += file.size
                }
            }
        }
        return totalSize
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - 路径导航栏

struct PathNavigationBar: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            // 返回同步按钮
            Button {
                viewModel.exitBrowsingMode()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text("关闭浏览")
                }
                .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            
            Divider()
                .frame(height: 20)
            
            // 返回按钮
            Button {
                viewModel.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canGoBack)
            
            // 根目录按钮
            Button {
                viewModel.goToRoot()
            } label: {
                Image(systemName: "house")
            }
            .buttonStyle(.bordered)
            
            Divider()
                .frame(height: 20)
            
            // 面包屑导航
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(viewModel.pathComponents.enumerated()), id: \.offset) { index, component in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Button(component.name) {
                            // 导航到该路径
                            viewModel.currentDevicePath = component.path
                            viewModel.pathHistory = Array(viewModel.pathHistory.prefix(index))
                            viewModel.loadCurrentDirectory()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(index == viewModel.pathComponents.count - 1 ? .primary : .accentColor)
                    }
                }
            }
            
            Spacer()
            
            // 刷新按钮
            Button {
                viewModel.loadCurrentDirectory()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoadingDirectory)
            
            // 当前路径显示
            Text("\(viewModel.deviceFiles.count) 个项目")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - 浏览模式的文件行

struct BrowserFileRow: View {
    let file: FileInfo
    var directorySize: Int64?
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)?
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 选择框（文件和文件夹都显示）
            Button {
                onToggleSelection?()
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 文件图标
            Image(systemName: file.isDirectory ? "folder.fill" : FileType.from(path: file.path).icon)
                .font(.system(size: 20))
                .foregroundColor(file.isDirectory ? .blue : .secondary)
                .frame(width: 28)
            
            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 13, weight: file.isDirectory ? .medium : .regular))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // 显示大小
                    if file.isDirectory {
                        if let size = directorySize {
                            Text(formatBytes(size))
                        } else {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.5)
                                Text("计算中...")
                            }
                        }
                    } else {
                        Text(file.formattedSize)
                    }
                    
                    Text("•")
                    Text(file.formattedDate)
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 目录指示器（点击进入文件夹）
            if file.isDirectory {
                Button {
                    onTap()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // 点击行时进入文件夹（对于目录）或切换选中状态（对于文件）
            if file.isDirectory {
                onTap()
            } else {
                onToggleSelection?()
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - 配置栏

struct ConfigurationBar: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var sourcePath: String = "/sdcard"
    var onBrowse: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            // 设备信息行
            HStack(spacing: 16) {
                // 当前设备
                HStack(spacing: 8) {
                    Image(systemName: "iphone")
                        .foregroundColor(viewModel.selectedDevice != nil ? .green : .secondary)
                    
                    if let device = viewModel.selectedDevice {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.displayName)
                                .font(.system(size: 13, weight: .medium))
                            Text("Android \(device.androidVersion) • \(device.connectionType.rawValue)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("未选择设备")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                // 目标路径
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundColor(!viewModel.targetPath.isEmpty ? .blue : .secondary)
                    
                    TextField("选择本地目标路径", text: $viewModel.targetPath)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13))
                    
                    Button("浏览") {
                        viewModel.selectTargetPath()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
            
            // 选项行
            HStack(spacing: 16) {
                // 源路径（Android 设备路径）
                HStack(spacing: 8) {
                    Text("扫描路径:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    TextField("/sdcard", text: $sourcePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                }
                
                Spacer()
                
                // 冲突处理
                HStack(spacing: 8) {
                    Text("冲突处理:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $viewModel.conflictResolution) {
                        ForEach(ConflictResolution.allCases, id: \.self) { resolution in
                            Text(resolution.rawValue).tag(resolution)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
                
                // 浏览设备按钮
                Button {
                    viewModel.currentDevicePath = sourcePath
                    viewModel.loadCurrentDirectory()
                    onBrowse?()
                } label: {
                    Label("浏览设备", systemImage: "folder.badge.gearshape")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedDevice == nil || viewModel.isLoadingDirectory)
                
                // 扫描按钮
                Button {
                    viewModel.scanFiles()
                } label: {
                    Label("开始扫描", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedDevice == nil || viewModel.targetPath.isEmpty || viewModel.isScanning)
            }
        }
        .padding()
    }
}

// MARK: - 未选择设备视图

struct NoDeviceSelectedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("未选择设备")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("请在左侧边栏选择一个已连接的 Android 设备")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("确保设备已通过 USB 连接", systemImage: "cable.connector")
                Label("确保已启用 USB 调试模式", systemImage: "gear")
                Label("在设备上允许 USB 调试授权", systemImage: "checkmark.shield")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 未设置目标路径视图

struct NoTargetPathView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("请设置目标路径")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("选择一个本地文件夹来存放从设备同步的文件")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                viewModel.selectTargetPath()
            } label: {
                Label("选择文件夹", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 准备扫描视图

struct ReadyToScanView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // 设备信息卡片
            if let device = viewModel.selectedDevice {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.displayName)
                                .font(.headline)
                            Text("\(device.model) • Android \(device.androidVersion)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("已连接")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            Text(device.connectionType.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
                .frame(maxWidth: 400)
            }
            
            // 引导信息
            VStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("准备就绪")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("点击「开始扫描」按钮扫描设备文件\n并与本地目录进行差异比对")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // 扫描按钮
            Button {
                viewModel.scanFiles()
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("开始扫描")
                }
                .frame(width: 150)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isScanning)
            
            // 提示信息
            VStack(alignment: .leading, spacing: 6) {
                Label("将扫描设备的 /sdcard 目录", systemImage: "info.circle")
                Label("目标路径: \(viewModel.targetPath)", systemImage: "folder")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 过滤栏

struct FilterBar: View {
    @Binding var searchText: String
    @Binding var selectedDiffType: DiffType
    @Binding var selectedFileTypes: Set<FileType>
    
    var body: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索文件...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 250)
            
            // 类型选择器
            Picker("类型", selection: $selectedDiffType) {
                ForEach(DiffType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.systemImage)
                        .tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 350)
            
            Spacer()
            
            // 文件类型筛选
            Menu {
                Button("清除筛选") {
                    selectedFileTypes.removeAll()
                }
                .disabled(selectedFileTypes.isEmpty)
                
                Divider()
                
                ForEach(FileType.allCases, id: \.self) { type in
                    Button {
                        toggleFileType(type)
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                            Spacer()
                            if selectedFileTypes.contains(type) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(selectedFileTypes.isEmpty ? "文件类型" : "\(selectedFileTypes.count) 种")
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func toggleFileType(_ type: FileType) {
        if selectedFileTypes.contains(type) {
            selectedFileTypes.remove(type)
        } else {
            selectedFileTypes.insert(type)
        }
    }
}

// MARK: - 差异结果视图

struct DiffResultView: View {
    let diffResult: DiffResult
    let selectedDiffType: DiffType
    @Binding var selectedFiles: Set<UUID>
    let onToggleSelection: (UUID) -> Void
    var onDirectoryTap: ((FileInfo) -> Void)? = nil
    
    var body: some View {
        let files = diffResult.filtered(by: selectedDiffType)
        
        VStack(spacing: 0) {
            // 统计信息栏
            HStack {
                // 文件统计
                HStack(spacing: 16) {
                    StatBadge(count: diffResult.newFiles.count, label: "新增", color: .green)
                    StatBadge(count: diffResult.modifiedFiles.count, label: "修改", color: .orange)
                    StatBadge(count: diffResult.deletedFiles.count, label: "缺失", color: .red)
                    StatBadge(count: diffResult.unchangedFiles.count, label: "未变", color: .gray)
                }
                
                Spacer()
                
                // 选择操作
                if selectedDiffType == .new || selectedDiffType == .modified || selectedDiffType == .all {
                    HStack(spacing: 8) {
                        Button("全选") {
                            let selectableFiles = files.filter { file in
                                diffResult.newFiles.contains(where: { $0.id == file.id }) ||
                                diffResult.modifiedFiles.contains(where: { $0.id == file.id })
                            }
                            selectableFiles.forEach { selectedFiles.insert($0.id) }
                        }
                        .buttonStyle(.borderless)
                        
                        Button("取消全选") {
                            files.forEach { selectedFiles.remove($0.id) }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                Text("\(files.count) 个文件")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // 文件列表
            if files.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("没有\(selectedDiffType.rawValue)的文件")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(files) { file in
                        FileRow(
                            file: file,
                            diffType: getDiffType(for: file),
                            isSelected: selectedFiles.contains(file.id),
                            onToggle: {
                                onToggleSelection(file.id)
                            },
                            onDirectoryTap: file.isDirectory ? {
                                onDirectoryTap?(file)
                            } : nil
                        )
                    }
                }
            }
        }
    }
    
    private func getDiffType(for file: FileInfo) -> DiffType {
        if diffResult.newFiles.contains(where: { $0.id == file.id }) {
            return .new
        } else if diffResult.modifiedFiles.contains(where: { $0.id == file.id }) {
            return .modified
        } else if diffResult.deletedFiles.contains(where: { $0.id == file.id }) {
            return .deleted
        } else {
            return .unchanged
        }
    }
}

// MARK: - 统计徽章

struct StatBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count)")
                .font(.system(size: 12, weight: .medium))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 文件行

struct FileRow: View {
    let file: FileInfo
    let diffType: DiffType
    let isSelected: Bool
    let onToggle: () -> Void
    var onDirectoryTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // 选择框（仅对新增和修改的文件显示，且不是目录）
            if !file.isDirectory && (diffType == .new || diffType == .modified) {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(CheckboxToggleStyle())
            } else if file.isDirectory {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20)
            } else {
                Spacer()
                    .frame(width: 20)
            }
            
            // 文件图标
            if !file.isDirectory {
                Image(systemName: FileType.from(path: file.path).icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
            }
            
            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 13, weight: file.isDirectory ? .medium : .regular))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(file.formattedSize)
                    Text("•")
                    Text(file.formattedDate)
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 目录指示器
            if file.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                // 状态标签
                HStack(spacing: 4) {
                    Image(systemName: diffType.systemImage)
                    Text(diffType.rawValue)
                }
                .font(.system(size: 11))
                .foregroundColor(diffTypeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(diffTypeColor.opacity(0.1))
                .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if file.isDirectory {
                onDirectoryTap?()
            } else if diffType == .new || diffType == .modified {
                onToggle()
            }
        }
    }
    
    private var iconColor: Color {
        switch diffType {
        case .new: return .green
        case .modified: return .orange
        case .deleted: return .red
        default: return .secondary
        }
    }
    
    private var diffTypeColor: Color {
        switch diffType {
        case .new: return .green
        case .modified: return .orange
        case .deleted: return .red
        default: return .secondary
        }
    }
}

// MARK: - 复选框样式

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 16))
                .foregroundColor(configuration.isOn ? .accentColor : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 扫描中视图

struct ScanningView: View {
    let progress: Int
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在扫描文件...")
                .font(.headline)
            
            if progress > 0 {
                Text("已扫描 \(progress) 个文件")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("请耐心等待，扫描时间取决于文件数量")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 比对中视图

struct ComparingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在比对差异...")
                .font(.headline)
            
            Text("正在分析设备文件与本地文件的差异")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 底部状态栏

struct StatusBar: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack {
            // 左侧：状态信息
            Group {
                if viewModel.isScanning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("正在扫描...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.isComparing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("正在比对...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.isSyncing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("正在同步...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else if let diff = viewModel.diffResult {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.secondary)
                        Text(diff.summary)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.selectedDevice != nil && !viewModel.targetPath.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("点击「开始扫描」扫描设备文件")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("请选择设备和目标路径")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 右侧：选择信息和同步按钮
            if let diff = viewModel.diffResult {
                HStack(spacing: 12) {
                    // 显示可同步的文件总数
                    let syncableCount = diff.newFiles.count + diff.modifiedFiles.count
                    if syncableCount > 0 {
                        Text("可同步: \(syncableCount) 个文件")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // 显示已选择的文件数量
                    if !viewModel.selectedFiles.isEmpty {
                        Text("已选择: \(viewModel.selectedFiles.count) 个")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentColor)
                        
                        let selectedSize = calculateSelectedSize(diff: diff)
                        Text("(\(formatBytes(selectedSize)))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Button {
                            viewModel.startSync()
                        } label: {
                            Label("开始同步", systemImage: "arrow.down.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isSyncing)
                    } else if syncableCount > 0 {
                        Text("请选择要同步的文件")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func calculateSelectedSize(diff: DiffResult) -> Int64 {
        let selectedNewFiles = diff.newFiles.filter { viewModel.selectedFiles.contains($0.id) }
        let selectedModifiedFiles = diff.modifiedFiles.filter { viewModel.selectedFiles.contains($0.id) }
        return selectedNewFiles.reduce(0) { $0 + $1.size } + selectedModifiedFiles.reduce(0) { $0 + $1.size }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
