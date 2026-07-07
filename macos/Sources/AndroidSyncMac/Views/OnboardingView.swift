import SwiftUI

struct OnboardingView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: Theme.spacingL) {
            ZStack {
                Circle()
                    .fill(Theme.cardGradient)
                    .frame(width: 96, height: 96)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white)
            }
            Text(model.text(.chooseReceiveFolder))
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(model.text(.onboardingDescription))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(model.text(.chooseFolderEllipsis)) {
                model.chooseDirectory()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}
