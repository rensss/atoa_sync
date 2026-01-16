import Foundation

// MARK: - 差异比对结果

/// 差异比对结果
struct DiffResult: Equatable {
    /// 新增文件：设备存在，本地不存在
    let newFiles: [FileInfo]
    
    /// 修改文件：路径存在，但大小或修改时间/哈希不同
    let modifiedFiles: [FileInfo]
    
    /// 缺失文件：本地存在，设备不存在
    let deletedFiles: [FileInfo]
    
    /// 未改变的文件
    let unchangedFiles: [FileInfo]
    
    /// 空结果
    static let empty = DiffResult(
        newFiles: [],
        modifiedFiles: [],
        deletedFiles: [],
        unchangedFiles: []
    )
    
    /// 总文件数
    var totalCount: Int {
        newFiles.count + modifiedFiles.count + deletedFiles.count + unchangedFiles.count
    }
    
    /// 总变化数
    var totalChanges: Int {
        newFiles.count + modifiedFiles.count + deletedFiles.count
    }
    
    /// 是否有变化
    var hasChanges: Bool {
        totalChanges > 0
    }
    
    /// 需要同步的文件数（新增 + 修改）
    var syncableCount: Int {
        newFiles.count + modifiedFiles.count
    }
    
    /// 需要同步的总字节数
    var syncableBytes: Int64 {
        let newBytes = newFiles.reduce(0) { $0 + $1.size }
        let modifiedBytes = modifiedFiles.reduce(0) { $0 + $1.size }
        return newBytes + modifiedBytes
    }
    
    /// 摘要信息
    var summary: String {
        var parts: [String] = []
        
        if !newFiles.isEmpty {
            parts.append("\(newFiles.count) 个新增")
        }
        if !modifiedFiles.isEmpty {
            parts.append("\(modifiedFiles.count) 个修改")
        }
        if !deletedFiles.isEmpty {
            parts.append("\(deletedFiles.count) 个缺失")
        }
        if !unchangedFiles.isEmpty {
            parts.append("\(unchangedFiles.count) 个未变")
        }
        
        if parts.isEmpty {
            return "没有文件"
        }
        
        return parts.joined(separator: "，")
    }
    
    /// 格式化可同步大小
    var formattedSyncableSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: syncableBytes)
    }
    
    /// 根据差异类型过滤文件
    func filtered(by diffType: DiffType) -> [FileInfo] {
        switch diffType {
        case .all:
            return newFiles + modifiedFiles + deletedFiles + unchangedFiles
        case .new:
            return newFiles
        case .modified:
            return modifiedFiles
        case .deleted:
            return deletedFiles
        case .unchanged:
            return unchangedFiles
        }
    }
    
    /// 获取所有可同步的文件
    var syncableFiles: [FileInfo] {
        return newFiles + modifiedFiles
    }
}

// MARK: - 差异类型

/// 差异类型枚举
enum DiffType: String, CaseIterable, Equatable {
    case all = "全部"
    case new = "新增"
    case modified = "修改"
    case deleted = "缺失"
    case unchanged = "未变"
    
    /// SF Symbol 图标名称
    var systemImage: String {
        switch self {
        case .all:
            return "square.stack.3d.up"
        case .new:
            return "plus.circle"
        case .modified:
            return "pencil.circle"
        case .deleted:
            return "minus.circle"
        case .unchanged:
            return "checkmark.circle"
        }
    }
    
    /// 填充版本的 SF Symbol 图标
    var systemImageFill: String {
        switch self {
        case .all:
            return "square.stack.3d.up.fill"
        case .new:
            return "plus.circle.fill"
        case .modified:
            return "pencil.circle.fill"
        case .deleted:
            return "minus.circle.fill"
        case .unchanged:
            return "checkmark.circle.fill"
        }
    }
    
    /// 颜色名称
    var color: String {
        switch self {
        case .all:
            return "primary"
        case .new:
            return "green"
        case .modified:
            return "orange"
        case .deleted:
            return "red"
        case .unchanged:
            return "gray"
        }
    }
}
