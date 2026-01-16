import AppKit
import SwiftUI
import Combine
import UserNotifications

/// 菜单栏状态图标管理器
@MainActor
class StatusBarManager: ObservableObject {
    static let shared = StatusBarManager()
    
    @Published var syncStatus: SyncStatusType = .idle
    @Published var currentProgress: Double = 0
    @Published var connectedDeviceCount: Int = 0
    
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var animationTimer: Timer?
    private var animationFrame = 0
    
    private init() {
        setupObservers()
    }
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        setupMenu()
    }
    
    private func setupObservers() {
        // 监听同步完成通知
        NotificationCenter.default.publisher(for: .syncCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.syncStatus = .completed
                self?.showSyncCompletedNotification(notification.object as? SyncTask)
                
                // 3秒后恢复空闲状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.syncStatus = .idle
                    self?.updateStatusIcon()
                }
            }
            .store(in: &cancellables)
        
        // 监听同步失败通知
        NotificationCenter.default.publisher(for: .syncFailed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.syncStatus = .failed
                self?.showSyncFailedNotification(notification.object as? Error)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.syncStatus = .idle
                    self?.updateStatusIcon()
                }
            }
            .store(in: &cancellables)
    }
    
    func startSyncing() {
        syncStatus = .syncing
        startAnimation()
        updateStatusIcon()
    }
    
    func updateProgress(_ progress: Double) {
        currentProgress = progress
    }
    
    func stopSyncing(success: Bool) {
        stopAnimation()
        syncStatus = success ? .completed : .failed
        updateStatusIcon()
    }
    
    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        
        let imageName: String
        let color: NSColor
        
        switch syncStatus {
        case .idle:
            imageName = "arrow.triangle.2.circlepath"
            color = .secondaryLabelColor
        case .syncing:
            imageName = "arrow.triangle.2.circlepath"
            color = .systemBlue
        case .completed:
            imageName = "checkmark.circle.fill"
            color = .systemGreen
        case .failed:
            imageName = "exclamationmark.triangle.fill"
            color = .systemRed
        }
        
        if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Sync Status") {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let coloredImage = image.withSymbolConfiguration(config)
            button.image = coloredImage
            button.contentTintColor = color
        }
        
        // 更新工具提示
        button.toolTip = syncStatus.description
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // 状态显示
        let statusItem = NSMenuItem(title: "状态: 空闲", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 设备信息
        let deviceItem = NSMenuItem(title: "已连接设备: 0", action: nil, keyEquivalent: "")
        deviceItem.tag = 101
        menu.addItem(deviceItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 操作按钮
        menu.addItem(NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "刷新设备", action: #selector(refreshDevices), keyEquivalent: "r"))
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        self.statusItem?.menu = menu
    }
    
    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func refreshDevices() {
        NotificationCenter.default.post(name: .refreshDevices, object: nil)
    }
    
    func updateDeviceCount(_ count: Int) {
        connectedDeviceCount = count
        if let menu = statusItem?.menu,
           let item = menu.item(withTag: 101) {
            item.title = "已连接设备: \(count)"
        }
    }
    
    func updateMenuStatus(_ status: String) {
        if let menu = statusItem?.menu,
           let item = menu.item(withTag: 100) {
            item.title = "状态: \(status)"
        }
    }
    
    // MARK: - 动画
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.animateIcon()
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationFrame = 0
    }
    
    private func animateIcon() {
        guard let button = statusItem?.button else { return }
        
        animationFrame = (animationFrame + 1) % 4
        
        let rotation = CGFloat(animationFrame) * 90
        button.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        button.layer?.setAffineTransform(CGAffineTransform(rotationAngle: rotation * .pi / 180))
    }
    
    // MARK: - 系统通知
    
    private func showSyncCompletedNotification(_ task: SyncTask?) {
        let content = UNMutableNotificationContent()
        content.title = "同步完成"
        
        if let task = task {
            content.body = "已成功同步 \(task.processedFiles) 个文件"
        } else {
            content.body = "文件同步已完成"
        }
        
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil as UNNotificationTrigger?
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func showSyncFailedNotification(_ error: Error?) {
        let content = UNMutableNotificationContent()
        content.title = "同步失败"
        content.body = error?.localizedDescription ?? "同步过程中发生错误"
        content.sound = UNNotificationSound.defaultCritical
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil as UNNotificationTrigger?
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - 同步状态类型

enum SyncStatusType: String {
    case idle = "空闲"
    case syncing = "同步中"
    case completed = "已完成"
    case failed = "失败"
    
    var description: String {
        switch self {
        case .idle:
            return "AtoA Sync - 空闲"
        case .syncing:
            return "AtoA Sync - 正在同步..."
        case .completed:
            return "AtoA Sync - 同步完成"
        case .failed:
            return "AtoA Sync - 同步失败"
        }
    }
}
