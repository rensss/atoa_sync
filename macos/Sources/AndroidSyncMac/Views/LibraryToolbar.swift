import SwiftUI

struct LibraryToolbar: ToolbarContent {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some ToolbarContent {
        ToolbarItem(placement: .status) {
            StatusCapsuleView(model: model)
        }

        if model.receiveDirectory != nil {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text(model.category.title(using: model.language))
                        .font(.headline)
                    Text("\(model.filteredItems.count)")
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if !model.selectedIDs.isEmpty {
                    Button(role: .destructive) {
                        Task { await model.deleteSelected() }
                    } label: {
                        Label(model.text(.moveToTrash), systemImage: "trash")
                    }
                    .disabled(model.category == .deleted)
                    .help(model.text(.moveToTrash))
                }

                Menu {
                    ForEach(LibraryDateFilter.allCases) { filter in
                        Button {
                            model.dateFilter = filter
                        } label: {
                            if model.dateFilter == filter {
                                Label(
                                    filter.title(using: model.language),
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text(filter.title(using: model.language))
                            }
                        }
                    }
                } label: {
                    Label(
                        model.dateFilter.title(using: model.language),
                        systemImage: "calendar"
                    )
                }

                Menu {
                    ForEach(LibrarySort.allCases) { sort in
                        Button {
                            model.sort = sort
                        } label: {
                            if model.sort == sort {
                                Label(
                                    sort.title(using: model.language),
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text(sort.title(using: model.language))
                            }
                        }
                    }
                } label: {
                    Label(
                        model.sort.title(using: model.language),
                        systemImage: "arrow.up.arrow.down"
                    )
                }

                Picker(model.text(.layout), selection: $model.layout) {
                    Image(systemName: "square.grid.2x2")
                        .tag(LibraryLayout.grid)
                    Image(systemName: "list.bullet")
                        .tag(LibraryLayout.list)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 90)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                openSettings()
            } label: {
                Label(model.text(.settings), systemImage: "gearshape")
            }
            .help(model.text(.settings))
        }

        if model.receiveDirectory != nil {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.inspectorPresented.toggle()
                } label: {
                    Label(model.text(.inspector), systemImage: "sidebar.right")
                }
                .help(model.text(.inspector))
            }
        }
    }
}
