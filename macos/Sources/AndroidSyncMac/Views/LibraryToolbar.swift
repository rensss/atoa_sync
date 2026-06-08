import SwiftUI

struct LibraryToolbar: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack {
            Text(model.category.title)
                .font(.title2.bold())
            Text("\(model.filteredItems.count)")
                .foregroundStyle(.secondary)
            Spacer()
            if !model.selectedIDs.isEmpty {
                Button(role: .destructive) {
                    Task { await model.deleteSelected() }
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
                .disabled(model.category == .deleted)
            }
            Menu {
                Picker("Date", selection: $model.dateFilter) {
                    ForEach(LibraryDateFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
            } label: {
                Label(model.dateFilter.title, systemImage: "calendar")
            }
            Menu {
                Picker("Sort", selection: $model.sort) {
                    ForEach(LibrarySort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
            } label: {
                Label(model.sort.title, systemImage: "arrow.up.arrow.down")
            }
            Button {
                model.inspectorPresented.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            Picker("Layout", selection: $model.layout) {
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
