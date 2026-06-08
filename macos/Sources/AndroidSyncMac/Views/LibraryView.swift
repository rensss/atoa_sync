import AppKit
import SwiftUI

struct LibraryView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.filteredItems.isEmpty {
                if model.searchText.isEmpty {
                    ContentUnavailableView(
                        "No Received Files",
                        systemImage: "tray.and.arrow.down",
                        description: Text("Files sent from Android will appear here.")
                    )
                } else {
                    ContentUnavailableView.search(text: model.searchText)
                }
            } else if model.layout == .grid {
                grid
            } else {
                list
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 14)],
                spacing: 16
            ) {
                ForEach(model.filteredItems) { item in
                    MediaGridItem(
                        item: item,
                        selected: model.selectedIDs.contains(item.id),
                        onSelect: {
                            model.select(
                                item.id,
                                additive: NSEvent.modifierFlags.contains(.command)
                            )
                        },
                        onPreview: { model.preview(item) },
                        onReveal: { model.reveal(item) }
                    )
                }
            }
            .padding(18)
        }
    }

    private var list: some View {
        List(model.filteredItems) { item in
            HStack(spacing: 12) {
                ThumbnailView(item: item, size: CGSize(width: 56, height: 42))
                    .frame(width: 56, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.filename)
                        .lineLimit(1)
                    Text(item.receivedAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)
            .background(model.selectedIDs.contains(item.id) ? Color.accentColor.opacity(0.12) : .clear)
            .contentShape(Rectangle())
            .onTapGesture {
                model.select(item.id, additive: NSEvent.modifierFlags.contains(.command))
            }
            .onTapGesture(count: 2) { model.preview(item) }
            .contextMenu { itemMenu(item) }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func itemMenu(_ item: MediaItemEntity) -> some View {
        Button("Quick Look") { model.preview(item) }
            .disabled(item.deleted)
        Button("Show in Finder") { model.reveal(item) }
            .disabled(item.deleted)
        Divider()
        Button("Move to Trash", role: .destructive) {
            model.selectedIDs = [item.id]
            Task { await model.deleteSelected() }
        }
        .disabled(item.deleted)
    }
}

private struct MediaGridItem: View {
    let item: MediaItemEntity
    let selected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThumbnailView(item: item, size: CGSize(width: 230, height: 150))
                .frame(maxWidth: .infinity)
                .aspectRatio(1.45, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(selected ? Color.accentColor : .clear, lineWidth: 3)
                }
                .opacity(item.deleted ? 0.45 : 1)
            Text(item.filename)
                .lineLimit(1)
                .font(.callout.weight(.medium))
            HStack {
                Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                Spacer()
                Text(item.receivedAt, style: .date)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onPreview)
        .contextMenu {
            Button("Quick Look", action: onPreview)
                .disabled(item.deleted)
            Button("Show in Finder", action: onReveal)
                .disabled(item.deleted)
        }
    }
}
