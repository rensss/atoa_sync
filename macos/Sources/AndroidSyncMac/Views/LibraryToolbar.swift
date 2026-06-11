import SwiftUI

struct LibraryToolbar: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack {
            Text(model.category.title(using: model.language))
                .font(.title2.bold())
            Text("\(model.filteredItems.count)")
                .foregroundStyle(.secondary)
            Spacer()
            if !model.selectedIDs.isEmpty {
                Button(role: .destructive) {
                    Task { await model.deleteSelected() }
                } label: {
                    Label(model.text(.moveToTrash), systemImage: "trash")
                }
                .disabled(model.category == .deleted)
            }
            Menu {
                Picker(model.text(.date), selection: $model.dateFilter) {
                    ForEach(LibraryDateFilter.allCases) { filter in
                        Text(filter.title(using: model.language)).tag(filter)
                    }
                }
            } label: {
                Label(
                    model.dateFilter.title(using: model.language),
                    systemImage: "calendar"
                )
            }
            Menu {
                Picker(model.text(.sort), selection: $model.sort) {
                    ForEach(LibrarySort.allCases) { sort in
                        Text(sort.title(using: model.language)).tag(sort)
                    }
                }
            } label: {
                Label(
                    model.sort.title(using: model.language),
                    systemImage: "arrow.up.arrow.down"
                )
            }
            Button {
                model.inspectorPresented.toggle()
            } label: {
                Label(model.text(.inspector), systemImage: "sidebar.right")
            }
            Picker(model.text(.layout), selection: $model.layout) {
                Image(systemName: "square.grid.2x2").tag(LibraryLayout.grid)
                Image(systemName: "list.bullet").tag(LibraryLayout.list)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 90)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}
