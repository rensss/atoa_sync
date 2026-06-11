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
                            Button(model.text(.quickLook)) { model.preview(item) }
                                .disabled(item.deleted)
                            Button(model.text(.finder)) { model.reveal(item) }
                                .disabled(item.deleted)
                        }
                        Button(model.text(.renameEllipsis)) {
                            renameValue = item.filename
                            renamePresented = true
                        }
                        .disabled(item.deleted)
                        Button(model.text(.moveToTrash), role: .destructive) {
                            Task { await model.deleteSelected() }
                        }
                        .disabled(item.deleted)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    model.text(.noSelection),
                    systemImage: "sidebar.right",
                    description: Text(model.text(.selectionDescription))
                )
            }
        }
    }

    @ViewBuilder
    private func metadata(_ item: MediaItemEntity) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            row(model.text(.metadataType), item.contentType ?? item.kind.rawValue)
            row(
                model.text(.metadataSize),
                ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)
            )
            row(
                model.text(.metadataReceived),
                item.receivedAt.formatted(
                    Date.FormatStyle(date: .abbreviated, time: .shortened)
                        .locale(model.language.locale)
                )
            )
            if let millis = item.dateTakenMillis {
                row(
                    model.text(.metadataCaptured),
                    Date(timeIntervalSince1970: Double(millis) / 1_000)
                        .formatted(
                            Date.FormatStyle(date: .abbreviated, time: .shortened)
                                .locale(model.language.locale)
                        )
                )
            }
            if let sourceIP = item.sourceIP {
                row(model.text(.metadataSource), sourceIP)
            }
            if let stableID = item.stableID {
                row(model.text(.metadataSyncID), stableID)
            }
            row(model.text(.metadataLocation), item.filePath)
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
