import SwiftUI

struct TransferCardRow: View {
    @Bindable var model: AppModel
    private let cardHeight: CGFloat = 96

    var body: some View {
        VStack(spacing: Theme.spacingS) {
            if let message = model.transientUploadMessage {
                banner(message)
            }
            switch model.transferCardState {
            case .idle:
                EmptyView()
            case .receiving:
                HStack(spacing: Theme.spacingM) {
                    progressCard
                    statsCard
                }
            }
        }
        .padding(.horizontal, Theme.spacingL)
        .padding(.top, contentIsEmpty ? 0 : Theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Theme.bg)
    }

    private var contentIsEmpty: Bool {
        model.transferCardState == .idle
            && model.transientUploadMessage == nil
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            HStack(spacing: Theme.spacingS) {
                Text(
                    model.format(
                        .receivingProgressFormat,
                        model.transferCompletedCount,
                        max(1, model.transferTotalCount),
                        model.transferRemainingDescription,
                        model.transferETADescription
                    )
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                Spacer(minLength: Theme.spacingS)
                Button {
                    model.toggleReceiver()
                } label: {
                    Label(
                        model.text(.pauseReceiving),
                        systemImage: "stop.fill"
                    )
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.white)
                .help(model.text(.pauseReceiving))
            }
            if let progress = model.transferProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.white)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.white)
            }
            Text(speedText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .opacity(model.transferSpeedBytesPerSecond == nil ? 0 : 1)
                .frame(height: 16, alignment: .leading)
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .fill(Theme.cardGradient)
        )
    }

    private var speedText: String {
        guard let speed = model.transferSpeedBytesPerSecond else {
            return " "
        }
        return model.format(
            .speedFormat,
            model.formatByteCount(speed)
        )
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Text(model.text(.todayReceived))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: Theme.spacingS) {
                Text(model.format(.itemsCountFormat, model.todayStats.count))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(model.formatByteCount(model.todayStats.bytes))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.spacingM)
        .frame(width: 180, alignment: .leading)
        .frame(minHeight: cardHeight, maxHeight: cardHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .fill(Theme.bgRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .strokeBorder(Theme.stroke)
        )
    }

    private func banner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(Theme.statusFailed)
            .padding(.vertical, Theme.spacingS)
            .padding(.horizontal, Theme.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusS)
                    .fill(Theme.statusFailed.opacity(0.12))
            )
    }
}
