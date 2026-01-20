import SwiftUI
import Combine

struct SyncView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedDiffType: DiffType = .all

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：同步配置/操作（替代缺失的 ConfigurationBar）
            SyncHeaderBar(viewModel: viewModel)

            Divider()

            // 主内容区状态机
            if let task = viewModel.activeSyncTask {
                SyncingView(
                    syncTask: task,
                    onPause: { viewModel.pauseSync() },
                    onResume: { viewModel.resumeSync() },
                    onCancel: { viewModel.cancelSync() }
                )
            } else if let result = viewModel.lastSyncResult {
                SyncCompleteView(result: result) {
                    viewModel.dismissSyncResult()
                }
            } else if viewModel.selectedDevice == nil {
                NoDeviceSelectedPlaceholder()
            } else if viewModel.targetPath.isEmpty {
                NoTargetPathPlaceholder(viewModel: viewModel)
            } else if viewModel.isScanning {
                ScanningView(progress: viewModel.scanProgress) {
                    viewModel.cancelScanning()
                }
            } else if viewModel.isComparing {
                ComparingView()
            } else if let diff = viewModel.filteredDiffResult {
                if viewModel.isBrowsing {
                    DeviceBrowserView(viewModel: viewModel)
                } else {
                    VStack(spacing: 0) {
                        // 过滤栏（替代缺失的 FilterBar）
                        FilterBarInline(
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
                            },
                            viewModel: viewModel // 注入 viewModel 以便获取目录大小
                        )
                    }
                }
            } else {
                ReadyToScanPlaceholder(viewModel: viewModel)
            }

            Divider()

            // 底部状态栏（替代缺失的 StatusBar）
            SyncStatusBarInline(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 顶部操作栏（替代 ConfigurationBar）

private struct SyncHeaderBar: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedDevice?.displayName ?? "未选择设备")
                    .font(.system(size: 13, weight: .semibold))

                Text("扫描根目录: /sdcard")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Divider().frame(height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("目标路径")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(viewModel.targetPath.isEmpty ? "未选择" : viewModel.targetPath)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()

            Button("选择目标路径…") {
                viewModel.selectTargetPath()
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.scanFiles()
            } label: {
                Label("扫描并比对", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedDevice == nil || viewModel.targetPath.isEmpty || viewModel.isScanning || viewModel.activeSyncTask != nil)

            Button {
                viewModel.loadCurrentDirectory()
            } label: {
                Label("浏览设备", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedDevice == nil || viewModel.isLoadingDirectory || viewModel.activeSyncTask != nil)

            Button {
                viewModel.startSync()
            } label: {
                Label("开始同步", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedFiles.isEmpty || viewModel.activeSyncTask != nil || viewModel.targetPath.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - 缺失视图的占位替代（NoDeviceSelectedView / NoTargetPathView / ReadyToScanView）

private struct NoDeviceSelectedPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("未选择设备")
                .font(.headline)

            Text("请在左侧“已连接设备”中选择一个设备")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NoTargetPathPlaceholder: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("未选择目标路径")
                .font(.headline)

            Text("请选择一个本地目录作为同步目标")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("选择目标路径…") {
                viewModel.selectTargetPath()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReadyToScanPlaceholder: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("准备就绪")
                .font(.headline)

            Text("点击“扫描并比对”生成差异列表，然后选择需要同步的文件")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                viewModel.scanFiles()
            } label: {
                Label("扫描并比对", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedDevice == nil || viewModel.targetPath.isEmpty || viewModel.isScanning)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 内联过滤栏（替代 FilterBar）

private struct FilterBarInline: View {
    @Binding var searchText: String
    @Binding var selectedDiffType: DiffType
    @Binding var selectedFileTypes: Set<FileType>

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索路径/文件名…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)

            Picker("差异", selection: $selectedDiffType) {
                ForEach(DiffType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            Menu {
                Button("清空类型过滤") { selectedFileTypes.removeAll() }
                Divider()
                ForEach(FileType.allCases, id: \.self) { type in
                    Button {
                        if selectedFileTypes.contains(type) {
                            selectedFileTypes.remove(type)
                        } else {
                            selectedFileTypes.insert(type)
                        }
                    } label: {
                        if selectedFileTypes.contains(type) {
                            Label(type.rawValue, systemImage: "checkmark")
                        } else {
                            Text(type.rawValue)
                        }
                    }
                }
            } label: {
                Label(
                    selectedFileTypes.isEmpty ? "文件类型：全部" : "文件类型：\(selectedFileTypes.count)",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - 内联状态栏（替代 StatusBar）

private struct SyncStatusBarInline: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let task = viewModel.activeSyncTask {
                    Label("\(task.status.rawValue)…", systemImage: "arrow.down.circle")
                } else if viewModel.isScanning {
                    Label("扫描中… \(viewModel.scanProgress)", systemImage: "magnifyingglass")
                } else if viewModel.isComparing {
                    Label("比对中…", systemImage: "arrow.triangle.2.circlepath")
                } else {
                    Label("就绪", systemImage: "checkmark.circle")
                }
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)

            Spacer()

            if let diff = viewModel.diffResult, viewModel.activeSyncTask == nil {
                Text("差异：\(diff.summary)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - 加载目录视图

struct LoadingDirectoryView: View {
    @State private var loadingText = "正在加载目录..."
    @State private var dots = ""
    var onCancel: (() -> Void)? = nil

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
            
            if let onCancel {
                Button("取消加载", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
            }
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
            PathNavigationBar(viewModel: viewModel)

            Divider()

            if viewModel.isLoadingDirectory {
                LoadingDirectoryView {
                    viewModel.cancelLoadingDirectory()
                }
            } else if viewModel.deviceFiles.isEmpty {
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
                        let key = selectionKey(for: file)

                        BrowserFileRow(
                            file: file,
                            directorySize: viewModel.directorySizes[file.path],
                            isLoadingSize: viewModel.isLoadingSize(for: file.path),
                            isFailedSize: viewModel.isFailedSize(for: file.path),
                            isSelected: viewModel.selectedFiles.contains(key),
                            onToggleSelection: {
                                viewModel.toggleFileSelection(key)
                            },
                            onRetryDirectorySize: {
                                viewModel.loadDirectorySize(for: file)
                            }
                        ) {
                            if file.isDirectory {
                                viewModel.enterDirectory(file)
                            }
                        }
                    }
                }
            }

            if !viewModel.selectedFiles.isEmpty {
                Divider()
                BrowserSelectionBar(viewModel: viewModel, selectionKey: selectionKey(for:))
            }
        }
    }

    private func selectionKey(for file: FileInfo) -> String {
        let full = file.path

        if let range = full.range(of: "/storage/self/primary/") {
            return String(full[range.upperBound...])
        }
        if let range = full.range(of: "/sdcard/") {
            return String(full[range.upperBound...])
        }

        var rel = file.relativePath
        if rel == "/" { return "" }
        if rel.hasPrefix("/") { rel.removeFirst() }
        return rel
    }
}

// MARK: - 浏览模式选择状态栏

struct BrowserSelectionBar: View {
    @ObservedObject var viewModel: MainViewModel
    let selectionKey: (FileInfo) -> String

    var body: some View {
        HStack {
            Text("已选择 \(viewModel.selectedFiles.count) 个项目")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.accentColor)

            Spacer()

            Button("全选") {
                for file in viewModel.deviceFiles {
                    viewModel.selectedFiles.insert(selectionKey(file))
                }
            }
            .buttonStyle(.borderless)

            Button("取消全选") {
                for file in viewModel.deviceFiles {
                    viewModel.selectedFiles.remove(selectionKey(file))
                }
            }
            .buttonStyle(.borderless)

            Divider()
                .frame(height: 16)

            Button {
                viewModel.startSync()
            } label: {
                Label("同步选中", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.activeSyncTask != nil || viewModel.targetPath.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - 路径导航栏

struct PathNavigationBar: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if viewModel.canGoBack {
                    viewModel.goBack()
                } else {
                    viewModel.exitBrowsingMode()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text(viewModel.canGoBack ? "返回上一级" : "关闭浏览")
                }
                .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            Divider()
                .frame(height: 20)

            Button {
                viewModel.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canGoBack)

            Button {
                viewModel.goToRoot()
            } label: {
                Image(systemName: "house")
            }
            .buttonStyle(.bordered)

            Divider()
                .frame(height: 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(viewModel.pathComponents.enumerated()), id: \.offset) { index, component in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Button(component.name) {
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

            Button {
                viewModel.loadCurrentDirectory()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoadingDirectory)

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
    var isLoadingSize: Bool
    var isFailedSize: Bool
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)?
    var onRetryDirectorySize: (() -> Void)?
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggleSelection?()
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(PlainButtonStyle())

            Image(systemName: file.isDirectory ? "folder.fill" : FileType.from(path: file.path).icon)
                .font(.system(size: 20))
                .foregroundColor(file.isDirectory ? .blue : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 13, weight: file.isDirectory ? .medium : .regular))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if file.isDirectory {
                        directorySizeView
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
            onToggleSelection?()
        }
        .onAppear {
            if file.isDirectory && directorySize == nil && !isLoadingSize && !isFailedSize {
                onRetryDirectorySize?()
            }
        }
    }

    @ViewBuilder
    private var directorySizeView: some View {
        if let size = directorySize {
            Text(formatBytes(size))
        } else if isLoadingSize {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                Text("计算中...")
            }
        } else if isFailedSize {
            Button {
                onRetryDirectorySize?()
            } label: {
                Text("无法计算")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("目录大小计算失败，点击重试")
        } else {
            Button {
                onRetryDirectorySize?()
            } label: {
                Text("计算大小")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("点击计算目录总大小（du）")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - 差异结果视图（选择机制：Set<String> relativePath）

struct DiffResultView: View {
    let diffResult: DiffResult
    let selectedDiffType: DiffType
    @Binding var selectedFiles: Set<String>
    let onToggleSelection: (String) -> Void
    var onDirectoryTap: ((FileInfo) -> Void)? = nil

    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        let files = diffResult.filtered(by: selectedDiffType)

        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 16) {
                    StatBadge(count: diffResult.newFiles.count, label: "新增", color: .green)
                    StatBadge(count: diffResult.modifiedFiles.count, label: "修改", color: .orange)
                    StatBadge(count: diffResult.deletedFiles.count, label: "缺失", color: .red)
                    StatBadge(count: diffResult.unchangedFiles.count, label: "未变", color: .gray)
                }

                Spacer()

                if selectedDiffType == .new || selectedDiffType == .modified || selectedDiffType == .all {
                    HStack(spacing: 8) {
                        Button("全选") {
                            let selectableFiles = files.filter { file in
                                diffResult.newFiles.contains(where: { $0.relativePath == file.relativePath }) ||
                                diffResult.modifiedFiles.contains(where: { $0.relativePath == file.relativePath })
                            }
                            selectableFiles.forEach { selectedFiles.insert(normalizeKey($0.relativePath)) }
                        }
                        .buttonStyle(.borderless)

                        Button("取消全选") {
                            files.forEach { selectedFiles.remove(normalizeKey($0.relativePath)) }
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
                        let key = normalizeKey(file.relativePath)
                        FileRow(
                            file: file,
                            diffType: getDiffType(for: file),
                            isSelected: selectedFiles.contains(key),
                            onToggle: {
                                onToggleSelection(key)
                            },
                            onDirectoryTap: file.isDirectory ? {
                                onDirectoryTap?(file)
                            } : nil,
                            viewModel: viewModel // 传入 viewModel 以显示目录大小
                        )
                    }
                }
            }
        }
    }

    private func normalizeKey(_ relativePath: String) -> String {
        if relativePath == "/" { return "" }
        if relativePath.hasPrefix("/") { return String(relativePath.dropFirst()) }
        return relativePath
    }

    private func getDiffType(for file: FileInfo) -> DiffType {
        if diffResult.newFiles.contains(where: { $0.relativePath == file.relativePath }) {
            return .new
        } else if diffResult.modifiedFiles.contains(where: { $0.relativePath == file.relativePath }) {
            return .modified
        } else if diffResult.deletedFiles.contains(where: { $0.relativePath == file.relativePath }) {
            return .deleted
        } else {
            return .unchanged
        }
    }
}

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

struct FileRow: View {
    let file: FileInfo
    let diffType: DiffType
    let isSelected: Bool
    let onToggle: () -> Void
    var onDirectoryTap: (() -> Void)? = nil

    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        HStack(spacing: 12) {
            // 为“新增”或“修改”状态的文件和目录显示复选框
            if diffType == .new || diffType == .modified {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(CheckboxToggleStyle())
            } else {
                // 为不可选中的项保留空间以对齐
                Spacer().frame(width: 20)
            }

            // 文件/目录图标
            Image(systemName: file.isDirectory ? "folder.fill" : FileType.from(path: file.path).icon)
                .font(.system(size: 16))
                .foregroundColor(file.isDirectory ? .blue : iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 13, weight: file.isDirectory ? .medium : .regular))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if file.isDirectory {
                        // 目录时优先展示 viewModel 中缓存的目录大小；没有再显示计算按钮 / 状态
                        if let formatted = viewModel.formattedDirectorySize(for: file.path) {
                            Text(formatted)
                        } else if viewModel.isLoadingSize(for: file.path) {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.5)
                                Text("计算中...")
                            }
                        } else if viewModel.isFailedSize(for: file.path) {
                            Button {
                                viewModel.loadDirectorySize(for: file)
                            } label: {
                                Text("无法计算")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("目录大小计算失败，点击重试")
                        } else {
                            Button {
                                viewModel.loadDirectorySize(for: file)
                            } label: {
                                Text("--")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("点击计算目录总大小（du）")
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

            if file.isDirectory {
                Button {
                    onDirectoryTap?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
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
            // 仅当项目是“新增”或“修改”时，点击行本身切换选中状态
            if diffType == .new || diffType == .modified {
                onToggle()
            }
        }
        .onAppear {
            if file.isDirectory {
                if viewModel.directorySizes[file.path] == nil &&
                   !viewModel.isLoadingSize(for: file.path) &&
                   !viewModel.isFailedSize(for: file.path) {
                    viewModel.loadDirectorySize(for: file)
                }
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

// MARK: - 扫描中视图（新增取消按钮）

struct ScanningView: View {
    let progress: Int
    let onCancel: () -> Void

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

            Button(role: .cancel) {
                onCancel()
            } label: {
                Label("取消扫描", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

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

// MARK: - 同步视图

struct SyncingView: View {
    @ObservedObject var syncTask: SyncTask
    var onPause: () -> Void
    var onResume: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("正在同步...")
                .font(.largeTitle)
                .fontWeight(.light)
            
            VStack(spacing: 8) {
                HStack {
                    Text("总体进度")
                    Spacer()
                    Text("\(syncTask.progressPercentage)%")
                }
                .font(.subheadline)
                
                ProgressView(value: syncTask.progress)
                    .progressViewStyle(.linear)
            }
            .padding(.horizontal, 40)
            
            Text(syncTask.currentFile ?? "正在准备文件...")
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)
            
            Divider()
            
            HStack(spacing: 30) {
                StatItem(label: "已同步", value: "\(syncTask.processedFiles) / \(syncTask.totalFiles)")
                StatItem(label: "大小", value: syncTask.formattedBytesTransferred)
                StatItem(label: "速度", value: syncTask.formattedSpeed)
                StatItem(label: "剩余时间", value: syncTask.formattedTimeRemaining)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if syncTask.status == .paused {
                    Button(action: onResume) {
                        Label("继续", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("r")
                } else {
                    Button(action: onPause) {
                        Label("暂停", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("p")
                }
                
                Button("取消", role: .cancel, action: onCancel)
                    .keyboardShortcut(.escape)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private struct StatItem: View {
        let label: String
        let value: String
        
        var body: some View {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(minWidth: 100)
        }
    }
}

struct SyncCompleteView: View {
    let result: SyncHistoryEntry
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: result.status.icon)
                .font(.system(size: 60))
                .foregroundColor(statusColor)

            Text("同步\(result.status.rawValue)")
                .font(.largeTitle)
                .fontWeight(.light)

            if let errorMessage = result.errorMessage, result.status == .failed {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(maxWidth: 400)
            }

            Divider()
                .frame(width: 300)

            VStack(alignment: .leading, spacing: 12) {
                SummaryRow(label: "同步文件", value: "\(result.filesCount) 个")
                SummaryRow(label: "总大小", value: result.formattedBytes)
                SummaryRow(label: "耗时", value: result.formattedDuration)
                SummaryRow(label: "目标目录", value: result.targetPath)
            }
            .frame(width: 350)

            Spacer()
            
            Button("完成") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusColor: Color {
        switch result.status {
        case .success: .green
        case .failed: .red
        case .cancelled: .orange
        }
    }
    
    private struct SummaryRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text(label)
                    .font(.callout)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

