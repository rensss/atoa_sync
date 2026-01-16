import Foundation

class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published var activeTasks: [SyncTask] = []
    @Published var completedTasks: [SyncTask] = []
    
    private let queue = DispatchQueue(label: "com.atoa.sync.manager", qos: .userInitiated)
    private var currentTask: SyncTask?
    private var isCancelled = false
    
    private init() {}
    
    func startSync(files: [FileInfo], device: DeviceInfo, targetPath: String, conflictResolution: ConflictResolution) async throws {
        let task = SyncTask(
            files: files,
            sourceDevice: device,
            targetPath: targetPath,
            conflictResolution: conflictResolution
        )
        
        await MainActor.run {
            self.activeTasks.append(task)
            self.currentTask = task
        }
        
        do {
            try await performSync(task: task)
            
            await MainActor.run {
                task.status = .completed
                self.activeTasks.removeAll { $0.id == task.id }
                self.completedTasks.append(task)
            }
        } catch {
            await MainActor.run {
                task.status = .failed
                task.error = error
            }
            throw error
        }
    }
    
    private func performSync(task: SyncTask) async throws {
        await MainActor.run {
            task.status = .running
        }
        
        let startTime = Date()
        var lastUpdateTime = startTime
        var bytesAtLastUpdate: Int64 = 0
        
        for (index, file) in task.files.enumerated() {
            if isCancelled {
                await MainActor.run {
                    task.status = .cancelled
                }
                throw SyncError.cancelled
            }
            
            await MainActor.run {
                task.currentFile = file.relativePath
            }
            
            let targetFileURL = URL(fileURLWithPath: task.targetPath).appendingPathComponent(file.relativePath)
            
            if FileManager.default.fileExists(atPath: targetFileURL.path) {
                let shouldOverwrite = try await handleConflict(
                    file: file,
                    targetPath: targetFileURL.path,
                    resolution: task.conflictResolution
                )
                
                if !shouldOverwrite {
                    await updateProgress(task: task, completedIndex: index + 1, fileSize: 0)
                    continue
                }
            }
            
            try createDirectoryIfNeeded(for: targetFileURL)
            
            try await ADBManager.shared.pullFile(
                serialNumber: task.sourceDevice.serialNumber,
                remotePath: file.path,
                localPath: targetFileURL.path
            )
            
            let currentTime = Date()
            let timeDiff = currentTime.timeIntervalSince(lastUpdateTime)
            
            await MainActor.run {
                task.bytesTransferred += file.size
                task.processedFiles = index + 1
                task.progress = Double(task.processedFiles) / Double(task.totalFiles)
            }
            
            if timeDiff >= 1.0 {
                let bytesDiff = task.bytesTransferred - bytesAtLastUpdate
                let speed = Double(bytesDiff) / timeDiff
                
                await MainActor.run {
                    task.speed = speed
                    
                    let remainingBytes = task.totalBytes - task.bytesTransferred
                    if speed > 0 {
                        task.estimatedTimeRemaining = Double(remainingBytes) / speed
                    }
                }
                
                lastUpdateTime = currentTime
                bytesAtLastUpdate = task.bytesTransferred
            }
        }
    }
    
    private func updateProgress(task: SyncTask, completedIndex: Int, fileSize: Int64) async {
        await MainActor.run {
            task.bytesTransferred += fileSize
            task.processedFiles = completedIndex
            task.progress = Double(task.processedFiles) / Double(task.totalFiles)
        }
    }
    
    private func handleConflict(file: FileInfo, targetPath: String, resolution: ConflictResolution) async throws -> Bool {
        switch resolution {
        case .overwrite:
            return true
        case .skip:
            return false
        case .rename:
            return false
        case .askEachTime:
            return await askUserForConflictResolution(file: file)
        }
    }
    
    private func askUserForConflictResolution(file: FileInfo) async -> Bool {
        return true
    }
    
    private func createDirectoryIfNeeded(for fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    func pauseSync(taskId: UUID) {
        guard let task = activeTasks.first(where: { $0.id == taskId }) else {
            return
        }
        
        Task { @MainActor in
            task.status = .paused
        }
    }
    
    func resumeSync(taskId: UUID) async throws {
        guard let task = activeTasks.first(where: { $0.id == taskId }) else {
            throw SyncError.taskNotFound
        }
        
        try await performSync(task: task)
    }
    
    func cancelSync(taskId: UUID) {
        isCancelled = true
        
        guard let task = activeTasks.first(where: { $0.id == taskId }) else {
            return
        }
        
        Task { @MainActor in
            task.status = .cancelled
            activeTasks.removeAll { $0.id == taskId }
        }
    }
    
    func cancelAllSyncs() {
        isCancelled = true
        
        Task { @MainActor in
            for task in activeTasks {
                task.status = .cancelled
            }
            activeTasks.removeAll()
        }
    }
    
    func clearCompletedTasks() {
        Task { @MainActor in
            completedTasks.removeAll()
        }
    }
}

enum SyncError: LocalizedError {
    case cancelled
    case taskNotFound
    case deviceDisconnected
    case insufficientSpace
    case permissionDenied
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "同步已取消"
        case .taskNotFound:
            return "未找到同步任务"
        case .deviceDisconnected:
            return "设备已断开连接"
        case .insufficientSpace:
            return "磁盘空间不足"
        case .permissionDenied:
            return "权限被拒绝"
        case .fileNotFound:
            return "文件未找到"
        }
    }
}
