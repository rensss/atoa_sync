import SwiftUI

struct TransferCardRow: View {
    @Bindable var model: AppModel

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
            case let .completed(count):
                HStack(spacing: Theme.spacingM) {
                    completedCard(count)
                    statsCard
                }
            }
        }
        .padding(.horizontal, Theme.spacingL)
        .padding(.top, contentIsEmpty ? 0 : Theme.spacingM)
        .animation(
            .easeInOut(duration: 0.25),
            value: model.transferCardState
        )
        .animation(
            .easeInOut(duration: 0.25),
            value: model.transientUploadMessage
        )
    }

    private var contentIsEmpty: Bool {
        model.transferCardState == .idle
            && model.transientUploadMessage == nil
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Text(
                model.format(
                    .receivingSummaryFormat,
                    model.activeUploads.count,
                    model.formatByteCount(model.activeUploadsExpectedBytes)
                )
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            if let progress = model.transferProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.white)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.white)
            }
            if let speed = model.transferSpeedBytesPerSecond {
                Text(
                    model.format(
                        .speedFormat,
                        model.formatByteCount(speed)
                    )
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .fill(Theme.cardGradient)
        )
    }

    private func completedCard(_ count: Int) -> some View {
        HStack(spacing: Theme.spacingS) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.statusRunning)
            Text(model.format(.completedLingerFormat, count))
                .font(.callout.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .fill(Theme.bgRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusL)
                .strokeBorder(Theme.stroke)
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
