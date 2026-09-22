import AppKit
import SwiftUI

struct LibraryToolbar: ToolbarContent {
    @Bindable var model: AppModel
    @Binding var searchPresented: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            LibraryToolbarControlStrip(model: model)
        }

        if model.receiveDirectory != nil {
            if #available(macOS 26.0, *) {
                ToolbarSpacer(.flexible, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) {
                    searchControl
                }
                .sharedBackgroundVisibility(
                    searchPresented ? .visible : .hidden
                )
            } else {
                ToolbarItem(placement: .primaryAction) {
                    searchControl
                }
            }
        }
    }

    private var searchControl: some View {
        LibrarySearchControl(
            model: model,
            isPresented: $searchPresented
        )
    }
}

private struct LibrarySearchControl: View {
    @Bindable var model: AppModel
    @Binding var isPresented: Bool

    var body: some View {
        Group {
            if isPresented {
                searchField
            } else {
                Button(action: presentSearch) {
                    Image(systemName: "magnifyingglass")
                        .frame(
                            width: Theme.toolbarIconSize,
                            height: Theme.toolbarIconSize
                        )
                        .contentShape(
                            RoundedRectangle(cornerRadius: Theme.radiusS)
                        )
                }
                .buttonStyle(ToolbarIconButtonStyle())
                .keyboardShortcut("f", modifiers: .command)
                .help(model.text(.searchFilenames))
                .accessibilityLabel(model.text(.searchFilenames))
            }
        }
    }

    private var searchField: some View {
        LibrarySearchTextField(
            text: $model.searchText,
            isPresented: $isPresented,
            prompt: model.text(.searchFilenames)
        )
        .frame(width: 220, height: Theme.toolbarIconSize)
    }

    private func presentSearch() {
        isPresented = true
    }
}

private struct LibrarySearchTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isPresented: Bool
    let prompt: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.delegate = context.coordinator
        searchField.placeholderString = prompt
        searchField.sendsSearchStringImmediately = true
        searchField.focusRingType = .none
        context.coordinator.requestFocus(for: searchField)
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        context.coordinator.parent = self
        searchField.placeholderString = prompt
        if searchField.stringValue != text {
            searchField.stringValue = text
        }
        context.coordinator.requestFocus(for: searchField)
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: LibrarySearchTextField
        private var allowsAutomaticDismissal = false
        private var focusRequested = false

        init(parent: LibrarySearchTextField) {
            self.parent = parent
        }

        func requestFocus(for searchField: NSSearchField) {
            guard !focusRequested else { return }
            DispatchQueue.main.async { [weak self, weak searchField] in
                guard let self,
                      let searchField,
                      let window = searchField.window
                else {
                    return
                }
                focusRequested = window.makeFirstResponder(searchField)
                // Toolbar relayout can emit a transient end-editing callback
                // while replacing the button with this field.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    [weak self, weak searchField] in
                    guard let self,
                          let searchField,
                          self.parent.isPresented,
                          let window = searchField.window
                    else {
                        return
                    }
                    if searchField.currentEditor() == nil {
                        self.focusRequested = window.makeFirstResponder(searchField)
                    }
                    self.allowsAutomaticDismissal = self.focusRequested
                }
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else {
                return
            }
            parent.text = searchField.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard allowsAutomaticDismissal,
                  notification.object is NSSearchField
            else {
                return
            }
            parent.isPresented = false
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.cancelOperation(_:)) else {
                return false
            }

            if parent.text.isEmpty {
                parent.isPresented = false
                control.window?.makeFirstResponder(nil)
            } else {
                parent.text = ""
                control.stringValue = ""
            }
            return true
        }
    }
}

private struct LibraryToolbarControlStrip: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            StatusCapsuleView(model: model)

            if model.receiveDirectory != nil {
                receiverControls
                ToolbarDivider()
                LibraryOptionsMenu(model: model)
                ToolbarDivider()
                layoutControls
                ToolbarDivider()
            } else {
                ToolbarDivider()
            }

            ToolbarIconButton(
                title: model.text(.settings),
                systemImage: "gearshape",
                action: { openSettings() }
            )

            if model.receiveDirectory != nil {
                ToolbarIconButton(
                    title: model.text(.inspector),
                    systemImage: "sidebar.right",
                    isActive: model.inspectorPresented,
                    action: { model.inspectorPresented.toggle() }
                )
            }
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.toolbarSurface)
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(Theme.stroke.opacity(0.7), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var receiverControls: some View {
        ToolbarIconButton(
            title: model.receiverActionTitle,
            systemImage: model.receiverActionSystemImage,
            isDisabled: model.receiverActionDisabled,
            action: { model.toggleReceiver() }
        )

        if !model.uploadURL.isEmpty {
            AddressQRCodeButton(model: model)
        }

        if model.category == .deleted && model.categoryCount(.deleted) > 0 {
            ToolbarIconButton(
                title: model.text(.clearDeleted),
                systemImage: "trash.slash",
                role: .destructive,
                action: { model.clearDeletedItems() }
            )
        }

        if !model.selectedIDs.isEmpty {
            ToolbarIconButton(
                title: model.text(.moveToTrash),
                systemImage: "trash",
                role: .destructive,
                isDisabled: model.category == .deleted,
                action: {
                    Task { await model.deleteSelected() }
                }
            )
        }
    }

    private var layoutControls: some View {
        HStack(spacing: 1) {
            ToolbarIconButton(
                title: model.text(.gridView),
                systemImage: "square.grid.2x2",
                isActive: model.layout == .grid,
                action: { model.layout = .grid }
            )
            ToolbarIconButton(
                title: model.text(.listView),
                systemImage: "list.bullet",
                isActive: model.layout == .list,
                action: { model.layout = .list }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.text(.layout))
    }
}

private struct LibraryOptionsMenu: View {
    @Bindable var model: AppModel

    var body: some View {
        Menu {
            Section(model.text(.date)) {
                ForEach(LibraryDateFilter.allCases) { filter in
                    Button {
                        model.dateFilter = filter
                    } label: {
                        checkedLabel(
                            filter.title(using: model.language),
                            selected: model.dateFilter == filter
                        )
                    }
                }
            }

            Section(model.text(.sort)) {
                ForEach(LibrarySort.allCases) { sort in
                    Button {
                        model.sort = sort
                    } label: {
                        checkedLabel(
                            sort.title(using: model.language),
                            selected: model.sort == sort
                        )
                    }
                }
            }
        } label: {
            Image(systemName: optionsSystemImage)
                .frame(
                    width: Theme.toolbarIconSize,
                    height: Theme.toolbarIconSize
                )
                .foregroundStyle(optionsAreDefault ? Theme.textPrimary : Theme.accent)
                .contentShape(RoundedRectangle(cornerRadius: Theme.radiusS))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(optionsHelp)
        .accessibilityLabel(optionsHelp)
    }

    @ViewBuilder
    private func checkedLabel(
        _ title: String,
        selected: Bool
    ) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private var optionsAreDefault: Bool {
        model.dateFilter == .all && model.sort == .newest
    }

    private var optionsSystemImage: String {
        optionsAreDefault
            ? "line.3.horizontal.decrease"
            : "line.3.horizontal.decrease.circle.fill"
    }

    private var optionsHelp: String {
        [
            model.dateFilter.title(using: model.language),
            model.sort.title(using: model.language),
        ].joined(separator: " · ")
    }
}

struct ToolbarIconButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    var isActive = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(ToolbarIconButtonStyle(isActive: isActive))
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .help(title)
        .id(systemImage)
    }
}

struct ToolbarIconButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(
                width: Theme.toolbarIconSize,
                height: Theme.toolbarIconSize
            )
            .foregroundStyle(isActive ? Theme.accent : Theme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusS)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusS))
            .opacity(configuration.isPressed ? 0.86 : 1)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isActive {
            return Theme.toolbarSelection
        }
        return isPressed ? Theme.toolbarSurfacePressed : .clear
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.stroke.opacity(0.9))
            .frame(width: 1, height: Theme.toolbarDividerHeight)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }
}
