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
                Text(model.uploadURL.isEmpty ? "Port \(model.port)" : model.uploadURL)
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
                    Label("Copy Address", systemImage: "doc.on.doc")
                }
            }
            if model.isRunning {
                Button("Pause") {
                    model.toggleReceiver()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Start") {
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
        case .needsDirectory: "Receive folder required"
        case .stopped: "Receiver paused"
        case .starting: "Starting receiver…"
        case .running: "Ready to receive"
        case .failed: "Receiver unavailable"
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
