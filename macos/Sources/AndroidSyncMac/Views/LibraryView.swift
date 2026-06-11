import AppKit
import SwiftUI

struct LibraryView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.filteredItems.isEmpty {
                if model.searchText.isEmpty {
                    ContentUnavailableView(
                        model.text(.noReceivedFiles),
                        systemImage: "tray.and.arrow.down",
                        description: Text(model.text(.receivedFilesDescription))
                    )
                } else {
                    ContentUnavailableView(
                        model.text(.noSearchResults),
                        systemImage: "magnifyingglass",
                        description: Text(model.text(.noSearchResultsDescription))
                    )
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
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: ThumbnailMetrics.gridCardWidth,
                            maximum: ThumbnailMetrics.gridCardWidth
                        ),
                        spacing: 14
                    )
                ],
                spacing: 16
            ) {
                ForEach(model.filteredItems) { item in
                    MediaGridItem(
                        model: model,
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
                ThumbnailView(item: item, size: ThumbnailMetrics.listSize)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.filename)
                        .lineLimit(1)
                    Text(model.formatDate(item.receivedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.formatByteCount(item.sizeBytes))
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
        Button(model.text(.quickLook)) { model.preview(item) }
            .disabled(item.deleted)
        Button(model.text(.showInFinder)) { model.reveal(item) }
            .disabled(item.deleted)
        Divider()
        Button(model.text(.moveToTrash), role: .destructive) {
            model.selectedIDs = [item.id]
            Task { await model.deleteSelected() }
        }
        .disabled(item.deleted)
    }
}

private struct MediaGridItem: View {
    @Bindable var model: AppModel
    let item: MediaItemEntity
    let selected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThumbnailView(item: item, size: ThumbnailMetrics.gridSize)
                .clipShape(RoundedRectangle(cornerRadius: ThumbnailMetrics.cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: ThumbnailMetrics.cornerRadius)
                        .stroke(selected ? Color.accentColor : .clear, lineWidth: 3)
                }
                .opacity(item.deleted ? 0.45 : 1)
            Text(item.filename)
                .lineLimit(1)
                .font(.callout.weight(.medium))
                .frame(width: ThumbnailMetrics.gridCardWidth, alignment: .leading)
            HStack {
                Text(model.formatByteCount(item.sizeBytes))
                Spacer()
                Text(model.formatDateOnly(item.receivedAt))
            }
            .frame(width: ThumbnailMetrics.gridCardWidth)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(width: ThumbnailMetrics.gridCardWidth, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onPreview)
        .contextMenu {
            Button(model.text(.quickLook), action: onPreview)
                .disabled(item.deleted)
            Button(model.text(.showInFinder), action: onReveal)
                .disabled(item.deleted)
        }
    }
}
