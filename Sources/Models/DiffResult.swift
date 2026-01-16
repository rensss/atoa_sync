import Foundation

struct DiffResult {
    let newFiles: [FileInfo]
    let modifiedFiles: [FileInfo]
    let deletedFiles: [FileInfo]
    let unchangedFiles: [FileInfo]
    
    var totalChanges: Int {
        return newFiles.count + modifiedFiles.count + deletedFiles.count
    }
    
    var hasChanges: Bool {
        return totalChanges > 0
    }
    
    var summary: String {
        var parts: [String] = []
        if !newFiles.isEmpty {
            parts.append("\(newFiles.count) 个新文件")
        }
        if !modifiedFiles.isEmpty {
            parts.append("\(modifiedFiles.count) 个修改文件")
        }
        if !deletedFiles.isEmpty {
            parts.append("\(deletedFiles.count) 个删除文件")
        }
        
        return parts.isEmpty ? "无变化" : parts.joined(separator: ", ")
    }
    
    func filtered(by type: DiffType) -> [FileInfo] {
        switch type {
        case .new:
            return newFiles
        case .modified:
            return modifiedFiles
        case .deleted:
            return deletedFiles
        case .unchanged:
            return unchangedFiles
        case .all:
            return newFiles + modifiedFiles + deletedFiles
        }
    }
}

enum DiffType: String, CaseIterable {
    case all = "全部"
    case new = "新增"
    case modified = "修改"
    case deleted = "删除"
    case unchanged = "未改变"
    
    var systemImage: String {
        switch self {
        case .all:
            return "list.bullet"
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
}
