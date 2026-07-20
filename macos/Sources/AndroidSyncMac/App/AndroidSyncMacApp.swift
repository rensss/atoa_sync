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
            _appModel = State(
                initialValue: AppModel(
                    modelContainer: container,
                    libraryKeyMonitor: AppKitLibraryKeyMonitor()
                )
            )
        } catch {
            fatalError("Unable to create Android Sync database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("Android Sync", id: "main") {
            ContentView(model: appModel)
                .frame(minWidth: 860, minHeight: 560)
                .environment(\.locale, appModel.language.locale)
                .preferredColorScheme(.dark)
                .task { await appModel.launchIfNeeded() }
        }
        .modelContainer(modelContainer)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .newItem) {
                Button(appModel.text(.chooseReceiveFolderEllipsis)) {
                    appModel.chooseDirectory()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("Android Sync", systemImage: appModel.menuBarSystemImage) {
            MenuBarView(model: appModel)
                .environment(\.locale, appModel.language.locale)
                .preferredColorScheme(.dark)
        }

        Settings {
            SettingsView(model: appModel)
                .environment(\.locale, appModel.language.locale)
                .preferredColorScheme(.dark)
        }
    }
}
