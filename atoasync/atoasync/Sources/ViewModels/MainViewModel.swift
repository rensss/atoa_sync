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
    @Published var isBrowsingMode: Bool = false
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
    
    init() {
        self.targetPath = configManager.config.defaultTargetPath
        self.conflictResolution = configManager.config.conflictResolution
        setupDeviceMonitoring()
    }
    
    // MARK: - 取消扫描
    
    func cancelScanning() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        logManager.log("用户取消扫描", level: .info, category: "Scan")
    }
    
    // MARK: - 设备监控
    
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
        
        if isSyncing {
            wasSyncingWhenDisconnected = true
            disconnectedDeviceName = deviceName
            showDeviceDisconnectedAlert = true
            
            Task { await syncManager.cancelAllSyncs() }
            logManager.log("同步已中断：设备断开连接", level: .error, category: "Sync")
        } else {
            wasSyncingWhenDisconnected = false
            disconnectedDeviceName = deviceName
            showDeviceDisconnectedAlert = true
        }
        
        // 断开时也取消扫描
        cancelScanning()
        
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
        
        // 若已有扫描，先取消
        cancelScanning()
        
        scanTask = Task { [weak self] in
            guard let self else { return }
            
            await MainActor.run {
                self.isScanning = true
                self.scanProgress = 0
                self.selectedFiles.removeAll()
                self.diffResult = nil
                self.deviceFiles = []
                self.localFiles = []
            }
            
            defer {
                Task { @MainActor in
                    self.isScanning = false
                }
            }
            
            do {
                let resolvedBase = try await resolveScanRootPath(for: device)
                logManager.log("扫描根路径: \(scanRootPath) -> \(resolvedBase)", level: .debug, category: "Scan")
                
                if Task.isCancelled { throw CancellationError() }
                logManager.log("开始扫描设备文件...", level: .info, category: "Scan")
                
                let deviceFiles = try await fileScanner.scanAndroidDevice(
                    serialNumber: device.serialNumber,
                    path: scanRootPath
                ) { progress in
                    Task { @MainActor in
                        self.scanProgress = progress
                    }
                }
                
                if Task.isCancelled { throw CancellationError() }
                logManager.log("设备扫描完成，发现 \(deviceFiles.count) 个文件/目录", level: .info, category: "Scan")
                
                if Task.isCancelled { throw CancellationError() }
                logManager.log("开始扫描本地文件...", level: .info, category: "Scan")
                
                let localFiles = try await fileScanner.scanLocalDirectory(
                    at: targetPath,
                    calculateHash: configManager.config.enableHashComparison
                ) { progress in
                    Task { @MainActor in
                        self.scanProgress = progress
                    }
                }
                
                if Task.isCancelled { throw CancellationError() }
                logManager.log("本地扫描完成，发现 \(localFiles.count) 个文件", level: .info, category: "Scan")
                
                await MainActor.run {
                    self.deviceFiles = deviceFiles
                    self.localFiles = localFiles
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
            deviceFiles: deviceFiles,
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
        
        Task {
            isSyncing = true
            defer { isSyncing = false }
            
            do {
                let resolvedBase = try await resolveScanRootPath(for: device)
                
                let selectedItems: [FileInfo]
                
                if isBrowsingMode {
                    selectedItems = deviceFiles.filter { file in
                        let key = relativeKey(forDeviceFullPath: file.path, resolvedBasePath: resolvedBase)
                        return selectedFiles.contains(key)
                    }
                } else {
                    guard let diff = diffResult else {
                        showErrorAlert("请先进行差异比对")
                        return
                    }
                    let candidates = diff.newFiles + diff.modifiedFiles
                    selectedItems = candidates.filter { selectedFiles.contains(normalizeRelativeKey($0.relativePath)) }
                }
                
                guard !selectedItems.isEmpty else {
                    showErrorAlert("请选择要同步的文件或文件夹")
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
                
                logManager.log("同步完成", level: .info, category: "Sync")
                configManager.updateLastSyncPath(targetPath, for: device.serialNumber)
                
                if !isBrowsingMode {
                    await compareDifferences()
                }
                
            } catch {
                handleError(error, message: "同步失败")
            }
        }
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
        deviceFiles = []
        localFiles = []
        diffResult = nil
        selectedFiles.removeAll()
        scanProgress = 0
        
        currentDevicePath = scanRootPath
        pathHistory = []
        isBrowsingMode = false
        
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
        
        isBrowsingMode = true
        
        Task {
            isLoadingDirectory = true
            defer { isLoadingDirectory = false }
            
            do {
                _ = try await resolveScanRootPath(for: device)
                
                deviceFiles = try await adbManager.listFiles(
                    serialNumber: device.serialNumber,
                    path: currentDevicePath
                )
                
                deviceFiles.sort { file1, file2 in
                    if file1.isDirectory != file2.isDirectory {
                        return file1.isDirectory
                    }
                    return file1.fileName.localizedCaseInsensitiveCompare(file2.fileName) == .orderedAscending
                }
                
                loadAllDirectorySizes()
                
            } catch is CancellationError {
                // ignore
            } catch {
                handleError(error, message: "加载目录失败")
            }
        }
    }
    
    func exitBrowsingMode() {
        isBrowsingMode = false
        deviceFiles = []
        currentDevicePath = scanRootPath
        pathHistory = []
        
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
