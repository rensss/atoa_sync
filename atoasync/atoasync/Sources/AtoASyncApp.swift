import SwiftUI
import UserNotifications

@main
struct AtoASyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var statusBarManager = StatusBarManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .environmentObject(statusBarManager)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            
            CommandMenu("设备") {
                Button("刷新设备列表") {
                    NotificationCenter.default.post(name: .refreshDevices, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("扫描文件") {
                    NotificationCenter.default.post(name: .scanFiles, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            
            CommandMenu("同步") {
                Button("开始同步") {
                    NotificationCenter.default.post(name: .startSync, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)
                
                Button("取消所有任务") {
                    Task {
                        await SyncManager.shared.cancelAllSyncs()
                    }
                }
                .keyboardShortcut(".", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
                .frame(width: 600, height: 400)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        LogManager.shared.log("应用启动", level: .info, category: "App")
        
        // 请求通知权限
        requestNotificationPermission()
        
        // 初始化菜单栏图标
        StatusBarManager.shared.setup()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        LogManager.shared.log("应用退出", level: .info, category: "App")
        ConfigManager.shared.save()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                LogManager.shared.log("通知权限已授予", level: .info, category: "App")
            } else if let error = error {
                LogManager.shared.log("通知权限请求失败: \(error.localizedDescription)", level: .error, category: "App")
            }
        }
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let scanDevices = Notification.Name("scanDevices")
    static let scanFiles = Notification.Name("scanFiles")
    static let startSync = Notification.Name("startSync")
}
