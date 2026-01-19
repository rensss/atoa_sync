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
    
    // 文件浏览相关
    @Published var currentDevicePath: String = "/sdcard"
    @Published var pathHistory: [String] = []
    @Published var isLoadingDirectory: Bool = false
    @Published var isBrowsingMode: Bool = false  // 是否处于浏览模式
    @Published var directorySizes: [String: Int64] = [:]  // 目录大小缓存
    @Published var loadingDirectorySizes: Set<String> = []  // 正在加载大小的目录
    
    // 设备断开提示
    @Published var showDeviceDisconnectedAlert: Bool = false
    @Published var disconnectedDeviceName: String = ""
    @Published var wasSyncingWhenDisconnected: Bool = false
    
    private let adbManager = ADBManager.shared
    private let fileScanner = FileScanner.shared
    private let diffEngine = DiffEngine.shared
    private let syncManager = SyncManager.shared
    private let configManager = ConfigManager.shared
    private let logManager = LogManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.targetPath = configManager.config.defaultTargetPath
        self.conflictResolution = configManager.config.conflictResolution
        
        setupDeviceMonitoring()
    }
    
    // MARK: - 设备监控
    
    private func setupDeviceMonitoring() {
        // 监听设备连接
        NotificationCenter.default.publisher(for: .deviceConnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let device = notification.object as? DeviceInfo else { return }
                self?.handleDeviceConnected(device)
            }
            .store(in: &cancellables)
        
        // 监听设备断开
        NotificationCenter.default.publisher(for: .deviceDisconnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let serial = notification.object as? String else { return }
                self?.handleDeviceDisconnected(serial: serial)
            }
            .store(in: &cancellables)
        
        // 监听设备监控器的设备列表变化
        DeviceMonitor.shared.$connectedDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
            }
            .store(in: &cancellables)
    }
    
    private func handleDeviceConnected(_ device: DeviceInfo) {
        logManager.log("设备已连接: \(device.displayName)", level: .info, category: "Device")
        
        // 如果当前没有选中设备，自动选择新连接的设备
        if selectedDevice == nil {
            selectedDevice = device
        }
    }
    
    private func handleDeviceDisconnected(serial: String) {
        // 检查是否是当前选中的设备
        guard selectedDevice?.serialNumber == serial else { return }
        
        let deviceName = selectedDevice?.displayName ?? serial
        
        logManager.log("当前设备已断开: \(deviceName)", level: .warning, category: "Device")
        
        // 检查是否正在同步
        if isSyncing {
            wasSyncingWhenDisconnected = true
            disconnectedDeviceName = deviceName
            showDeviceDisconnectedAlert = true
            
            // 取消同步任务
            Task {
                await syncManager.cancelAllSyncs()
            }
            
            logManager.log("同步已中断：设备断开连接", level: .error, category: "Sync")
        } else {
            wasSyncingWhenDisconnected = false
            disconnectedDeviceName = deviceName
            showDeviceDisconnectedAlert = true
        }
        
        // 清空当前设备相关的状态
        selectedDevice = nil
        clearScanResults()
        
        // 停止正在进行的操作
        isScanning = false
        isComparing = false
        isSyncing = false
        isLoadingDirectory = false
    }
    
    /// 重新连接设备后的处理
    func reconnectDevice() {
        scanDevices()
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
    
    /// 浏览模式下的同步（同步选中的文件和文件夹）
    func startBrowserSync() {
        guard let device = selectedDevice else {
            showErrorAlert("请先选择设备")
            return
        }
        
        guard !targetPath.isEmpty else {
            showErrorAlert("请选择目标路径")
            return
        }
        
        // 获取选中的文件
        let filesToSync = deviceFiles.filter { selectedFiles.contains($0.id) }
        
        guard !filesToSync.isEmpty else {
            showErrorAlert("请选择要同步的文件或文件夹")
            return
        }
        
        Task {
            isSyncing = true
            defer { isSyncing = false }
            
            do {
                logManager.log("开始浏览模式同步 \(filesToSync.count) 个项目", level: .info, category: "Sync")
                
                // 计算目标路径（保持相对路径结构）
                let basePath = currentDevicePath
                
                try await syncManager.startBrowserSync(
                    files: filesToSync,
                    device: device,
                    sourcePath: basePath,
                    targetPath: targetPath,
                    conflictResolution: conflictResolution
                )
                
                logManager.log("浏览模式同步完成", level: .info, category: "Sync")
                
                configManager.updateLastSyncPath(targetPath, for: device.serialNumber)
                
                // 清空选中状态
                selectedFiles.removeAll()
                
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
        currentDevicePath = "/sdcard"
        pathHistory = []
        isBrowsingMode = false
    }
    
    // MARK: - 文件夹导航
    
    /// 进入文件夹
    func enterDirectory(_ file: FileInfo) {
        guard file.isDirectory else { return }
        guard let device = selectedDevice else { return }
        
        pathHistory.append(currentDevicePath)
        currentDevicePath = file.path
        
        loadCurrentDirectory()
    }
    
    /// 返回上一级目录
    func goBack() {
        guard !pathHistory.isEmpty else { return }
        currentDevicePath = pathHistory.removeLast()
        loadCurrentDirectory()
    }
    
    /// 返回根目录
    func goToRoot() {
        pathHistory.removeAll()
        currentDevicePath = "/sdcard"
        loadCurrentDirectory()
    }
    
    /// 加载当前目录
    func loadCurrentDirectory() {
        guard let device = selectedDevice else { return }
        
        // 进入浏览模式
        isBrowsingMode = true
        
        Task {
            isLoadingDirectory = true
            defer { isLoadingDirectory = false }
            
            do {
                logManager.log("加载目录: \(currentDevicePath)", level: .info, category: "Browse")
                
                deviceFiles = try await adbManager.listFiles(
                    serialNumber: device.serialNumber,
                    path: currentDevicePath
                )
                
                // 按文件夹优先、名称排序
                deviceFiles.sort { file1, file2 in
                    if file1.isDirectory != file2.isDirectory {
                        return file1.isDirectory
                    }
                    return file1.fileName.localizedCaseInsensitiveCompare(file2.fileName) == .orderedAscending
                }
                
                logManager.log("目录加载完成，共 \(deviceFiles.count) 个项目", level: .info, category: "Browse")
                
                // 自动开始计算所有文件夹的大小
                loadAllDirectorySizes()
                
            } catch {
                handleError(error, message: "加载目录失败")
            }
        }
    }
    
    /// 退出浏览模式
    func exitBrowsingMode() {
        isBrowsingMode = false
        deviceFiles = []
        currentDevicePath = "/sdcard"
        pathHistory = []
        directorySizes = [:]
        loadingDirectorySizes = []
    }
    
    /// 获取单个目录的大小
    func loadDirectorySize(for file: FileInfo) {
        guard file.isDirectory else { return }
        guard let device = selectedDevice else { return }
        guard !loadingDirectorySizes.contains(file.path) else { return }
        guard directorySizes[file.path] == nil else { return }
        
        loadingDirectorySizes.insert(file.path)
        
        Task {
            do {
                let size = try await adbManager.getDirectorySize(
                    serialNumber: device.serialNumber,
                    remotePath: file.path
                )
                
                await MainActor.run {
                    self.directorySizes[file.path] = size
                    self.loadingDirectorySizes.remove(file.path)
                }
                
                logManager.log("目录大小: \(file.fileName) = \(formatBytes(size))", level: .debug, category: "Browse")
                
            } catch {
                await MainActor.run {
                    self.loadingDirectorySizes.remove(file.path)
                }
                logManager.log("获取目录大小失败: \(file.path) - \(error.localizedDescription)", level: .warning, category: "Browse")
            }
        }
    }
    
    /// 批量加载当前目录下所有文件夹的大小
    func loadAllDirectorySizes() {
        guard let device = selectedDevice else { return }
        
        let directories = deviceFiles.filter { $0.isDirectory && directorySizes[$0.path] == nil }
        guard !directories.isEmpty else { return }
        
        for dir in directories {
            loadingDirectorySizes.insert(dir.path)
        }
        
        Task {
            let paths = directories.map { $0.path }
            let sizes = await adbManager.getDirectorySizes(
                serialNumber: device.serialNumber,
                remotePaths: paths
            )
            
            await MainActor.run {
                for (path, size) in sizes {
                    self.directorySizes[path] = size
                }
                for path in paths {
                    self.loadingDirectorySizes.remove(path)
                }
            }
            
            logManager.log("批量获取了 \(sizes.count) 个目录的大小", level: .info, category: "Browse")
        }
    }
    
    /// 获取目录大小的格式化字符串
    func formattedDirectorySize(for path: String) -> String? {
        guard let size = directorySizes[path] else { return nil }
        return formatBytes(size)
    }
    
    /// 检查目录大小是否正在加载
    func isLoadingSize(for path: String) -> Bool {
        return loadingDirectorySizes.contains(path)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 当前路径的各级组件（用于面包屑导航）
    var pathComponents: [(name: String, path: String)] {
        var components: [(String, String)] = []
        var currentPath = ""
        
        let parts = currentDevicePath.split(separator: "/").map(String.init)
        for part in parts {
            currentPath += "/" + part
            components.append((part, currentPath))
        }
        
        return components
    }
    
    /// 是否可以返回上一级
    var canGoBack: Bool {
        return !pathHistory.isEmpty
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
