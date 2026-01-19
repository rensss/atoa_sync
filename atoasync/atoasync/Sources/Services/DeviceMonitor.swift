import Foundation
import Combine

/// 设备监视器 - 监控 USB 设备的连接和断开
class DeviceMonitor: ObservableObject {
    static let shared = DeviceMonitor()
    
    @Published var connectedDevices: [DeviceInfo] = []
    
    private var monitorTask: Task<Void, Never>?
    private var lastKnownDevices: Set<String> = []
    private let pollInterval: TimeInterval = 3.0
    
    private init() {}
    
    /// 开始监控设备
    func startMonitoring() {
        guard monitorTask == nil else { return }
        
        LogManager.shared.log("开始设备监控", level: .info, category: "Monitor")
        
        monitorTask = Task {
            while !Task.isCancelled {
                await pollDevices()
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }
    
    /// 停止监控设备
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        LogManager.shared.log("停止设备监控", level: .info, category: "Monitor")
    }
    
    /// 轮询检查设备状态
    private func pollDevices() async {
        do {
            let devices = try await ADBManager.shared.scanDevices()
            let currentDeviceSerials = Set(devices.map { $0.serialNumber })
            
            // 检测新连接的设备
            let newDevices = currentDeviceSerials.subtracting(lastKnownDevices)
            for serial in newDevices {
                if let device = devices.first(where: { $0.serialNumber == serial }) {
                    LogManager.shared.log("设备已连接: \(device.displayName)", level: .info, category: "Monitor")
                    NotificationCenter.default.post(
                        name: .deviceConnected,
                        object: device
                    )
                    
                    // 如果配置了自动扫描，触发扫描
                    if ConfigManager.shared.config.autoScanOnConnect {
                        NotificationCenter.default.post(name: .scanFiles, object: device)
                    }
                }
            }
            
            // 检测断开的设备
            let disconnectedDevices = lastKnownDevices.subtracting(currentDeviceSerials)
            for serial in disconnectedDevices {
                LogManager.shared.log("设备已断开: \(serial)", level: .warning, category: "Monitor")
                NotificationCenter.default.post(
                    name: .deviceDisconnected,
                    object: serial
                )
            }
            
            lastKnownDevices = currentDeviceSerials
            
            await MainActor.run {
                self.connectedDevices = devices
            }
            
        } catch {
            // 静默处理错误，避免日志刷屏
            #if DEBUG
            print("设备轮询错误: \(error)")
            #endif
        }
    }
    
    /// 强制刷新设备列表
    func refreshDevices() async {
        await pollDevices()
    }
}

// MARK: - 设备存储信息获取

extension ADBManager {
    /// 获取设备存储信息
    func getStorageInfo(serialNumber: String) async throws -> (total: Int64, available: Int64) {
        let output = try await executeStorageCommand(serialNumber: serialNumber)
        return parseStorageInfo(output)
    }
    
    private func executeStorageCommand(serialNumber: String) async throws -> String {
        // 使用 df 命令获取存储信息
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/adb")
        process.arguments = ["-s", serialNumber, "shell", "df", "/sdcard"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func parseStorageInfo(_ output: String) -> (total: Int64, available: Int64) {
        let lines = output.components(separatedBy: .newlines)
        
        guard lines.count >= 2 else {
            return (0, 0)
        }
        
        // 解析 df 输出格式
        let components = lines[1].split(separator: " ", omittingEmptySubsequences: true)
        
        guard components.count >= 4 else {
            return (0, 0)
        }
        
        // df 输出单位通常是 1K 块
        let totalBlocks = Int64(components[1]) ?? 0
        let availableBlocks = Int64(components[3]) ?? 0
        
        return (totalBlocks * 1024, availableBlocks * 1024)
    }
}
// MARK: - Notification Names

extension Notification.Name {
    /// 设备已连接通知
    static let deviceConnected = Notification.Name("deviceConnected")
    /// 设备已断开通知
    static let deviceDisconnected = Notification.Name("deviceDisconnected")
    /// 同步完成通知
    static let syncCompleted = Notification.Name("syncCompleted")
    /// 同步失败通知
    static let syncFailed = Notification.Name("syncFailed")
    /// 刷新设备通知
    static let refreshDevices = Notification.Name("refreshDevices")
    /// 扫描设备通知
    static let scanDevices = Notification.Name("scanDevices")
    /// 扫描文件通知
    static let scanFiles = Notification.Name("scanFiles")
    /// 开始同步通知
    static let startSync = Notification.Name("startSync")
}

