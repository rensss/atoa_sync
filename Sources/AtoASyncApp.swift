import SwiftUI

@main
struct AtoASyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
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
                .keyboardShortcut("s", modifiers: .command)
            }
            
            CommandMenu("同步") {
                Button("开始同步") {
                    NotificationCenter.default.post(name: .startSync, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)
                
                Button("取消所有任务") {
                    SyncManager.shared.cancelAllSyncs()
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
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        LogManager.shared.log("应用退出", level: .info, category: "App")
        ConfigManager.shared.save()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let refreshDevices = Notification.Name("refreshDevices")
    static let scanFiles = Notification.Name("scanFiles")
    static let startSync = Notification.Name("startSync")
}
