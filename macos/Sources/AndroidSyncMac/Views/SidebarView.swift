import SwiftUI

struct SidebarView: View {
    @Bindable var model: AppModel

    var body: some View {
        List(LibraryCategory.allCases, selection: $model.category) { category in
            Label(
                category.title(using: model.language),
                systemImage: category.systemImage
            )
            .badge(
                Text("\(model.categoryCount(category))")
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            )
            .tag(category)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Theme.bgSidebar)
        .navigationTitle("Android Sync")
        .safeAreaInset(edge: .bottom) {
            if let directory = model.receiveDirectory {
                Button {
                    model.openReceiveDirectory()
                } label: {
                    Label(directory.lastPathComponent, systemImage: "folder")
                        .lineLimit(1)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(Theme.spacingM)
                .help(directory.path)
            }
        }
    }
}
