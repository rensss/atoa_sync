import AppKit
import SwiftData
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct AndroidSyncMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer
    @State private var appModel: AppModel

    init() {
        do {
            let container = try ModelContainer(for: MediaItemEntity.self)
            modelContainer = container
            _appModel = State(initialValue: AppModel(modelContainer: container))
        } catch {
            fatalError("Unable to create Android Sync database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("Android Sync", id: "main") {
            ContentView(model: appModel)
                .frame(minWidth: 860, minHeight: 560)
                .task { await appModel.launchIfNeeded() }
        }
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Choose Receive Folder…") {
                    appModel.chooseDirectory()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("Android Sync", systemImage: appModel.menuBarSystemImage) {
            MenuBarView(model: appModel)
        }

        Settings {
            SettingsView(model: appModel)
        }
    }
}
