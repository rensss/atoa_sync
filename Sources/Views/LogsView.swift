import SwiftUI

struct LogsView: View {
    @ObservedObject private var logManager = LogManager.shared
    @State private var selectedLevel: LogLevel?
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜索日志...", text: $searchText)
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
                
                Picker("级别", selection: $selectedLevel) {
                    Text("全部").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level as LogLevel?)
                    }
                }
                .frame(width: 150)
                
                Button("清除") {
                    logManager.clearLogs()
                }
                
                Button("导出") {
                    if let url = logManager.exportLogs() {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding()
            
            Divider()
            
            if filteredLogs.isEmpty {
                EmptyLogsView()
            } else {
                List {
                    ForEach(filteredLogs) { log in
                        LogRow(log: log)
                    }
                }
            }
        }
    }
    
    private var filteredLogs: [LogEntry] {
        logManager.filterLogs(
            by: selectedLevel,
            searchText: searchText.isEmpty ? nil : searchText
        )
    }
}

struct LogRow: View {
    let log: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: log.level.icon)
                .foregroundColor(levelColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.formattedTimestamp)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Text(log.category)
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    
                    Spacer()
                }
                
                Text(log.message)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var levelColor: Color {
        switch log.level {
        case .debug:
            return .gray
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .critical:
            return .purple
        }
    }
}

struct EmptyLogsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("没有日志")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
