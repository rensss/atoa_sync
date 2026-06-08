import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var portText = ""

    var body: some View {
        Form {
            Section("Receiving") {
                LabeledContent("Folder") {
                    HStack {
                        Text(model.receiveDirectory?.path ?? "Not selected")
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Button("Choose…") { model.chooseDirectory() }
                    }
                }
                LabeledContent("Port") {
                    TextField("8765", text: $portText)
                        .frame(width: 90)
                        .onSubmit(applyPort)
                }
                Text("Changing the port restarts the receiver.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle(
                    "Launch Android Sync at login",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }
            Section("Security") {
                Label(
                    "Uploads are accepted only from loopback and private local-network addresses. No authentication token is used.",
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 330)
        .onAppear { portText = String(model.port) }
    }

    private func applyPort() {
        guard let value = UInt16(portText), value > 0 else {
            portText = String(model.port)
            return
        }
        guard value != model.port else { return }
        model.port = value
        model.restartReceiver()
    }
}
