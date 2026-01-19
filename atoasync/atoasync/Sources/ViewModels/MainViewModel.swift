import Foundation
import SwiftUI
import Combine

@MainActor
class MainViewModel: ObservableObject {
    @Published var devices: [DeviceInfo] = []
    @Published var selectedDevice: DeviceInfo? {
        didSet {
            // 设备改变时清空之前的扫描结果
            if oldValue?.serialNumber != selectedDevice?.serialNumber {
                clearScanResults()
            }
        }
    }
    @Published var deviceFiles: [FileInfo] = []
    @Published var localFiles: [FileInfo] = []
    @Published var diffResult: DiffResult?
    @Published var selectedFiles: Set<UUID> = []
    @Published var targetPath: String = "" {
        didSet {
            // 目标路径改变时清空之前的扫描结果
            if oldValue != targetPath {
                clearScanResults()
            }
        }
    }
    @Published var isScanning: Bool = false
    @Published var isComparing: Bool = false
    @Published var isSyncing: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var scanProgress: Int = 0
    @Published var searchText: String = ""
    @Published var selectedFileTypes: Set<FileType> = []
    @Published var selectedDiffTypes: Set<DiffType> = [.new, .modified]
    @Published var conflictResolution: ConflictResolution = .askEachTime
    
    private let adbManager = ADBManager.shared
    private let fileScanner = FileScanner.shared
    private let diffEngine = DiffEngine.shared
    private let syncManager = SyncManager.shared
    private let configManager = ConfigManager.shared
    private let logManager = LogManager.shared
    
    init() {
        self.targetPath = configManager.config.defaultTargetPath
        self.conflictResolution = configManager.config.conflictResolution
    }
    
    func scanDevices() {
        Task {
            isScanning = true
            defer { isScanning = false }
            
            do {
                let foundDevices = try await adbManager.scanDevices()
                self.devices = foundDevices
                
                if !foundDevices.isEmpty {
                    self.selectedDevice = foundDevices[0]
                    logManager.log("发现 \(foundDevices.count) 个设备", level: .info, category: "Device")
                } else {
                    logManager.log("未发现任何设备", level: .warning, category: "Device")
                }
            } catch {
                handleError(error, message: "扫描设备失败")
            }
        }
    }
    
    func scanFiles() {
        guard let device = selectedDevice else {
            showErrorAlert("请先选择设备")
            return
        }
        
        guard !targetPath.isEmpty else {
            showErrorAlert("请选择目标路径")
            return
        }
        
        Task {
            isScanning = true
            scanProgress = 0
            
            // 清空之前的选择和结果
            selectedFiles.removeAll()
            diffResult = nil
            deviceFiles = []
            localFiles = []
            
            defer { isScanning = false }
            
            do {
                logManager.log("开始扫描设备文件...", level: .info, category: "Scan")
                
                let androidPath = "/sdcard"
                deviceFiles = try await fileScanner.scanAndroidDevice(
                    serialNumber: device.serialNumber,
                    path: androidPath
                ) { progress in
                    Task { @MainActor in
                        self.scanProgress = progress
                    }
                }
                
                logManager.log("设备扫描完成，发现 \(deviceFiles.count) 个文件", level: .info, category: "Scan")
                
                logManager.log("开始扫描本地文件...", level: .info, category: "Scan")
                
                localFiles = try await fileScanner.scanLocalDirectory(
                    at: targetPath,
                    calculateHash: configManager.config.enableHashComparison
                ) { progress in
                    Task { @MainActor in
                        self.scanProgress = progress
                    }
                }
                
                logManager.log("本地扫描完成，发现 \(localFiles.count) 个文件", level: .info, category: "Scan")
                
                await compareDifferences()
                
                // 扫描完成后自动选择所有新增和修改的文件
                if let diff = diffResult {
                    selectedFiles = Set((diff.newFiles + diff.modifiedFiles).map { $0.id })
                    logManager.log("自动选择了 \(selectedFiles.count) 个待同步文件", level: .info, category: "Scan")
                }
                
            } catch {
                handleError(error, message: "扫描文件失败")
            }
        }
    }
    
    func compareDifferences() async {
        isComparing = true
        defer { isComparing = false }
        
        logManager.log("开始比对文件差异...", level: .info, category: "Diff")
        
        let result = await diffEngine.compare(
            deviceFiles: deviceFiles,
            localFiles: localFiles,
            useHash: configManager.config.enableHashComparison
        )
        
        self.diffResult = result
        
        logManager.log("差异比对完成: \(result.summary)", level: .info, category: "Diff")
    }
    
    func startSync() {
        guard let device = selectedDevice else {
            showErrorAlert("请先选择设备")
            return
        }
        
        guard let diff = diffResult else {
            showErrorAlert("请先进行差异比对")
            return
        }
        
        let filesToSync = Array(selectedFiles).compactMap { id in
            diff.newFiles.first { $0.id == id } ??
            diff.modifiedFiles.first { $0.id == id }
        }
        
        guard !filesToSync.isEmpty else {
            showErrorAlert("请选择要同步的文件")
            return
        }
        
        Task {
            isSyncing = true
            defer { isSyncing = false }
            
            do {
                logManager.log("开始同步 \(filesToSync.count) 个文件", level: .info, category: "Sync")
                
                try await syncManager.startSync(
                    files: filesToSync,
                    device: device,
                    targetPath: targetPath,
                    conflictResolution: conflictResolution
                )
                
                logManager.log("同步完成", level: .info, category: "Sync")
                
                configManager.updateLastSyncPath(targetPath, for: device.serialNumber)
                
                await compareDifferences()
                
            } catch {
                handleError(error, message: "同步失败")
            }
        }
    }
    
    func selectTargetPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            targetPath = url.path
            configManager.config.defaultTargetPath = url.path
            configManager.save()
        }
    }
    
    func toggleFileSelection(_ fileId: UUID) {
        if selectedFiles.contains(fileId) {
            selectedFiles.remove(fileId)
        } else {
            selectedFiles.insert(fileId)
        }
    }
    
    func selectAllFiles() {
        guard let diff = diffResult else { return }
        
        selectedFiles = Set(
            (diff.newFiles + diff.modifiedFiles).map { $0.id }
        )
    }
    
    func deselectAllFiles() {
        selectedFiles.removeAll()
    }
    
    /// 清空扫描结果
    private func clearScanResults() {
        deviceFiles = []
        localFiles = []
        diffResult = nil
        selectedFiles.removeAll()
        scanProgress = 0
    }
    
    var filteredDiffResult: DiffResult? {
        guard let diff = diffResult else { return nil }
        
        return diffEngine.filterDiffResult(
            diff,
            searchText: searchText,
            fileTypes: selectedFileTypes,
            diffTypes: selectedDiffTypes
        )
    }
    
    private func handleError(_ error: Error, message: String) {
        let fullMessage = "\(message): \(error.localizedDescription)"
        logManager.log(fullMessage, level: .error, category: "Error")
        showErrorAlert(fullMessage)
    }
    
    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
    }
}
