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
            HStack(spacing: Theme.spacingXS + 2) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(model.statusCapsuleTitle)
                    .font(.callout)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(model.statusCapsuleDetail)
    }

    private var statusColor: Color {
        switch model.status {
        case .running: Theme.statusRunning
        case .failed: Theme.statusFailed
        case .starting, .needsDirectory, .stopped: Theme.statusIdle
        }
    }
}
