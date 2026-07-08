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
                        ThumbnailView(item: item, size: Theme.Thumb.inspectorSize)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL))
                        Text(item.filename)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                            .textSelection(.enabled)
                        metadata(item)
                        HStack {
                            Button(model.text(.quickLook)) { model.preview(item) }
                                .disabled(item.removed)
                                .buttonStyle(.bordered)
                            Button(model.text(.finder)) { model.reveal(item) }
                                .disabled(item.removed)
                                .buttonStyle(.bordered)
                        }
                        Button(model.text(.renameEllipsis)) {
                            renameValue = item.filename
                            renamePresented = true
                        }
                        .disabled(item.removed)
                        .buttonStyle(.bordered)
                        Button(model.text(.moveToTrash), role: .destructive) {
                            Task { await model.deleteSelected() }
                        }
                        .disabled(item.removed)
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
                .background(Theme.bg)
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
            row(
                model.text(.metadataType),
                AppFormatters.contentType(
                    item.contentType,
                    kind: item.kind,
                    language: model.language
                )
            )
            row(
                model.text(.metadataSize),
                model.formatByteCount(item.sizeBytes)
            )
            row(
                model.text(.metadataReceived),
                model.formatDate(item.receivedAt)
            )
            if let millis = item.dateTakenMillis {
                row(
                    model.text(.metadataCaptured),
                    model.formatDate(
                        Date(timeIntervalSince1970: Double(millis) / 1_000)
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
                .foregroundStyle(Theme.textSecondary)
            Text(value)
        }
    }
}
