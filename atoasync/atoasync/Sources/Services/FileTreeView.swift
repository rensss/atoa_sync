import SwiftUI

/// 文件树视图 - 以树状结构展示文件
struct FileTreeView: View {
    let rootNodes: [FileTreeNode]
    @Binding var selectedFiles: Set<UUID>
    let diffResult: DiffResult?
    
    var body: some View {
        List {
            ForEach(rootNodes) { node in
                FileTreeNodeView(
                    node: node,
                    selectedFiles: $selectedFiles,
                    diffResult: diffResult,
                    indentLevel: 0
                )
            }
        }
        .listStyle(.sidebar)
    }
}

struct FileTreeNodeView: View {
    @ObservedObject var node: FileTreeNode
    @Binding var selectedFiles: Set<UUID>
    let diffResult: DiffResult?
    let indentLevel: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // 展开/折叠按钮
                if node.isDirectory && !node.children.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            node.isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 16)
                } else {
                    Spacer()
                        .frame(width: 16)
                }
                
                // 选择框（仅对文件）
                if !node.isDirectory, let fileInfo = node.fileInfo {
                    let isSyncable = isDiffSyncable(fileInfo)
                    
                    if isSyncable {
                        Toggle("", isOn: Binding(
                            get: { selectedFiles.contains(fileInfo.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedFiles.insert(fileInfo.id)
                                } else {
                                    selectedFiles.remove(fileInfo.id)
                                }
                            }
                        ))
                        .toggleStyle(CheckboxToggleStyle())
                    }
                }
                
                // 图标
                Image(systemName: node.icon)
                    .foregroundColor(iconColor)
                    .frame(width: 16)
                
                // 名称
                Text(node.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Spacer()
                
                // 文件大小和差异标签
                if !node.isDirectory, let fileInfo = node.fileInfo {
                    HStack(spacing: 8) {
                        Text(fileInfo.formattedSize)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        if let diffType = getDiffType(for: fileInfo) {
                            DiffTypeBadge(diffType: diffType)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.leading, CGFloat(indentLevel) * 16)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.isDirectory {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        node.isExpanded.toggle()
                    }
                }
            }
            
            // 子节点
            if node.isExpanded {
                ForEach(node.childrenArray) { childNode in
                    FileTreeNodeView(
                        node: childNode,
                        selectedFiles: $selectedFiles,
                        diffResult: diffResult,
                        indentLevel: indentLevel + 1
                    )
                }
            }
        }
    }
    
    private var iconColor: Color {
        if node.isDirectory {
            return .blue
        }
        
        if let fileInfo = node.fileInfo, let diffType = getDiffType(for: fileInfo) {
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
        
        return .secondary
    }
    
    private func getDiffType(for file: FileInfo) -> DiffType? {
        guard let diff = diffResult else { return nil }
        
        if diff.newFiles.contains(where: { $0.id == file.id }) {
            return .new
        } else if diff.modifiedFiles.contains(where: { $0.id == file.id }) {
            return .modified
        } else if diff.deletedFiles.contains(where: { $0.id == file.id }) {
            return .deleted
        }
        
        return .unchanged
    }
    
    private func isDiffSyncable(_ file: FileInfo) -> Bool {
        guard let diff = diffResult else { return false }
        
        return diff.newFiles.contains(where: { $0.id == file.id }) ||
               diff.modifiedFiles.contains(where: { $0.id == file.id })
    }
}

/// 差异类型标签
struct DiffTypeBadge: View {
    let diffType: DiffType
    
    var body: some View {
        Text(diffType.rawValue)
            .font(.system(size: 10))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch diffType {
        case .new:
            return .green
        case .modified:
            return .orange
        case .deleted:
            return .red
        case .unchanged:
            return .gray
        case .all:
            return .blue
        }
    }
}

/// 目录选择器视图
struct DirectoryBrowserView: View {
    @Binding var selectedPath: String
    @State private var isExpanded = true
    
    private let commonPaths: [(String, String, String)] = [
        ("桌面", "desktopcomputer", NSHomeDirectory() + "/Desktop"),
        ("文稿", "doc.text", NSHomeDirectory() + "/Documents"),
        ("下载", "arrow.down.circle", NSHomeDirectory() + "/Downloads"),
        ("图片", "photo", NSHomeDirectory() + "/Pictures"),
        ("音乐", "music.note", NSHomeDirectory() + "/Music"),
        ("影片", "film", NSHomeDirectory() + "/Movies")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                    Text("快速访问")
                        .font(.headline)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ForEach(commonPaths, id: \.2) { name, icon, path in
                    Button {
                        selectedPath = path
                    } label: {
                        HStack {
                            Image(systemName: icon)
                                .frame(width: 20)
                            Text(name)
                            Spacer()
                            if selectedPath == path {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.leading, 20)
                }
            }
        }
        .padding()
    }
}

/// 同步进度详情视图
struct SyncProgressDetailView: View {
    @ObservedObject var task: SyncTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                
                Text("同步进度")
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(status: task.status)
            }
            
            // 总体进度
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: task.progress) {
                    HStack {
                        Text("\(task.progressPercentage)%")
                        Spacer()
                        Text("\(task.processedFiles) / \(task.totalFiles) 文件")
                    }
                    .font(.system(size: 12))
                }
                
                // 数据传输量
                HStack {
                    Text("已传输:")
                    Text(task.formattedBytesTransferred)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("速度:")
                    Text(task.formattedSpeed)
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 12))
                
                // 剩余时间
                if let timeRemaining = task.estimatedTimeRemaining {
                    HStack {
                        Text("预计剩余时间:")
                        Text(task.formattedTimeRemaining)
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 12))
                }
            }
            
            // 当前文件
            if let currentFile = task.currentFile {
                VStack(alignment: .leading, spacing: 4) {
                    Text("正在同步:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(currentFile)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(2)
                }
            }
            
            // 控制按钮
            HStack {
                Spacer()
                
                if task.status == .running {
                    Button("暂停") {
                        Task {
                            await SyncManager.shared.pauseSync(taskId: task.id)
                        }
                    }
                    .buttonStyle(.bordered)
                } else if task.status == .paused {
                    Button("继续") {
                        Task {
                            try? await SyncManager.shared.resumeSync(taskId: task.id)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if task.status == .running || task.status == .paused {
                    Button("取消") {
                        Task {
                            await SyncManager.shared.cancelSync(taskId: task.id)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    VStack {
        DiffTypeBadge(diffType: .new)
        DiffTypeBadge(diffType: .modified)
        DiffTypeBadge(diffType: .deleted)
    }
    .padding()
}
