import SwiftUI

struct LibraryToolbar: ToolbarContent {
    @Bindable var model: AppModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            StatusCapsuleView(
                model: model,
                categoryTitle: model.receiveDirectory == nil
                    ? nil
                    : model.category.title(using: model.language),
                itemCount: model.receiveDirectory == nil
                    ? nil
                    : model.filteredItems.count
            )
        }

        ToolbarItem(placement: .primaryAction) {
            LibraryToolbarControlStrip(model: model)
        }
    }
}

private struct LibraryToolbarControlStrip: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            if model.receiveDirectory != nil {
                receiverControls
                ToolbarDivider()
                LibraryOptionsMenu(model: model)
                ToolbarDivider()
                layoutControls
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
            title: model.text(
                model.isRunning ? .pauseReceiving : .startReceiving
            ),
            systemImage: model.isRunning ? "stop.fill" : "play.fill",
            isDisabled: model.status == .starting,
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
