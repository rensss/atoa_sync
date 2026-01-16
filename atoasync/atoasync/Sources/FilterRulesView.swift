import SwiftUI

/// 文件过滤规则视图
struct FilterRulesView: View {
    @ObservedObject private var filterManager = FileFilterManager.shared
    @State private var showAddRule = false
    @State private var editingRule: FilterRule?
    @State private var showPresets = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("文件过滤规则")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showPresets = true
                } label: {
                    Label("预设", systemImage: "list.bullet.rectangle")
                }
                .popover(isPresented: $showPresets) {
                    PresetsPopover(filterManager: filterManager)
                }
                
                Button {
                    showAddRule = true
                } label: {
                    Label("添加规则", systemImage: "plus")
                }
                
                Button(role: .destructive) {
                    filterManager.clearRules()
                } label: {
                    Label("清除", systemImage: "trash")
                }
                .disabled(filterManager.rules.isEmpty)
            }
            .padding()
            
            Divider()
            
            // 规则列表
            if filterManager.rules.isEmpty {
                EmptyRulesView()
            } else {
                List {
                    ForEach(filterManager.rules) { rule in
                        RuleRow(rule: rule) {
                            editingRule = rule
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { filterManager.removeRule(at: $0) }
                    }
                    .onMove { source, destination in
                        filterManager.moveRule(from: source, to: destination)
                    }
                }
            }
            
            // 规则说明
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                
                Text("规则按顺序执行：先检查排除规则，再检查包含规则")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .sheet(isPresented: $showAddRule) {
            RuleEditorView(mode: .add) { rule in
                filterManager.addRule(rule)
            }
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorView(mode: .edit(rule)) { updatedRule in
                if let index = filterManager.rules.firstIndex(where: { $0.id == rule.id }) {
                    filterManager.updateRule(at: index, with: updatedRule)
                }
            }
        }
    }
}

// MARK: - 规则行

struct RuleRow: View {
    let rule: FilterRule
    let onEdit: () -> Void
    
    @ObservedObject private var filterManager = FileFilterManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 启用开关
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { newValue in
                    var updated = rule
                    updated.isEnabled = newValue
                    if let index = filterManager.rules.firstIndex(where: { $0.id == rule.id }) {
                        filterManager.updateRule(at: index, with: updated)
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .labelsHidden()
            
            // 类型图标
            Image(systemName: rule.type.icon)
                .foregroundColor(rule.type == .include ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.pattern)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(rule.isEnabled ? .primary : .secondary)
                    
                    if rule.isRegex {
                        Text("正则")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }
                }
                
                if !rule.description.isEmpty {
                    Text(rule.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .opacity(rule.isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - 规则编辑器

struct RuleEditorView: View {
    enum Mode {
        case add
        case edit(FilterRule)
    }
    
    let mode: Mode
    let onSave: (FilterRule) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var pattern: String = ""
    @State private var type: FilterRuleType = .include
    @State private var isRegex: Bool = false
    @State private var description: String = ""
    @State private var isValidRegex: Bool = true
    
    var body: some View {
        VStack(spacing: 20) {
            Text(mode.isAdd ? "添加规则" : "编辑规则")
                .font(.headline)
            
            Form {
                // 规则类型
                Picker("类型", selection: $type) {
                    ForEach(FilterRuleType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                // 模式
                VStack(alignment: .leading) {
                    TextField("模式", text: $pattern)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: pattern) { _ in
                            validatePattern()
                        }
                    
                    if !isValidRegex && isRegex {
                        Text("无效的正则表达式")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // 是否为正则表达式
                Toggle("使用正则表达式", isOn: $isRegex)
                    .onChange(of: isRegex) { _ in
                        validatePattern()
                    }
                
                // 描述
                TextField("描述（可选）", text: $description)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // 帮助信息
                VStack(alignment: .leading, spacing: 8) {
                    Text("示例:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if isRegex {
                        Text("• .*\\.jpg$ - 匹配所有 .jpg 文件")
                        Text("• .*/DCIM/.* - 匹配 DCIM 目录下的所有文件")
                        Text("• ^(?!.*cache).*$ - 排除包含 cache 的路径")
                    } else {
                        Text("• *.jpg - 匹配所有 .jpg 文件")
                        Text("• DCIM/* - 匹配 DCIM 目录下的文件")
                        Text("• photo?.png - 匹配 photo1.png, photo2.png 等")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .formStyle(.grouped)
            
            // 按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("保存") {
                    saveRule()
                }
                .buttonStyle(.borderedProminent)
                .disabled(pattern.isEmpty || (isRegex && !isValidRegex))
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 400, height: 450)
        .onAppear {
            loadExistingRule()
        }
    }
    
    private func loadExistingRule() {
        if case .edit(let rule) = mode {
            pattern = rule.pattern
            type = rule.type
            isRegex = rule.isRegex
            description = rule.description
        }
    }
    
    private func validatePattern() {
        if isRegex && !pattern.isEmpty {
            isValidRegex = FileFilterManager.shared.validateRegex(pattern)
        } else {
            isValidRegex = true
        }
    }
    
    private func saveRule() {
        let rule = FilterRule(
            pattern: pattern,
            type: type,
            isRegex: isRegex,
            isEnabled: true,
            description: description
        )
        onSave(rule)
        dismiss()
    }
}

extension RuleEditorView.Mode {
    var isAdd: Bool {
        if case .add = self { return true }
        return false
    }
}

// MARK: - 预设弹出框

struct PresetsPopover: View {
    @ObservedObject var filterManager: FileFilterManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("快速应用预设")
                .font(.headline)
                .padding()
            
            Divider()
            
            List {
                ForEach(filterManager.presets) { preset in
                    Button {
                        filterManager.applyPreset(preset)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.system(size: 13))
                            
                            Text(preset.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(preset.rules.count) 条规则")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .frame(width: 250, height: 300)
    }
}

// MARK: - 空规则视图

struct EmptyRulesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("没有过滤规则")
                .font(.headline)
            
            Text("添加规则来筛选要同步的文件")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    FilterRulesView()
        .frame(width: 500, height: 400)
}
