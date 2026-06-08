import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var renamePresented = false
    @State private var renameValue = ""

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            if model.receiveDirectory == nil {
                OnboardingView(model: model)
            } else {
                VStack(spacing: 0) {
                    ReceiverStatusView(model: model)
                    Divider()
                    LibraryToolbar(model: model)
                    LibraryView(model: model)
                }
                .searchable(text: $model.searchText, prompt: "Search filenames")
                .inspector(isPresented: $model.inspectorPresented) {
                    InspectorView(
                        model: model,
                        renamePresented: $renamePresented,
                        renameValue: $renameValue
                    )
                    .inspectorColumnWidth(min: 240, ideal: 280, max: 360)
                }
            }
        }
        .sheet(isPresented: $renamePresented) {
            RenameSheet(
                filename: $renameValue,
                onCancel: { renamePresented = false },
                onRename: {
                    renamePresented = false
                    Task { await model.renameSelected(to: renameValue) }
                }
            )
        }
        .alert(
            "Android Sync",
            isPresented: Binding(
                get: { model.lastError != nil },
                set: { if !$0 { model.lastError = nil } }
            )
        ) {
            Button("OK") { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "")
        }
    }
}

private struct RenameSheet: View {
    @Binding var filename: String
    let onCancel: () -> Void
    let onRename: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename File")
                .font(.headline)
            TextField("Filename", text: $filename)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onRename)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: onRename)
                    .keyboardShortcut(.defaultAction)
                    .disabled(filename.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
