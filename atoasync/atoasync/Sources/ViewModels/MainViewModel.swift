import Foundation
import SwiftUI
import Combine

@MainActor
class MainViewModel: ObservableObject {
    @Published var devices: [DeviceInfo] = []
    @Published var selectedDevice: DeviceInfo? {
        didSet {
            if oldValue?.serialNumber != selectedDevice?.serialNumber {
                clearScanResults()
            }
        }
    }
    @Published var deviceFiles: [FileInfo] = []
    private var allDeviceFiles: [FileInfo] = []
    @Published var localFiles: [FileInfo] = []
    @Published var diffResult: DiffResult?
    @Published var selectedFiles: Set<String> = []
    @Published var targetPath: String = "" {
        didSet {
            if oldValue != targetPath {
                clearScanResults()
            }
        }
    }
    @Published var isScanning: Bool = false
    @Published var isComparing: Bool = false
    @Published var isSyncing: Bool = false // Kept for monitoring completion
    @Published var isPreparingForSync: Bool = false
    @Published var activeSyncTask: SyncTask?
    @Published var lastSyncResult: SyncHistoryEntry?
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
    @Published var directorySizes: [String: Int64] = [:]
    @Published var loadingDirectorySizes: Set<String> = []
    @Published var failedDirectorySizes: Set<String> = []
    
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
    
    private let scanRootPath: String = "/sdcard"
    private var resolvedScanRootPathBySerial: [String: String] = [:]
    
    private var scanTask: Task<Void, Never>?
    private var directoryLoadTask: Task<Void, Never>?
    
    init() {
        self.targetPath = configManager.config.defaultTargetPath
        self.conflictResolution = configManager.config.conflictResolution
        setupDeviceMonitoring()
        setupSyncMonitoring()
    }
    
    var isBrowsing: Bool {
        currentDevicePath != scanRootPath
    }
    
    // MARK: - 取消扫描
    
    func cancelScanning() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        logManager.log("用户取消扫描", level: .info, category: "Scan")
    }
    
    // MARK: - 设备与同步监控
    
    private func setupDeviceMonitoring() {
        NotificationCenter.default.publisher(for: .deviceConnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let device = notification.object as? DeviceInfo else { return }
                self?.handleDeviceConnected(device)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .deviceDisconnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let serial = notification.object as? String else { return }
                self?.handleDeviceDisconnected(serial: serial)
            }
            .store(in: &cancellables)
        
        DeviceMonitor.shared.$connectedDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
            }
            .store(in: &cancellables)
    }

    private func setupSyncMonitoring() {
        syncManager.$activeTasks
            .receive(on: DispatchQueue.main)
            .map(\.first) // Assuming one sync task at a time for this UI
            .assign(to: &$activeSyncTask)
            
        syncManager.$isPreparing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPreparingForSync)

        // When a sync task disappears but we were in a syncing state, show the result.
        $activeSyncTask
            .combineLatest($isSyncing)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] task, syncing in
                guard let self = self else { return }
                if task == nil && syncing {
                    // Sync just finished.
                    self.isSyncing = false
                    self.lastSyncResult = SyncHistoryManager.shared.history.first
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleDeviceConnected(_ device: DeviceInfo) {
        logManager.log("设备已连接: \(device.displayName)", level: .info, category: "Device")
        if selectedDevice == nil {
            selectedDevice = device
        }
    }
    
    private func handleDeviceDisconnected(serial: String) {
        guard selectedDevice?.serialNumber == serial else { return }
        
        let deviceName = selectedDevice?.displayName ?? serial
        logManager.log("当前设备已断开: \(deviceName)", level: .warning, category: "Device")
        
        if activeSyncTask != nil {
            wasSyncingWhenDisconnected = true
            disconnectedDeviceName = deviceName
            showDeviceDisconnectedAlert = true
            
            syncManager.cancelAllSyncs()
            logManager.log("同步已中断：设备断开连接", level: .error, category: "Sync")
        } else {
            wasSyncingWhenDisconnected = false
            disconnectedDeviceName = deviceName
            showDeviceDisconnectedAlert = true
        }
        
        cancelScanning()
        directoryLoadTask?.cancel()
        
        selectedDevice = nil
        clearScanResults()
        
        isComparing = false
        isSyncing = false
        isLoadingDirectory = false
    }
    
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
        
        cancelScanning()
        
        scanTask = Task { [weak self] in
            guard let self else { return }
            
            await MainActor.run {
                self.isScanning = true
                self.scanProgress = 0
                self.selectedFiles.removeAll()
                self.diffResult = nil
                self.deviceFiles = []
                self.allDeviceFiles = []
                self.localFiles = []
            }
            
            defer {
                Task { @MainActor in
                    self.isScanning = false
                }
            }
            
            do {
                _ = try await resolveScanRootPath(for: device)
                logManager.log("扫描根路径: \(scanRootPath)", level: .debug, category: "Scan")
                
                if Task.isCancelled { throw CancellationError() }
                logManager.log("开始扫描设备文件...", level: .info, category: "Scan")
                
                let deviceFilesResult = try await fileScanner.scanAndroidDevice(
                    serialNumber: device.serialNumber,
                    path: scanRootPath
                ) { progress in
                    Task { @MainActor in
                        self.scanProgress = progress
                    }
                }
                
                if Task.isCancelled { throw CancellationError() }
                logManager.log("设备扫描完成，发现 \(deviceFilesResult.count) 个文件/目录", level: .info, category: "Scan")
                
                if Task.isCancelled { throw CancellationError() }
                logManager.log("开始扫描本地文件...", level: .info, category: "Scan")
                
                let localFilesResult = try await fileScanner.scanLocalDirectory(
                    at: targetPath,
                    calculateHash: configManager.config.enableHashComparison
                ) { progress in
                    Task { @MainActor in
                        self.scanProgress = progress
                    }
                }
                
                if Task.isCancelled { throw CancellationError() }
                logManager.log("本地扫描完成，发现 \(localFilesResult.count) 个文件", level: .info, category: "Scan")
                
                await MainActor.run {
                    self.allDeviceFiles = deviceFilesResult
                    self.localFiles = localFilesResult
                }
                
                await compareDifferences()
                
                if Task.isCancelled { throw CancellationError() }
                
                if let diff = await MainActor.run(body: { self.diffResult }) {
                    let keys = (diff.newFiles + diff.modifiedFiles).map { self.normalizeRelativeKey($0.relativePath) }
                    await MainActor.run {
                        self.selectedFiles = Set(keys)
                    }
                    logManager.log("自动选择了 \(keys.count) 个待同步文件", level: .info, category: "Scan")
                }
                
            } catch is CancellationError {
                logManager.log("扫描已取消", level: .info, category: "Scan")
            } catch {
                await MainActor.run {
                    self.handleError(error, message: "扫描文件失败")
                }
            }
        }
    }
    
    func compareDifferences() async {
        isComparing = true
        defer { isComparing = false }
        
        logManager.log("开始比对文件差异...", level: .info, category: "Diff")
        
        let result = await diffEngine.compare(
            deviceFiles: allDeviceFiles,
            localFiles: localFiles,
            useHash: configManager.config.enableHashComparison
        )
        
        self.diffResult = result
        logManager.log("差异比对完成: \(result.summary)", level: .info, category: "Diff")
    }
    
    // MARK: - 同步
    
    func startSync() {
        guard let device = selectedDevice else {
            showErrorAlert("请先选择设备")
            return
        }
        
        guard !targetPath.isEmpty else {
            showErrorAlert("请选择目标路径")
            return
        }
        
        lastSyncResult = nil
        isSyncing = true
        
        Task {
            do {
                let resolvedBase = try await resolveScanRootPath(for: device)
                
                // Determine the source list of files based on browsing state
                let sourceFileList = isBrowsing ? deviceFiles : allDeviceFiles
                
                let allFilesMap = Dictionary(sourceFileList.map { (normalizeRelativeKey($0.relativePath), $0) }, uniquingKeysWith: { (first, _) in first })
                let selectedItems = selectedFiles.compactMap { allFilesMap[$0] }

                guard !selectedItems.isEmpty else {
                    showErrorAlert("请选择要同步的文件或文件夹")
                    isSyncing = false
                    return
                }
                
                logManager.log("开始同步 \(selectedItems.count) 个选择项", level: .info, category: "Sync")
                
                try await syncManager.startSync(
                    items: selectedItems,
                    device: device,
                    sourceBasePath: resolvedBase,
                    targetPath: targetPath,
                    conflictResolution: conflictResolution
                )
                
                logManager.log("同步任务已提交", level: .info, category: "Sync")
                configManager.updateLastSyncPath(targetPath, for: device.serialNumber)
                
                if !isBrowsing {
                    await compareDifferences()
                }
                
            } catch {
                handleError(error, message: "同步失败")
                isSyncing = false // Manually reset on pre-flight failure
            }
        }
    }

    func pauseSync() {
        guard let task = activeSyncTask else { return }
        syncManager.pauseSync(taskId: task.id)
    }

    func resumeSync() {
        guard let task = activeSyncTask else { return }
        Task { try? await syncManager.resumeSync(taskId: task.id) }
    }

    func cancelSync() {
        guard let task = activeSyncTask else { return }
        syncManager.cancelSync(taskId: task.id)
    }

    func dismissSyncResult() {
        lastSyncResult = nil
    }
    
    // MARK: - Selection
    
    func toggleFileSelection(_ key: String) {
        if selectedFiles.contains(key) {
            selectedFiles.remove(key)
        } else {
            selectedFiles.insert(key)
        }
    }
    
    func deselectAllFiles() {
        selectedFiles.removeAll()
    }
    
    func selectAllFiles() {
        guard let diff = diffResult else { return }
        let keys = (diff.newFiles + diff.modifiedFiles).map { normalizeRelativeKey($0.relativePath) }
        selectedFiles = Set(keys)
    }
    
    // MARK: - 目标路径
    
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
    
    // MARK: - 清理
    
    private func clearScanResults() {
        allDeviceFiles = []
        deviceFiles = []
        localFiles = []
        diffResult = nil
        selectedFiles.removeAll()
        scanProgress = 0
        
        currentDevicePath = scanRootPath
        pathHistory = []
        directoryLoadTask?.cancel()
        
        directorySizes = [:]
        loadingDirectorySizes = []
        failedDirectorySizes = []
        
        resolvedScanRootPathBySerial = [:]
    }
    
    // MARK: - 文件夹导航
    
    func enterDirectory(_ file: FileInfo) {
        guard file.isDirectory else { return }
        guard selectedDevice != nil else { return }
        
        pathHistory.append(currentDevicePath)
        currentDevicePath = file.path
        loadCurrentDirectory()
    }
    
    func goBack() {
        guard !pathHistory.isEmpty else { return }
        currentDevicePath = pathHistory.removeLast()
        loadCurrentDirectory()
    }
    
    func goToRoot() {
        pathHistory.removeAll()
        currentDevicePath = scanRootPath
        loadCurrentDirectory()
    }
    
    func loadCurrentDirectory() {
        guard let device = selectedDevice else { return }
        
        directoryLoadTask?.cancel()
        
        directoryLoadTask = Task {
            isLoadingDirectory = true
            defer { isLoadingDirectory = false }
            
            do {
                _ = try await resolveScanRootPath(for: device)
                
                let files = try await adbManager.listFiles(
                    serialNumber: device.serialNumber,
                    path: currentDevicePath
                )
                
                deviceFiles = files.sorted { file1, file2 in
                    if file1.isDirectory != file2.isDirectory {
                        return file1.isDirectory
                    }
                    return file1.fileName.localizedCaseInsensitiveCompare(file2.fileName) == .orderedAscending
                }
                
                loadAllDirectorySizes()
                
            } catch is CancellationError {
                logManager.log("目录加载已取消: \(currentDevicePath)", level: .info, category: "Browse")
            } catch {
                handleError(error, message: "加载目录失败")
            }
        }
    }
    
    func cancelLoadingDirectory() {
        directoryLoadTask?.cancel()
        isLoadingDirectory = false
        logManager.log("用户取消目录加载", level: .info, category: "Browse")
    }
    
    func exitBrowsingMode() {
        currentDevicePath = scanRootPath
        pathHistory = []
        deviceFiles = []
        
        directorySizes = [:]
        loadingDirectorySizes = []
        failedDirectorySizes = []
    }
    
    // MARK: - 目录大小
    
    func loadDirectorySize(for file: FileInfo) {
        guard file.isDirectory else { return }
        guard let device = selectedDevice else { return }
        guard !loadingDirectorySizes.contains(file.path) else { return }
        
        failedDirectorySizes.remove(file.path)
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
                    self.failedDirectorySizes.remove(file.path)
                }
            } catch {
                await MainActor.run {
                    self.loadingDirectorySizes.remove(file.path)
                    self.failedDirectorySizes.insert(file.path)
                }
            }
        }
    }
    
    func loadAllDirectorySizes() {
        guard let device = selectedDevice else { return }
        
        let directories = deviceFiles.filter { $0.isDirectory && directorySizes[$0.path] == nil && !failedDirectorySizes.contains($0.path) }
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
                for path in paths {
                    self.loadingDirectorySizes.remove(path)
                }
                
                for (path, size) in sizes {
                    self.directorySizes[path] = size
                    self.failedDirectorySizes.remove(path)
                }
                
                let returned = Set(sizes.keys)
                let failed = Set(paths).subtracting(returned)
                self.failedDirectorySizes.formUnion(failed)
            }
        }
    }
    
    func formattedDirectorySize(for path: String) -> String? {
        guard let size = directorySizes[path] else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    func isLoadingSize(for path: String) -> Bool {
        loadingDirectorySizes.contains(path)
    }
    
    func isFailedSize(for path: String) -> Bool {
        failedDirectorySizes.contains(path)
    }
    
    // MARK: - 路径组件
    
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
    
    var canGoBack: Bool {
        !pathHistory.isEmpty
    }
    
    // MARK: - Diff 过滤
    
    var filteredDiffResult: DiffResult? {
        guard let diff = diffResult else { return nil }
        
        return diffEngine.filterDiffResult(
            diff,
            searchText: searchText,
            fileTypes: selectedFileTypes,
            diffTypes: selectedDiffTypes
        )
    }
    
    // MARK: - RelativePath 统一
    
    private func normalizeRelativeKey(_ relativePath: String) -> String {
        if relativePath == "/" { return "" }
        if relativePath.hasPrefix("/") {
            return String(relativePath.dropFirst())
        }
        return relativePath
    }
    
    private func resolveScanRootPath(for device: DeviceInfo) async throws -> String {
        if let cached = resolvedScanRootPathBySerial[device.serialNumber] {
            return cached
        }
        
        let resolved = try await adbManager.resolvePath(serialNumber: device.serialNumber, path: scanRootPath)
        resolvedScanRootPathBySerial[device.serialNumber] = resolved
        return resolved
    }
    
    private func relativeKey(forDeviceFullPath fullPath: String, resolvedBasePath basePath: String) -> String {
        var rel = fullPath
        if rel.hasPrefix(basePath) {
            rel = String(rel.dropFirst(basePath.count))
        } else if rel.hasPrefix(scanRootPath) {
            rel = String(rel.dropFirst(scanRootPath.count))
        }
        if rel.hasPrefix("/") {
            rel = String(rel.dropFirst())
        }
        return rel
    }
    
    // MARK: - Error
    
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
