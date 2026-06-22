import SwiftUI

struct OnboardingView: View {
    @Bindable var model: AppModel

    var body: some View {
        ContentUnavailableView {
            Label(
                model.text(.chooseReceiveFolder),
                systemImage: "externaldrive.badge.plus"
            )
        } description: {
            Text(model.text(.onboardingDescription))
        } actions: {
            Button(model.text(.chooseFolderEllipsis)) {
                model.chooseDirectory()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
