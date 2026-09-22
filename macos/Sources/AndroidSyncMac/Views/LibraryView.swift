import AppKit
import AVFoundation
import SwiftUI

struct LibraryView: View {
    @Bindable var model: AppModel
    let quickLookBlocked: Bool
    @FocusState private var libraryFocused: Bool

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .focusable()
        .focused($libraryFocused)
        .focusEffectDisabled()
        .onChange(of: libraryFocused) { _, focused in
            model.libraryKeyboardNavigationEnabled = focused
        }
        .onAppear {
            model.libraryQuickLookBlocked = quickLookBlocked
        }
        .onChange(of: quickLookBlocked) { _, blocked in
            model.libraryQuickLookBlocked = blocked
        }
        .onDisappear {
            model.libraryKeyboardNavigationEnabled = false
        }
        .onKeyPress(.space, phases: .down) { press in
            guard libraryFocused,
                  !quickLookBlocked,
                  press.modifiers.isEmpty,
                  !textInputIsFirstResponder,
                  model.selectedItem != nil
            else {
                return .ignored
            }
            model.toggleSelectedPreview()
            return .handled
        }
        .onKeyPress(.delete, phases: .down) { press in
            guard libraryFocused,
                  !quickLookBlocked,
                  press.modifiers.isEmpty,
                  !textInputIsFirstResponder,
                  model.selectedIDs.contains(where: { id in
                      model.items.contains { $0.id == id && !$0.removed }
                  })
            else {
                return .ignored
            }
            Task { await model.deleteSelected() }
            return .handled
        }
    }

    private var grid: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(
                                .adaptive(
                                    minimum: Theme.Thumb.gridCell,
                                    maximum: Theme.Thumb.gridCell
                                ),
                                spacing: Theme.Thumb.gridGap
                            )
                        ],
                        spacing: Theme.Thumb.gridGap
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
                                    libraryFocused = true
                                    model.libraryKeyboardNavigationEnabled = true
                                },
                                onPreview: { model.preview(item) },
                                onReveal: { model.reveal(item) }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(Theme.spacingS)
                }
                .background(Theme.bg)
                .onAppear {
                    updateGridColumnCount(for: geometry.size.width)
                }
                .onChange(of: geometry.size.width) { _, width in
                    updateGridColumnCount(for: width)
                }
                .onChange(of: model.libraryScrollTargetID) { _, id in
                    scrollToSelection(id, with: proxy)
                }
            }
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            List(model.filteredItems) { item in
                HStack(spacing: 12) {
                    ThumbnailView(item: item, size: Theme.Thumb.listSize)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.filename)
                            .lineLimit(1)
                        Text(model.formatDate(item.mediaDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(model.formatByteCount(item.sizeBytes))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
                .background(
                    model.selectedIDs.contains(item.id)
                        ? Theme.accent.opacity(0.15)
                        : .clear
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    model.select(item.id, additive: NSEvent.modifierFlags.contains(.command))
                    libraryFocused = true
                    model.libraryKeyboardNavigationEnabled = true
                }
                .onTapGesture(count: 2) { model.preview(item) }
                .contextMenu { itemMenu(item) }
                .id(item.id)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .onChange(of: model.libraryScrollTargetID) { _, id in
                scrollToSelection(id, with: proxy)
            }
        }
    }

    private static func gridColumnCount(for libraryWidth: CGFloat) -> Int {
        let contentWidth = max(0, libraryWidth - (Theme.spacingS * 2))
        return max(
            1,
            Int(
                (contentWidth + Theme.Thumb.gridGap)
                    / (Theme.Thumb.gridCell + Theme.Thumb.gridGap)
            )
        )
    }

    private func updateGridColumnCount(for libraryWidth: CGFloat) {
        model.libraryGridColumnCount = Self.gridColumnCount(for: libraryWidth)
    }

    private func scrollToSelection(
        _ id: UUID?,
        with proxy: ScrollViewProxy
    ) {
        guard let id else { return }
        proxy.scrollTo(id)
    }

    @ViewBuilder
    private func itemMenu(_ item: MediaItemEntity) -> some View {
        Button(model.text(.quickLook)) { model.preview(item) }
            .disabled(item.removed)
        Button(model.text(.showInFinder)) { model.reveal(item) }
            .disabled(item.removed)
        Divider()
        Button(model.text(.moveToTrash), role: .destructive) {
            model.selectedIDs = [item.id]
            Task { await model.deleteSelected() }
        }
        .disabled(item.removed)
    }

    private var textInputIsFirstResponder: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else {
            return false
        }
        return responder is NSTextView || responder is NSTextField
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
        ThumbnailView(item: item, size: Theme.Thumb.gridSize)
            .overlay(alignment: .bottomTrailing) {
                if item.kind == .video {
                    DurationBadge(item: item)
                }
            }
            .clipShape(
                RoundedRectangle(cornerRadius: Theme.Thumb.cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Thumb.cornerRadius)
                    .stroke(
                        selected ? Theme.accent : .clear,
                        lineWidth: 2
                    )
            }
            .opacity(item.removed ? 0.45 : 1)
            .help(item.filename)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .onTapGesture(count: 2, perform: onPreview)
            .contextMenu {
                Button(model.text(.quickLook), action: onPreview)
                    .disabled(item.removed)
                Button(model.text(.showInFinder), action: onReveal)
                    .disabled(item.removed)
            }
    }
}

private struct DurationBadge: View {
    let item: MediaItemEntity
    @State private var duration: String?

    var body: some View {
        Group {
            if let duration {
                Text(duration)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.spacingXS + 1)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.black.opacity(0.6))
                    )
                    .padding(Theme.spacingXS)
            }
        }
        .task(id: item.filePath) {
            guard !item.removed else { return }
            let asset = AVURLAsset(url: item.fileURL)
            guard let time = try? await asset.load(.duration) else { return }
            let seconds = Int(time.seconds.rounded())
            guard seconds > 0 else { return }
            duration = String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
    }
}
