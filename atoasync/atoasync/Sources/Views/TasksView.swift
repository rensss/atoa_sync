import SwiftUI

import SwiftUI

struct TasksView: View {
    @ObservedObject private var syncManager = SyncManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if syncManager.activeTasks.isEmpty && syncManager.completedTasks.isEmpty {
                EmptyTasksView()
            } else {
                List {
                    if !syncManager.activeTasks.isEmpty {
                        Section("进行中") {
                            ForEach(syncManager.activeTasks) { task in
                                TaskRow(task: task)
                            }
                        }
                    }
                    
                    if !syncManager.completedTasks.isEmpty {
                        Section("已完成") {
                            ForEach(syncManager.completedTasks) { task in
                                TaskRow(task: task)
                            }
                        }
                    }
                }
                
                if !syncManager.completedTasks.isEmpty {
                    Divider()
                    
                    HStack {
                        Spacer()
                        
                        Button("清除已完成") {
                            syncManager.clearCompletedTasks()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
    }
}

struct TaskRow: View {
    @ObservedObject var task: SyncTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.blue)
                
                Text(task.sourceDevice.displayName)
                    .font(.headline)
                
                Spacer()
                
                StatusBadge(status: task.status)
            }
            
            if task.status == .running {
                VStack(spacing: 8) {
                    ProgressView(value: task.progress) {
                        HStack {
                            Text("\(task.progressPercentage)%")
                            Spacer()
                            Text(task.formattedBytesTransferred)
                        }
                        .font(.system(size: 12))
                    }
                    
                    if let currentFile = task.currentFile {
                        Text("正在同步: \(currentFile)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text("速度: \(task.formattedSpeed)")
                        Spacer()
                        Text("剩余时间: \(task.formattedTimeRemaining)")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Text("\(task.processedFiles) / \(task.totalFiles) 文件")
                    Spacer()
                    Text(task.formattedBytesTransferred)
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            
            if task.status == .running || task.status == .paused {
                HStack(spacing: 8) {
                    if task.status == .running {
                        Button("暂停") {
                            SyncManager.shared.pauseSync(taskId: task.id)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("继续") {
                            Task {
                                try? await SyncManager.shared.resumeSync(taskId: task.id)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button("取消") {
                        SyncManager.shared.cancelSync(taskId: task.id)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            
            if let error = task.error {
                Text("错误: \(error.localizedDescription)")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct StatusBadge: View {
    let status: SyncStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .pending:
            return .gray
        case .running:
            return .blue
        case .paused:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }
}

struct EmptyTasksView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("没有同步任务")
                .font(.headline)
            
            Text("开始同步后，任务会显示在这里")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
