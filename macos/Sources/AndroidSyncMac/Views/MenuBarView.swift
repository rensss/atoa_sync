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
        Button(
            model.text(model.isRunning ? .pauseReceiving : .startReceiving)
        ) {
            model.toggleReceiver()
        }
        if !model.uploadURL.isEmpty {
            Button(model.text(.copyUploadAddress)) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.uploadURL, forType: .string)
            }
        }
        Button(model.text(.openAndroidSync)) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button(model.text(.openReceiveFolder)) {
            model.openReceiveDirectory()
        }
        .disabled(model.receiveDirectory == nil)
        Divider()
        SettingsLink {
            Text(model.text(.settings))
        }
        Button(model.text(.quitAndroidSync)) {
            NSApplication.shared.terminate(nil)
        }
    }

    private var statusTitle: String {
        switch model.status {
        case .running: model.text(.receiverRunning)
        case .starting: model.text(.receiverStarting)
        case .failed: model.text(.receiverError)
        case .needsDirectory: model.text(.folderRequired)
        case .stopped: model.text(.receiverPaused)
        }
    }
}
