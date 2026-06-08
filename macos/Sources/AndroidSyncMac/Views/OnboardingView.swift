import SwiftUI

struct OnboardingView: View {
    @Bindable var model: AppModel

    var body: some View {
        ContentUnavailableView {
            Label("Choose a Receive Folder", systemImage: "externaldrive.badge.plus")
        } description: {
            Text("Android Sync needs a folder for original photos, videos, metadata, and receive history.")
        } actions: {
            Button("Choose Folder…") {
                model.chooseDirectory()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
