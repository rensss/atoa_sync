import AppKit
import SwiftUI

struct ReceiverStatusView: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)
                Text(
                    model.uploadURL.isEmpty
                        ? model.format(.portFormat, Int(model.port))
                        : model.uploadURL
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            if !model.uploadURL.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.uploadURL, forType: .string)
                } label: {
                    Label(model.text(.copyAddress), systemImage: "doc.on.doc")
                }
            }
            if model.isRunning {
                Button(model.text(.pause)) {
                    model.toggleReceiver()
                }
                .buttonStyle(.bordered)
            } else {
                Button(model.text(.start)) {
                    model.toggleReceiver()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var statusTitle: String {
        switch model.status {
        case .needsDirectory: model.text(.receiveFolderRequired)
        case .stopped: model.text(.receiverPaused)
        case .starting: model.text(.startingReceiver)
        case .running: model.text(.readyToReceive)
        case .failed: model.text(.receiverUnavailable)
        }
    }

    private var statusIcon: String {
        switch model.status {
        case .running: "checkmark.circle.fill"
        case .starting: "arrow.triangle.2.circlepath"
        case .failed: "exclamationmark.triangle.fill"
        case .needsDirectory: "folder.badge.questionmark"
        case .stopped: "pause.circle"
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .running: .green
        case .failed: .red
        case .starting: .blue
        case .needsDirectory, .stopped: .secondary
        }
    }
}
