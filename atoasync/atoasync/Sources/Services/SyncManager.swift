import Foundation
import Combine
import AppKit

/// 同步管理器 - 负责文件同步任务的调度和执行
@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published var activeTasks: [SyncTask] = []
    @Published var completedTasks: [SyncTask] = []
    @Published var isPreparing: Bool = false
    
    private var taskCancellations: [UUID: Bool] = [:]
    private var taskPauses: [UUID: Bool] = [:]
    private var resumeStates: [UUID: ResumeState] = [:]
    private var taskWideConflictResolution: [UUID: ConflictResolution] = [:]
    
    private init() {}
    
    // MARK: - 同步任务管理
    
    /// 开始同步任务（统一入口：支持文件/文件夹混合选择）
    ///
    /// - Parameters:
    ///   - items: 用户选择的条目（可包含文件夹）
    ///   - device: 源设备
    ///   - sourceBasePath: 相对路径计算的基准路径（统一规则：一律相对扫描根，例如 /sdcard）
    ///   - targetPath: 本地目标根目录
    ///   - conflictResolution: 冲突处理策略
    func startSync(
        items: [FileInfo],
        device: DeviceInfo,
        sourceBasePath: String,
        targetPath: String,
        conflictResolution: ConflictResolution
    ) async throws {
        isPreparing = true
        defer { isPreparing = false }

        // 统一展开：把选择项（包含目录）展开成最终文件列表
        let allFiles = try await expandSelectionToFiles(
            items: items,
            device: device,
            sourceBasePath: sourceBasePath
        )
        
        guard !allFiles.isEmpty else {
            LogManager.shared.log("没有文件需要同步", level: .warning, category: "Sync")
            throw SyncError.noFilesToSync
        }
        
        let task = SyncTask(
            files: allFiles,
            sourceDevice: device,
            targetPath: targetPath,
            conflictResolution: conflictResolution
        )
        
        taskCancellations[task.id] = false
        taskPauses[task.id] = false
        // 清理之前可能存在的任务范围冲突解决策略
        taskWideConflictResolution.removeValue(forKey: task.id)
        
        self.activeTasks.append(task)
        StatusBarManager.shared.startSyncing()
        
        do {
            try await performSync(task: task)
            
            task.status = .completed
            self.activeTasks.removeAll { $0.id == task.id }
            self.completedTasks.append(task)
            
            // 保存同步缓存
            saveSyncCache(task: task)
            
            // 记录同步历史
            let duration = Date().timeIntervalSince(task.startTime)
            SyncHistoryManager.shared.addFromTask(task, duration: duration)
            
            // 更新菜单栏状态
            StatusBarManager.shared.stopSyncing(success: true)
            
            LogManager.shared.log("同步完成: \(task.processedFiles) 个文件", level: .info, category: "Sync")
            NotificationCenter.default.post(name: .syncCompleted, object: task)
            
        } catch SyncError.cancelled {
            task.status = .cancelled
            self.activeTasks.removeAll { $0.id == task.id }
            taskWideConflictResolution.removeValue(forKey: task.id)
            LogManager.shared.log("同步已取消", level: .info, category: "Sync")
            
        } catch SyncError.paused {
            // 暂停时保存续传状态
            task.status = .paused
            LogManager.shared.log("同步已暂停", level: .info, category: "Sync")
            
        } catch {
            task.status = .failed
            task.error = error
            
            // 记录失败历史
            let duration = Date().timeIntervalSince(task.startTime)
            SyncHistoryManager.shared.addFromTask(task, duration: duration)
            
            // 更新菜单栏状态
            StatusBarManager.shared.stopSyncing(success: false)
            
            LogManager.shared.log("同步失败: \(error.localizedDescription)", level: .error, category: "Sync")
            NotificationCenter.default.post(name: .syncFailed, object: error)
            throw error
        }
    }
    
    // MARK: - 选择展开（文件夹递归 -> 文件列表）
    
    /// 将用户选择的文件/文件夹条目展开为最终要传输的文件列表，并统一计算 relativePath
    private func expandSelectionToFiles(
        items: [FileInfo],
        device: DeviceInfo,
        sourceBasePath: String
    ) async throws -> [FileInfo] {
        var allFiles: [FileInfo] = []
        
        try await withThrowingTaskGroup(of: [FileInfo].self) { group in
            var standaloneFiles: [FileInfo] = []
            
            for item in items {
                if item.isDirectory {
                    group.addTask {
                        try await self.expandDirectory(
                            directory: item,
                            device: device,
                            sourceBasePath: sourceBasePath
                        )
                    }
                } else {
                    let relativePath = self.computeRelativePath(fullPath: item.path, basePath: sourceBasePath)
                    standaloneFiles.append(
                        FileInfo(
                            path: item.path,
                            relativePath: relativePath,
                            size: item.size,
                            modified: item.modified,
                            hash: item.hash,
                            isDirectory: false
                        )
                    )
                }
            }
            
            for try await filesInDir in group {
                allFiles.append(contentsOf: filesInDir)
            }
            allFiles.append(contentsOf: standaloneFiles)
        }
        
        return allFiles
    }
    
    /// 递归展开文件夹，获取所有文件（不包含目录本身）
    private func expandDirectory(
        directory: FileInfo,
        device: DeviceInfo,
        sourceBasePath: String
    ) async throws -> [FileInfo] {
        var result: [FileInfo] = []
        
        let contents = try await ADBManager.shared.listFilesRecursive(
            serialNumber: device.serialNumber,
            path: directory.path
        )
        
        for item in contents where !item.isDirectory {
            let relativePath = computeRelativePath(fullPath: item.path, basePath: sourceBasePath)
            result.append(
                FileInfo(
                    path: item.path,
                    relativePath: relativePath,
                    size: item.size,
                    modified: item.modified,
                    hash: item.hash,
                    isDirectory: false
                )
            )
        }
        
        return result
    }
    
    private func computeRelativePath(fullPath: String, basePath: String) -> String {
        var relativePath = fullPath
        if relativePath.hasPrefix(basePath) {
            relativePath = String(relativePath.dropFirst(basePath.count))
            if relativePath.hasPrefix("/") {
                relativePath = String(relativePath.dropFirst())
            }
        }
        return relativePath
    }
    
    // MARK: - 并行同步执行
    
    private func performSync(task: SyncTask) async throws {
        task.status = .running
        
        let maxConcurrent = ConfigManager.shared.config.maxConcurrentTransfers
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
            for try await (_, fileSize) in group {
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
                task.bytesTransferred += fileSize
                task.processedFiles = completedCount
                task.progress = Double(completedCount) / Double(task.totalFiles)
                
                // 更新速度（每秒更新一次）
                let now = Date()
                if now.timeIntervalSince(lastSpeedUpdate) >= 1.0 {
                    let bytesDiff = task.bytesTransferred - bytesAtLastUpdate
                    let timeDiff = now.timeIntervalSince(lastSpeedUpdate)
                    let speed = Double(bytesDiff) / timeDiff
                    
                    task.speed = speed
                    let remainingBytes = task.totalBytes - task.bytesTransferred
                    if speed > 0 {
                        task.estimatedTimeRemaining = Double(remainingBytes) / speed
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
        
        // 清理续传和冲突解决状态
        resumeStates.removeValue(forKey: task.id)
        taskWideConflictResolution.removeValue(forKey: task.id)
    }
    
    // MARK: - 单文件传输
    
    private func transferFile(file: FileInfo, index: Int, task: SyncTask) async throws {
        task.currentFile = file.relativePath
        
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
            let connectedDevices = WiFiManager.shared.connectedDevices
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
    
    private enum UserConflictChoice {
        case overwrite, skip, overwriteAll, skipAll
    }
    
    private func handleConflict(
        file: FileInfo,
        targetPath: String,
        resolution: ConflictResolution,
        task: SyncTask
    ) async throws -> Bool {
        // 检查任务范围内的冲突解决策略
        if let taskResolution = self.taskWideConflictResolution[task.id] {
            switch taskResolution {
            case .overwrite:
                return true
            case .skip:
                return false
            default:
                break
            }
        }
        
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
            let choice = await askUserForConflictResolution(file: file)
            switch choice {
            case .overwrite:
                return true
            case .skip:
                return false
            case .overwriteAll:
                self.taskWideConflictResolution[task.id] = .overwrite
                return true
            case .skipAll:
                self.taskWideConflictResolution[task.id] = .skip
                return false
            }
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
    
    private func askUserForConflictResolution(file: FileInfo) async -> UserConflictChoice {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            LogManager.shared.log("无法显示冲突对话框，因为没有活动的窗口。默认跳过文件: \(file.relativePath)", level: .warning, category: "Sync")
            return .skip
        }
        
        return await withCheckedContinuation { continuation in
            let alert = NSAlert()
            alert.messageText = "文件冲突"
            alert.informativeText = "文件 “\(file.relativePath)” 已存在。您要怎么做？"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "覆盖")
            alert.addButton(withTitle: "跳过")
            alert.addButton(withTitle: "全部覆盖")
            alert.addButton(withTitle: "全部跳过")
            
            alert.beginSheetModal(for: window) { response in
                switch response {
                case .alertFirstButtonReturn:
                    continuation.resume(returning: .overwrite)
                case .alertSecondButtonReturn:
                    continuation.resume(returning: .skip)
                case .alertThirdButtonReturn:
                    continuation.resume(returning: .overwriteAll)
                case NSApplication.ModalResponse(1003):
                    continuation.resume(returning: .skipAll)
                default:
                    continuation.resume(returning: .skip)
                }
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
    
    private func saveSyncCache(task: SyncTask) {
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
    
    // MARK: - 任务控制
    
    /// 暂停同步任务
    func pauseSync(taskId: UUID) {
        taskPauses[taskId] = true
        LogManager.shared.log("请求暂停同步任务", level: .info, category: "Sync")
    }
    
    /// 恢复同步任务
    func resumeSync(taskId: UUID) async throws {
        guard let task = activeTasks.first(where: { $0.id == taskId }) else {
            throw SyncError.taskNotFound
        }
        
        taskPauses[taskId] = false
        taskCancellations[taskId] = false
        
        LogManager.shared.log("恢复同步任务", level: .info, category: "Sync")
        
        try await performSync(task: task)
        
        task.status = .completed
        self.activeTasks.removeAll { $0.id == taskId }
        self.completedTasks.append(task)
    }
    
    /// 取消同步任务
    func cancelSync(taskId: UUID) {
        taskCancellations[taskId] = true
        resumeStates.removeValue(forKey: taskId)
        taskWideConflictResolution.removeValue(forKey: taskId)
        
        if let task = activeTasks.first(where: { $0.id == taskId }) {
            task.status = .cancelled
        }
        activeTasks.removeAll { $0.id == taskId }
        
        LogManager.shared.log("取消同步任务", level: .info, category: "Sync")
    }
    
    /// 取消所有同步任务
    func cancelAllSyncs() {
        let taskIds = activeTasks.map { $0.id }
        taskIds.forEach { cancelSync(taskId: $0) }
    }
    
    /// 清除已完成的任务
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
    case noFilesToSync
    
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
        case .noFilesToSync:
            return "没有需要同步的文件。您选择的文件夹可能是空的。"
        }
    }
}
