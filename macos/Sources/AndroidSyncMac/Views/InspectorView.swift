import AppKit
import SwiftUI

struct InspectorView: View {
    @Bindable var model: AppModel
    @Binding var renamePresented: Bool
    @Binding var renameValue: String

    var body: some View {
        Group {
            if let item = model.selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ThumbnailView(item: item, size: CGSize(width: 320, height: 220))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1.45, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text(item.filename)
                            .font(.headline)
                            .textSelection(.enabled)
                        metadata(item)
                        HStack {
                            Button("Quick Look") { model.preview(item) }
                                .disabled(item.deleted)
                            Button("Finder") { model.reveal(item) }
                                .disabled(item.deleted)
                        }
                        Button("Rename…") {
                            renameValue = item.filename
                            renamePresented = true
                        }
                        .disabled(item.deleted)
                        Button("Move to Trash", role: .destructive) {
                            Task { await model.deleteSelected() }
                        }
                        .disabled(item.deleted)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "sidebar.right",
                    description: Text("Select one item to see its metadata.")
                )
            }
        }
    }

    @ViewBuilder
    private func metadata(_ item: MediaItemEntity) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            row("Type", item.contentType ?? item.kind.rawValue)
            row("Size", ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
            row("Received", item.receivedAt.formatted(date: .abbreviated, time: .shortened))
            if let millis = item.dateTakenMillis {
                row("Captured", Date(timeIntervalSince1970: Double(millis) / 1_000)
                    .formatted(date: .abbreviated, time: .shortened))
            }
            if let sourceIP = item.sourceIP {
                row("Source", sourceIP)
            }
            if let stableID = item.stableID {
                row("Sync ID", stableID)
            }
            row("Location", item.filePath)
        }
        .font(.caption)
        .textSelection(.enabled)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }
}
