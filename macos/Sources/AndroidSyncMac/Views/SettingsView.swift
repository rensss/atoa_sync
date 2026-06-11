import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var portText = ""

    var body: some View {
        Form {
            Section(model.text(.receiving)) {
                LabeledContent(model.text(.folder)) {
                    HStack {
                        Text(model.receiveDirectory?.path ?? model.text(.notSelected))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Button(model.text(.chooseEllipsis)) { model.chooseDirectory() }
                    }
                }
                LabeledContent(model.text(.port)) {
                    TextField("8765", text: $portText)
                        .frame(width: 90)
                        .onSubmit(applyPort)
                }
                Text(model.text(.portRestartDescription))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(model.text(.general)) {
                Picker(model.text(.language), selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }
            Section(model.text(.startup)) {
                Toggle(
                    model.text(.launchAtLogin),
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }
            Section(model.text(.security)) {
                Label(
                    model.text(.securityDescription),
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 400)
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
