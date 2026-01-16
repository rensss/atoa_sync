import SwiftUI

struct SyncView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedDiffType: DiffType = .all
    
    var body: some View {
        VStack(spacing: 0) {
            ConfigurationBar(viewModel: viewModel)
            
            Divider()
            
            FilterBar(
                searchText: $viewModel.searchText,
                selectedDiffType: $selectedDiffType,
                selectedFileTypes: $viewModel.selectedFileTypes
            )
            
            Divider()
            
            if viewModel.isScanning {
                ScanningView(progress: viewModel.scanProgress)
            } else if viewModel.isComparing {
                ComparingView()
            } else if let diff = viewModel.filteredDiffResult {
                DiffResultView(
                    diffResult: diff,
                    selectedDiffType: selectedDiffType,
                    selectedFiles: $viewModel.selectedFiles,
                    onToggleSelection: viewModel.toggleFileSelection
                )
            } else {
                EmptyStateView()
            }
            
            Divider()
            
            ActionBar(viewModel: viewModel)
        }
    }
}

struct ConfigurationBar: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            Label("目标路径:", systemImage: "folder")
                .font(.system(size: 13))
            
            TextField("选择目标路径", text: $viewModel.targetPath)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            
            Button("浏览...") {
                viewModel.selectTargetPath()
            }
            
            Picker("冲突处理:", selection: $viewModel.conflictResolution) {
                ForEach(ConflictResolution.allCases, id: \.self) { resolution in
                    Text(resolution.rawValue).tag(resolution)
                }
            }
            .frame(width: 150)
        }
        .padding()
    }
}

struct FilterBar: View {
    @Binding var searchText: String
    @Binding var selectedDiffType: DiffType
    @Binding var selectedFileTypes: Set<FileType>
    
    var body: some View {
        HStack(spacing: 12) {
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
            
            Picker("类型", selection: $selectedDiffType) {
                ForEach(DiffType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.systemImage)
                        .tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 300)
            
            Menu {
                ForEach(FileType.allCases, id: \.self) { type in
                    Button {
                        toggleFileType(type)
                    } label: {
                        HStack {
                            Text(type.rawValue)
                            if selectedFileTypes.contains(type) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("文件类型", systemImage: "line.3.horizontal.decrease.circle")
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

struct DiffResultView: View {
    let diffResult: DiffResult
    let selectedDiffType: DiffType
    @Binding var selectedFiles: Set<UUID>
    let onToggleSelection: (UUID) -> Void
    
    var body: some View {
        let files = diffResult.filtered(by: selectedDiffType)
        
        VStack(spacing: 0) {
            HStack {
                Text("\(files.count) 个文件")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if selectedDiffType != .all && selectedDiffType != .unchanged && selectedDiffType != .deleted {
                    Button("全选") {
                        files.forEach { selectedFiles.insert($0.id) }
                    }
                    .buttonStyle(LinkButtonStyle())
                    
                    Button("取消全选") {
                        files.forEach { selectedFiles.remove($0.id) }
                    }
                    .buttonStyle(LinkButtonStyle())
                }
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
                        FileRow(
                            file: file,
                            diffType: getDiffType(for: file),
                            isSelected: selectedFiles.contains(file.id),
                            onToggle: {
                                onToggleSelection(file.id)
                            }
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

struct FileRow: View {
    let file: FileInfo
    let diffType: DiffType
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if diffType != .unchanged && diffType != .deleted {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(CheckboxToggleStyle())
            }
            
            Image(systemName: FileType.from(path: file.path).icon)
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.relativePath)
                    .font(.system(size: 13))
                
                HStack {
                    Text(file.formattedSize)
                    Text("•")
                    Text(file.formattedDate)
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Label(diffType.rawValue, systemImage: diffType.systemImage)
                .font(.system(size: 11))
                .foregroundColor(diffTypeColor)
        }
        .padding(.vertical, 4)
    }
    
    private var iconColor: Color {
        switch diffType {
        case .new:
            return .green
        case .modified:
            return .orange
        case .deleted:
            return .red
        default:
            return .secondary
        }
    }
    
    private var diffTypeColor: Color {
        switch diffType {
        case .new:
            return .green
        case .modified:
            return .orange
        case .deleted:
            return .red
        default:
            return .secondary
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .accentColor : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("选择设备并开始扫描")
                .font(.headline)
            
            Text("点击工具栏的「扫描文件」按钮开始")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ActionBar: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack {
            if let diff = viewModel.diffResult {
                Text(diff.summary)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("已选择 \(viewModel.selectedFiles.count) 个文件")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
