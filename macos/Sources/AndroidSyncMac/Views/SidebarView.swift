import SwiftUI

struct SidebarView: View {
    @Bindable var model: AppModel

    var body: some View {
        List(LibraryCategory.allCases, selection: $model.category) { category in
            Label(category.title, systemImage: category.systemImage)
                .tag(category)
        }
        .listStyle(.sidebar)
        .navigationTitle("Android Sync")
        .safeAreaInset(edge: .bottom) {
            if let directory = model.receiveDirectory {
                Button {
                    model.openReceiveDirectory()
                } label: {
                    Label(directory.lastPathComponent, systemImage: "folder")
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .padding(12)
                .help(directory.path)
            }
        }
    }
}
