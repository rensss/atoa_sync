import AppKit
import SwiftUI

struct StatusCapsuleView: View {
    @Bindable var model: AppModel
    let categoryTitle: String?
    let itemCount: Int?

    init(
        model: AppModel,
        categoryTitle: String? = nil,
        itemCount: Int? = nil
    ) {
        self.model = model
        self.categoryTitle = categoryTitle
        self.itemCount = itemCount
    }

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
            if let categoryTitle, let itemCount {
                HStack(spacing: Theme.spacingS) {
                    Text("\(categoryTitle) \(itemCount)")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    statusDot
                }
            } else {
                Text(model.statusCapsuleTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help(statusHelp)
        .accessibilityLabel(accessibilityTitle)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 7, height: 7)
    }

    private var statusHelp: String {
        "\(model.statusCapsuleTitle) · \(model.statusCapsuleDetail)"
    }

    private var accessibilityTitle: String {
        guard let categoryTitle, let itemCount else {
            return model.statusCapsuleTitle
        }
        return "\(categoryTitle) \(itemCount), \(model.statusCapsuleTitle)"
    }

    private var statusColor: Color {
        switch model.status {
        case .running: Theme.statusRunning
        case .failed: Theme.statusFailed
        case .starting, .needsDirectory, .stopped: Theme.statusIdle
        }
    }
}
