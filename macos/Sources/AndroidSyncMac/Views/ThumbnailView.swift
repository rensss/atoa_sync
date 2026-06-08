import AppKit
import QuickLookThumbnailing
import SwiftUI

struct ThumbnailView: View {
    let item: MediaItemEntity
    let size: CGSize
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.quaternary)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.kind == .video ? "film" : item.kind == .photo ? "photo" : "doc")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task(id: item.filePath) {
            guard !item.deleted else { return }
            let request = QLThumbnailGenerator.Request(
                fileAt: item.fileURL,
                size: size,
                scale: NSScreen.main?.backingScaleFactor ?? 2,
                representationTypes: .thumbnail
            )
            image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(
                for: request
            ).nsImage
        }
    }
}

private extension QLThumbnailRepresentation {
    var nsImage: NSImage {
        NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
    }
}
