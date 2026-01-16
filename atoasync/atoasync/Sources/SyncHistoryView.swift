import SwiftUI

/// 同步历史视图
struct SyncHistoryView: View {
    @ObservedObject private var historyManager = SyncHistoryManager.shared
    @State private var selectedEntry: SyncHistoryEntry?
    @State private var searchText = ""
    @State private var showStatistics = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜索历史...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                
                Spacer()
                
                Button {
                    showStatistics.toggle()
                } label: {
                    Label("统计", systemImage: "chart.bar")
                }
                
                Button {
                    if let url = historyManager.exportHistory() {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                
                Button(role: .destructive) {
                    historyManager.clearHistory()
                } label: {
                    Label("清除", systemImage: "trash")
                }
            }
            .padding()
            
            Divider()
            
            // 统计信息卡片
            if showStatistics {
                StatisticsCard(statistics: historyManager.getStatistics())
                    .padding()
                
                Divider()
            }
            
            // 历史列表
            if filteredHistory.isEmpty {
                EmptyHistoryView()
            } else {
                List(selection: $selectedEntry) {
                    ForEach(filteredHistory) { entry in
                        HistoryEntryRow(entry: entry)
                            .tag(entry)
                    }
                }
            }
        }
    }
    
    private var filteredHistory: [SyncHistoryEntry] {
        if searchText.isEmpty {
            return historyManager.history
        }
        
        return historyManager.history.filter { entry in
            entry.deviceName.localizedCaseInsensitiveContains(searchText) ||
            entry.targetPath.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - 历史条目行

struct HistoryEntryRow: View {
    let entry: SyncHistoryEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            Image(systemName: entry.status.icon)
                .font(.title2)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 4) {
                // 设备名称和时间
                HStack {
                    Text(entry.deviceName)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(entry.formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 文件信息
                HStack {
                    Label("\(entry.filesCount) 个文件", systemImage: "doc")
                    Text("•")
                    Text(entry.formattedBytes)
                    Text("•")
                    Text(entry.formattedDuration)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // 目标路径
                Text(entry.targetPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // 错误信息
                if let error = entry.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var statusColor: Color {
        switch entry.status {
        case .success:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        }
    }
}

// MARK: - 统计卡片

struct StatisticsCard: View {
    let statistics: SyncStatistics
    
    var body: some View {
        HStack(spacing: 20) {
            StatItem(
                title: "总同步次数",
                value: "\(statistics.totalSyncs)",
                icon: "arrow.triangle.2.circlepath"
            )
            
            Divider()
            
            StatItem(
                title: "成功率",
                value: String(format: "%.1f%%", statistics.successRate),
                icon: "checkmark.circle"
            )
            
            Divider()
            
            StatItem(
                title: "总文件数",
                value: "\(statistics.totalFiles)",
                icon: "doc"
            )
            
            Divider()
            
            StatItem(
                title: "总数据量",
                value: statistics.formattedTotalBytes,
                icon: "internaldrive"
            )
            
            Divider()
            
            StatItem(
                title: "总耗时",
                value: statistics.formattedTotalDuration,
                icon: "clock"
            )
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 80)
    }
}

// MARK: - 空历史视图

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("没有同步历史")
                .font(.headline)
            
            Text("完成同步后，历史记录会显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SyncHistoryView()
        .frame(width: 600, height: 400)
}
