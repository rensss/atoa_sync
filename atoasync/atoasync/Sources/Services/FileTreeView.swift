import SwiftUI

/// 文件树视图 - 以树状结构展示文件
struct FileTreeView: View {
    let rootNodes: [FileTreeNode]
    @Binding var selectedFiles: Set<String>
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
    @Binding var selectedFiles: Set<String>
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
                        let key = normalizeKey(fileInfo.relativePath)
                        Toggle("", isOn: Binding(
                            get: { selectedFiles.contains(key) },
                            set: { isSelected in
                                if isSelected {
                                    selectedFiles.insert(key)
                                } else {
                                    selectedFiles.remove(key)
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
    
    private func normalizeKey(_ relativePath: String) -> String {
        if relativePath == "/" { return "" }
        if relativePath.hasPrefix("/") { return String(relativePath.dropFirst()) }
        return relativePath
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
        
        if diff.newFiles.contains(where: { $0.relativePath == file.relativePath }) {
            return .new
        } else if diff.modifiedFiles.contains(where: { $0.relativePath == file.relativePath }) {
            return .modified
        } else if diff.deletedFiles.contains(where: { $0.relativePath == file.relativePath }) {
            return .deleted
        }
        
        return .unchanged
    }
    
    private func isDiffSyncable(_ file: FileInfo) -> Bool {
        guard let diff = diffResult else { return false }
        
        return diff.newFiles.contains(where: { $0.relativePath == file.relativePath }) ||
               diff.modifiedFiles.contains(where: { $0.relativePath == file.relativePath })
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
