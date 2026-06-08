import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(statusTitle)
        if !model.uploadURL.isEmpty {
            Text(model.uploadURL)
                .font(.caption)
        }
        Divider()
        Button(model.isRunning ? "Pause Receiving" : "Start Receiving") {
            model.toggleReceiver()
        }
        if !model.uploadURL.isEmpty {
            Button("Copy Upload Address") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.uploadURL, forType: .string)
            }
        }
        Button("Open Android Sync") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Open Receive Folder") {
            model.openReceiveDirectory()
        }
        .disabled(model.receiveDirectory == nil)
        Divider()
        SettingsLink()
        Button("Quit Android Sync") {
            NSApplication.shared.terminate(nil)
        }
    }

    private var statusTitle: String {
        switch model.status {
        case .running: "Receiver Running"
        case .starting: "Receiver Starting"
        case .failed: "Receiver Error"
        case .needsDirectory: "Folder Required"
        case .stopped: "Receiver Paused"
        }
    }
}
