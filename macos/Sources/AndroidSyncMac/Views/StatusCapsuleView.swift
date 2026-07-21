import AppKit
import SwiftUI

struct StatusCapsuleView: View {
    @Bindable var model: AppModel

    var body: some View {
        Menu {
            Button(model.text(model.isRunning ? .pause : .start)) {
                model.toggleReceiver()
            }
            if !model.uploadURL.isEmpty {
                Button(model.text(.copyAddress)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        model.uploadURL,
                        forType: .string
                    )
                }
            }
            Divider()
            Text(model.statusCapsuleDetail)
        } label: {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .frame(
                width: Theme.toolbarIconSize,
                height: Theme.toolbarIconSize
            )
            .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(statusHelp)
        .accessibilityLabel(model.statusCapsuleTitle)
    }

    private var statusHelp: String {
        "\(model.statusCapsuleTitle) · \(model.statusCapsuleDetail)"
    }

    private var statusColor: Color {
        switch model.status {
        case .running: Theme.statusRunning
        case .failed: Theme.statusFailed
        case .starting, .needsDirectory, .stopped: Theme.statusIdle
        }
    }
}
