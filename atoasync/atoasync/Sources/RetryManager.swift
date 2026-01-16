import Foundation

/// 重试管理器 - 处理传输失败的自动重试
actor RetryManager {
    static let shared = RetryManager()
    
    private var retryQueue: [RetryItem] = []
    private var isProcessing = false
    
    // 重试配置
    private let maxRetries = 3
    private let initialDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 30.0
    private let backoffMultiplier = 2.0
    
    private init() {}
    
    // MARK: - 重试逻辑
    
    /// 执行带重试的操作
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        operationName: String = "操作",
        shouldRetry: @escaping (Error) -> Bool = { _ in true }
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = initialDelay
        
        for attempt in 1...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // 检查是否应该重试
                guard shouldRetry(error) else {
                    LogManager.shared.log(
                        "\(operationName) 失败，不可重试: \(error.localizedDescription)",
                        level: .error,
                        category: "Retry"
                    )
                    throw error
                }
                
                // 最后一次尝试失败
                guard attempt < maxRetries else {
                    LogManager.shared.log(
                        "\(operationName) 在 \(maxRetries) 次尝试后失败",
                        level: .error,
                        category: "Retry"
                    )
                    break
                }
                
                LogManager.shared.log(
                    "\(operationName) 失败 (尝试 \(attempt)/\(maxRetries))，\(currentDelay) 秒后重试: \(error.localizedDescription)",
                    level: .warning,
                    category: "Retry"
                )
                
                // 等待后重试
                try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                
                // 指数退避
                currentDelay = min(currentDelay * backoffMultiplier, maxDelay)
            }
        }
        
        throw lastError ?? RetryError.maxRetriesExceeded
    }
    
    /// 传输文件带重试
    func transferFileWithRetry(
        serialNumber: String,
        remotePath: String,
        localPath: String
    ) async throws {
        try await executeWithRetry(
            operation: {
                try await ADBManager.shared.pullFile(
                    serialNumber: serialNumber,
                    remotePath: remotePath,
                    localPath: localPath
                )
            },
            operationName: "传输文件 \(remotePath)",
            shouldRetry: { error in
                // 根据错误类型决定是否重试
                if let adbError = error as? ADBError {
                    switch adbError {
                    case .deviceNotFound:
                        return false // 设备未找到，不重试
                    case .commandFailed, .executionFailed:
                        return true // 命令失败，可以重试
                    default:
                        return true
                    }
                }
                return true
            }
        )
    }
    
    // MARK: - 失败队列管理
    
    /// 添加失败项到重试队列
    func addToRetryQueue(
        file: FileInfo,
        device: DeviceInfo,
        targetPath: String,
        error: Error
    ) {
        let item = RetryItem(
            file: file,
            device: device,
            targetPath: targetPath,
            error: error
        )
        retryQueue.append(item)
        
        LogManager.shared.log(
            "添加到重试队列: \(file.relativePath)",
            level: .info,
            category: "Retry"
        )
    }
    
    /// 处理重试队列
    func processRetryQueue() async {
        guard !isProcessing, !retryQueue.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        LogManager.shared.log(
            "开始处理重试队列，共 \(retryQueue.count) 个项目",
            level: .info,
            category: "Retry"
        )
        
        var remainingItems: [RetryItem] = []
        
        for var item in retryQueue {
            do {
                let targetURL = URL(fileURLWithPath: item.targetPath)
                    .appendingPathComponent(item.file.relativePath)
                
                try await transferFileWithRetry(
                    serialNumber: item.device.serialNumber,
                    remotePath: item.file.path,
                    localPath: targetURL.path
                )
                
                LogManager.shared.log(
                    "重试成功: \(item.file.relativePath)",
                    level: .info,
                    category: "Retry"
                )
            } catch {
                item.retryCount += 1
                item.lastError = error
                
                if item.retryCount < maxRetries {
                    remainingItems.append(item)
                } else {
                    LogManager.shared.log(
                        "重试失败，已放弃: \(item.file.relativePath)",
                        level: .error,
                        category: "Retry"
                    )
                }
            }
        }
        
        retryQueue = remainingItems
        
        if !retryQueue.isEmpty {
            LogManager.shared.log(
                "重试队列剩余 \(retryQueue.count) 个项目",
                level: .warning,
                category: "Retry"
            )
        }
    }
    
    /// 清空重试队列
    func clearRetryQueue() {
        retryQueue.removeAll()
        LogManager.shared.log("已清空重试队列", level: .info, category: "Retry")
    }
    
    /// 获取队列状态
    func getQueueStatus() -> (count: Int, isProcessing: Bool) {
        return (retryQueue.count, isProcessing)
    }
    
    /// 获取失败项列表
    func getFailedItems() -> [RetryItem] {
        return retryQueue
    }
}

// MARK: - 重试项

struct RetryItem: Identifiable {
    let id = UUID()
    let file: FileInfo
    let device: DeviceInfo
    let targetPath: String
    var retryCount: Int = 0
    var lastError: Error?
    let addedAt: Date = Date()
    
    init(file: FileInfo, device: DeviceInfo, targetPath: String, error: Error) {
        self.file = file
        self.device = device
        self.targetPath = targetPath
        self.lastError = error
    }
}

// MARK: - 重试错误

enum RetryError: LocalizedError {
    case maxRetriesExceeded
    case operationCancelled
    
    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "已达到最大重试次数"
        case .operationCancelled:
            return "操作已取消"
        }
    }
}

// MARK: - 重试策略

enum RetryStrategy {
    case immediate           // 立即重试
    case fixedDelay(TimeInterval)  // 固定延迟
    case exponentialBackoff  // 指数退避
    case custom(delays: [TimeInterval])  // 自定义延迟序列
    
    func delay(for attempt: Int) -> TimeInterval {
        switch self {
        case .immediate:
            return 0
        case .fixedDelay(let interval):
            return interval
        case .exponentialBackoff:
            return pow(2.0, Double(attempt - 1))
        case .custom(let delays):
            return attempt <= delays.count ? delays[attempt - 1] : delays.last ?? 1.0
        }
    }
}
