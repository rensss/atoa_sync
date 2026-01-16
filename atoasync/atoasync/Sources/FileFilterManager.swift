import Foundation
import Combine

/// 文件过滤规则管理器 - 支持正则表达式过滤
class FileFilterManager: ObservableObject {
    static let shared = FileFilterManager()
    
    @Published var rules: [FilterRule] = []
    @Published var presets: [FilterPreset] = []
    
    private let rulesFileURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("AtoASync", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        self.rulesFileURL = appDirectory.appendingPathComponent("filter_rules.json")
        
        loadRules()
        setupDefaultPresets()
    }
    
    // MARK: - 预设规则
    
    private func setupDefaultPresets() {
        presets = [
            FilterPreset(
                name: "仅图片",
                description: "只同步图片文件",
                rules: [
                    FilterRule(pattern: ".*\\.(jpg|jpeg|png|gif|bmp|heic|webp)$", type: .include, isRegex: true)
                ]
            ),
            FilterPreset(
                name: "仅视频",
                description: "只同步视频文件",
                rules: [
                    FilterRule(pattern: ".*\\.(mp4|mov|avi|mkv|flv|wmv|m4v)$", type: .include, isRegex: true)
                ]
            ),
            FilterPreset(
                name: "仅音频",
                description: "只同步音频文件",
                rules: [
                    FilterRule(pattern: ".*\\.(mp3|m4a|wav|flac|aac|ogg|wma)$", type: .include, isRegex: true)
                ]
            ),
            FilterPreset(
                name: "仅文档",
                description: "只同步文档文件",
                rules: [
                    FilterRule(pattern: ".*\\.(pdf|doc|docx|xls|xlsx|ppt|pptx|txt)$", type: .include, isRegex: true)
                ]
            ),
            FilterPreset(
                name: "排除缓存",
                description: "排除常见缓存和临时文件",
                rules: [
                    FilterRule(pattern: ".*\\.cache$", type: .exclude, isRegex: true),
                    FilterRule(pattern: ".*\\.tmp$", type: .exclude, isRegex: true),
                    FilterRule(pattern: ".*\\.log$", type: .exclude, isRegex: true),
                    FilterRule(pattern: ".*/\\.thumbnails/.*", type: .exclude, isRegex: true),
                    FilterRule(pattern: ".*/Android/data/.*", type: .exclude, isRegex: true)
                ]
            ),
            FilterPreset(
                name: "相机照片",
                description: "只同步相机拍摄的照片",
                rules: [
                    FilterRule(pattern: ".*/DCIM/.*\\.(jpg|jpeg|png|heic)$", type: .include, isRegex: true)
                ]
            ),
            FilterPreset(
                name: "微信文件",
                description: "同步微信接收的文件",
                rules: [
                    FilterRule(pattern: ".*/tencent/MicroMsg/.*", type: .include, isRegex: true)
                ]
            )
        ]
    }
    
    // MARK: - 规则管理
    
    func addRule(_ rule: FilterRule) {
        rules.append(rule)
        saveRules()
    }
    
    func removeRule(at index: Int) {
        guard index < rules.count else { return }
        rules.remove(at: index)
        saveRules()
    }
    
    func updateRule(at index: Int, with rule: FilterRule) {
        guard index < rules.count else { return }
        rules[index] = rule
        saveRules()
    }
    
    func moveRule(from source: IndexSet, to destination: Int) {
        var updatedRules = rules
        let itemsToMove = source.map { updatedRules[$0] }
        
        // Remove items from highest index first to avoid index shifting issues
        for index in source.sorted().reversed() {
            updatedRules.remove(at: index)
        }
        
        // Calculate the adjusted destination index
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        
        // Insert items at the destination
        for (offset, item) in itemsToMove.enumerated() {
            updatedRules.insert(item, at: adjustedDestination + offset)
        }
        
        rules = updatedRules
        saveRules()
    }
    
    func applyPreset(_ preset: FilterPreset) {
        rules = preset.rules
        saveRules()
    }
    
    func clearRules() {
        rules.removeAll()
        saveRules()
    }
    
    // MARK: - 文件过滤
    
    func shouldIncludeFile(_ file: FileInfo) -> Bool {
        return shouldIncludePath(file.relativePath)
    }
    
    func shouldIncludePath(_ path: String) -> Bool {
        // 如果没有规则，包含所有文件
        if rules.isEmpty {
            return true
        }
        
        // 分离包含和排除规则
        let includeRules = rules.filter { $0.type == .include && $0.isEnabled }
        let excludeRules = rules.filter { $0.type == .exclude && $0.isEnabled }
        
        // 首先检查排除规则
        for rule in excludeRules {
            if rule.matches(path) {
                return false
            }
        }
        
        // 如果有包含规则，文件必须匹配至少一个
        if !includeRules.isEmpty {
            for rule in includeRules {
                if rule.matches(path) {
                    return true
                }
            }
            return false
        }
        
        // 没有包含规则，且未被排除，则包含
        return true
    }
    
    func filterFiles(_ files: [FileInfo]) -> [FileInfo] {
        return files.filter { shouldIncludeFile($0) }
    }
    
    // MARK: - 持久化
    
    private func loadRules() {
        guard FileManager.default.fileExists(atPath: rulesFileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: rulesFileURL)
            rules = try JSONDecoder().decode([FilterRule].self, from: data)
        } catch {
            LogManager.shared.log("加载过滤规则失败: \(error.localizedDescription)", level: .error, category: "Filter")
        }
    }
    
    private func saveRules() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(rules)
            try data.write(to: rulesFileURL)
        } catch {
            LogManager.shared.log("保存过滤规则失败: \(error.localizedDescription)", level: .error, category: "Filter")
        }
    }
    
    // MARK: - 规则验证
    
    func validateRegex(_ pattern: String) -> Bool {
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            return true
        } catch {
            return false
        }
    }
}

// MARK: - 过滤规则

struct FilterRule: Identifiable, Codable, Equatable {
    let id: UUID
    var pattern: String
    var type: FilterRuleType
    var isRegex: Bool
    var isEnabled: Bool
    var description: String
    
    init(
        pattern: String,
        type: FilterRuleType,
        isRegex: Bool = false,
        isEnabled: Bool = true,
        description: String = ""
    ) {
        self.id = UUID()
        self.pattern = pattern
        self.type = type
        self.isRegex = isRegex
        self.isEnabled = isEnabled
        self.description = description
    }
    
    func matches(_ path: String) -> Bool {
        guard isEnabled else { return false }
        
        if isRegex {
            return matchesRegex(path)
        } else {
            return matchesWildcard(path)
        }
    }
    
    private func matchesRegex(_ path: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(path.startIndex..., in: path)
            return regex.firstMatch(in: path, options: [], range: range) != nil
        } catch {
            return false
        }
    }
    
    private func matchesWildcard(_ path: String) -> Bool {
        // 简单通配符匹配
        // * 匹配任意字符
        // ? 匹配单个字符
        
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        do {
            let regex = try NSRegularExpression(pattern: "^\(regexPattern)$", options: [.caseInsensitive])
            let range = NSRange(path.startIndex..., in: path)
            return regex.firstMatch(in: path, options: [], range: range) != nil
        } catch {
            return false
        }
    }
}

enum FilterRuleType: String, Codable, CaseIterable {
    case include = "包含"
    case exclude = "排除"
    
    var icon: String {
        switch self {
        case .include:
            return "plus.circle"
        case .exclude:
            return "minus.circle"
        }
    }
}

// MARK: - 过滤预设

struct FilterPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let rules: [FilterRule]
}
