import Foundation
import Combine
import AppKit

/// 同步管理器 - 负责文件同步任务的调度和执行
actor SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @MainActor @Published var activeTasks: [SyncTask] = []
    @MainActor @Published var completedTasks: [SyncTask] = []
    
    private var taskCancellations: [UUID: Bool] = [:]
    private var taskPauses: [UUID: Bool] = [:]
    private var resumeStates: [UUID: ResumeState] = [:]
    
    private init() {}
    
    // MARK: - 同步任务管理
    
    /// 开始同步任务
    func startSync(
        files: [FileInfo],
        device: DeviceInfo,
        targetPath: String,
        conflictResolution: ConflictResolution
    ) async throws {
        let task = SyncTask(
            files: files,
            sourceDevice: device,
            targetPath: targetPath,
            conflictResolution: conflictResolution
        )
        
        taskCancellations[task.id] = false
        taskPauses[task.id] = false
        
        await MainActor.run {
            self.activeTasks.append(task)
            StatusBarManager.shared.startSyncing()
        }
        
        do {
            try await performSync(task: task)
            
            await MainActor.run {
                task.status = .completed
                self.activeTasks.removeAll { $0.id == task.id }
                self.completedTasks.append(task)
            }
            
            // 保存同步缓存
            await saveSyncCache(task: task)
            
            // 记录同步历史
            let duration = Date().timeIntervalSince(task.startTime)
            SyncHistoryManager.shared.addFromTask(task, duration: duration)
            
            // 更新菜单栏状态
            await StatusBarManager.shared.stopSyncing(success: true)
            
            LogManager.shared.log("同步完成: \(task.processedFiles) 个文件", level: .info, category: "Sync")
            NotificationCenter.default.post(name: .syncCompleted, object: task)
            
        } catch SyncError.cancelled {
            await MainActor.run {
                task.status = .cancelled
                self.activeTasks.removeAll { $0.id == task.id }
            }
            LogManager.shared.log("同步已取消", level: .info, category: "Sync")
            
        } catch SyncError.paused {
            // 暂停时保存续传状态
            await MainActor.run {
                task.status = .paused
            }
            LogManager.shared.log("同步已暂停", level: .info, category: "Sync")
            
        } catch {
            await MainActor.run {
                task.status = .failed
                task.error = error
            }
            
            // 记录失败历史
            let duration = Date().timeIntervalSince(task.startTime)
            SyncHistoryManager.shared.addFromTask(task, duration: duration)
            
            // 更新菜单栏状态
            await StatusBarManager.shared.stopSyncing(success: false)
            
            LogManager.shared.log("同步失败: \(error.localizedDescription)", level: .error, category: "Sync")
            NotificationCenter.default.post(name: .syncFailed, object: error)
            throw error
        }
    }
    
    // MARK: - 并行同步执行
    
    private func performSync(task: SyncTask) async throws {
        await MainActor.run {
            task.status = .running
        }
        
        let maxConcurrent = await MainActor.run { ConfigManager.shared.config.maxConcurrentTransfers }
        let startIndex = resumeStates[task.id]?.completedIndex ?? 0
        let remainingFiles = Array(task.files.dropFirst(startIndex))
        
        // 使用 TaskGroup 进行并行传输
        try await withThrowingTaskGroup(of: (Int, Int64).self) { group in
            var pendingFiles = remainingFiles.enumerated().makeIterator()
            var activeCount = 0
            var completedCount = startIndex
            
            let startTime = Date()
            var lastSpeedUpdate = startTime
            var bytesAtLastUpdate: Int64 = resumeStates[task.id]?.bytesTransferred ?? 0
            
            // 初始化并发任务
            while activeCount < maxConcurrent, let (index, file) = pendingFiles.next() {
                let globalIndex = index + startIndex
                group.addTask {
                    try await self.transferFile(
                        file: file,
                        index: globalIndex,
                        task: task
                    )
                    return (globalIndex, file.size)
                }
                activeCount += 1
            }
            
            // 处理完成的任务并添加新任务
            for try await (completedIndex, fileSize) in group {
                // 检查取消和暂停状态
                if taskCancellations[task.id] == true {
                    group.cancelAll()
                    throw SyncError.cancelled
                }
                
                if taskPauses[task.id] == true {
                    // 保存续传状态
                    resumeStates[task.id] = ResumeState(
                        completedIndex: completedCount,
                        bytesTransferred: task.bytesTransferred
                    )
                    group.cancelAll()
                    throw SyncError.paused
                }
                
                completedCount += 1
                activeCount -= 1
                
                // 更新进度
                await MainActor.run {
                    task.bytesTransferred += fileSize
                    task.processedFiles = completedCount
                    task.progress = Double(completedCount) / Double(task.totalFiles)
                }
                
                // 更新速度（每秒更新一次）
                let now = Date()
                if now.timeIntervalSince(lastSpeedUpdate) >= 1.0 {
                    let bytesDiff = task.bytesTransferred - bytesAtLastUpdate
                    let timeDiff = now.timeIntervalSince(lastSpeedUpdate)
                    let speed = Double(bytesDiff) / timeDiff
                    
                    await MainActor.run {
                        task.speed = speed
                        let remainingBytes = task.totalBytes - task.bytesTransferred
                        if speed > 0 {
                            task.estimatedTimeRemaining = Double(remainingBytes) / speed
                        }
                    }
                    
                    lastSpeedUpdate = now
                    bytesAtLastUpdate = task.bytesTransferred
                }
                
                // 添加下一个任务
                if let (index, file) = pendingFiles.next() {
                    let globalIndex = index + startIndex
                    group.addTask {
                        try await self.transferFile(
                            file: file,
                            index: globalIndex,
                            task: task
                        )
                        return (globalIndex, file.size)
                    }
                    activeCount += 1
                }
            }
        }
        
        // 清理续传状态
        resumeStates.removeValue(forKey: task.id)
    }
    
    // MARK: - 单文件传输
    
    private func transferFile(file: FileInfo, index: Int, task: SyncTask) async throws {
        await MainActor.run {
            task.currentFile = file.relativePath
        }
        
        let targetFileURL = URL(fileURLWithPath: task.targetPath)
            .appendingPathComponent(file.relativePath)
        
        // 检查文件冲突
        if FileManager.default.fileExists(atPath: targetFileURL.path) {
            let shouldOverwrite = try await handleConflict(
                file: file,
                targetPath: targetFileURL.path,
                resolution: task.conflictResolution,
                task: task
            )
            
            if !shouldOverwrite {
                LogManager.shared.log("跳过文件: \(file.relativePath)", level: .debug, category: "Sync")
                return
            }
        }
        
        // 创建目标目录
        try createDirectoryIfNeeded(for: targetFileURL)
        
        // 根据连接类型选择传输方式，带重试
        switch task.sourceDevice.connectionType {
        case .usb:
            do {
                try await RetryManager.shared.transferFileWithRetry(
                    serialNumber: task.sourceDevice.serialNumber,
                    remotePath: file.path,
                    localPath: targetFileURL.path
                )
            } catch {
                // 添加到重试队列
                await RetryManager.shared.addToRetryQueue(
                    file: file,
                    device: task.sourceDevice,
                    targetPath: task.targetPath,
                    error: error
                )
                throw error
            }
        case .wifi:
            // 使用 WiFi 传输
            let connectedDevices = await MainActor.run { WiFiManager.shared.connectedDevices }
            if let wifiDevice = connectedDevices.first(where: {
                $0.host == task.sourceDevice.serialNumber.components(separatedBy: ":").first
            }) {
                try await WiFiManager.shared.downloadFile(
                    device: wifiDevice,
                    remotePath: file.path,
                    localPath: targetFileURL.path
                )
            } else {
                throw SyncError.deviceDisconnected
            }
        }
        
        LogManager.shared.log("已同步: \(file.relativePath)", level: .debug, category: "Sync")
    }
    
    // MARK: - 冲突处理
    
    private func handleConflict(
        file: FileInfo,
        targetPath: String,
        resolution: ConflictResolution,
        task: SyncTask
    ) async throws -> Bool {
        switch resolution {
        case .overwrite:
            return true
            
        case .skip:
            return false
            
        case .rename:
            // 生成新文件名并移动现有文件
            let newPath = generateUniqueFilename(for: targetPath)
            try FileManager.default.moveItem(atPath: targetPath, toPath: newPath)
            LogManager.shared.log("已重命名现有文件: \(targetPath) -> \(newPath)", level: .debug, category: "Sync")
            return true
            
        case .askEachTime:
            return await askUserForConflictResolution(file: file, targetPath: targetPath)
        }
    }
    
    private func generateUniqueFilename(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        var counter = 1
        var newPath: String
        
        repeat {
            let newFilename = "\(filename)_\(counter)"
            newPath = directory.appendingPathComponent(newFilename)
                .appendingPathExtension(ext).path
            counter += 1
        } while FileManager.default.fileExists(atPath: newPath)
        
        return newPath
    }
    
    @MainActor
    private func askUserForConflictResolution(file: FileInfo, targetPath: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "文件冲突"
            alert.informativeText = "文件 \(file.relativePath) 已存在。\n\n是否覆盖？"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "覆盖")
            alert.addButton(withTitle: "跳过")
            alert.addButton(withTitle: "全部覆盖")
            alert.addButton(withTitle: "全部跳过")
            
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn:
                continuation.resume(returning: true)
            case .alertSecondButtonReturn:
                continuation.resume(returning: false)
            default:
                continuation.resume(returning: false)
            }
        }
    }
    
    // MARK: - 辅助方法
    
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
    
    private func saveSyncCache(task: SyncTask) async {
        await MainActor.run {
            var cache = ConfigManager.shared.loadCache() ?? SyncCache()
            var deviceCache = cache.deviceCaches[task.sourceDevice.serialNumber]
                ?? DeviceCache(deviceSerial: task.sourceDevice.serialNumber)
            
            for file in task.files {
                deviceCache.files[file.relativePath] = CachedFileInfo(from: file)
            }
            deviceCache.lastSyncDate = Date()
            
            cache.deviceCaches[task.sourceDevice.serialNumber] = deviceCache
            cache.lastUpdated = Date()
            
            ConfigManager.shared.saveCache(cache)
        }
    }
    
    // MARK: - 任务控制
    
    /// 暂停同步任务
    func pauseSync(taskId: UUID) {
        taskPauses[taskId] = true
        LogManager.shared.log("请求暂停同步任务", level: .info, category: "Sync")
    }
    
    /// 恢复同步任务
    func resumeSync(taskId: UUID) async throws {
        guard let task = await MainActor.run(body: { activeTasks.first(where: { $0.id == taskId }) }) else {
            throw SyncError.taskNotFound
        }
        
        taskPauses[taskId] = false
        taskCancellations[taskId] = false
        
        LogManager.shared.log("恢复同步任务", level: .info, category: "Sync")
        
        try await performSync(task: task)
        
        await MainActor.run {
            task.status = .completed
            self.activeTasks.removeAll { $0.id == taskId }
            self.completedTasks.append(task)
        }
    }
    
    /// 取消同步任务
    func cancelSync(taskId: UUID) {
        taskCancellations[taskId] = true
        resumeStates.removeValue(forKey: taskId)
        
        Task { @MainActor in
            if let task = activeTasks.first(where: { $0.id == taskId }) {
                task.status = .cancelled
            }
            activeTasks.removeAll { $0.id == taskId }
        }
        
        LogManager.shared.log("取消同步任务", level: .info, category: "Sync")
    }
    
    /// 取消所有同步任务
    func cancelAllSyncs() {
        for taskId in taskCancellations.keys {
            taskCancellations[taskId] = true
        }
        resumeStates.removeAll()
        
        Task { @MainActor in
            for task in activeTasks {
                task.status = .cancelled
            }
            activeTasks.removeAll()
        }
        
        LogManager.shared.log("取消所有同步任务", level: .info, category: "Sync")
    }
    
    /// 清除已完成的任务
    @MainActor
    func clearCompletedTasks() {
        completedTasks.removeAll()
    }
}

// MARK: - 续传状态

private struct ResumeState {
    let completedIndex: Int
    let bytesTransferred: Int64
}

enum SyncError: LocalizedError {
    case cancelled
    case paused
    case taskNotFound
    case deviceDisconnected
    case insufficientSpace
    case permissionDenied
    case fileNotFound
    case transferFailed(String)
    case hashMismatch
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "同步已取消"
        case .paused:
            return "同步已暂停"
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
        case .transferFailed(let message):
            return "传输失败: \(message)"
        case .hashMismatch:
            return "文件校验失败"
        }
    }
}
