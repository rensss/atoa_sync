import AppKit
import QuickLookThumbnailing
import SwiftUI

enum ThumbnailMetrics {
    static let gridCardWidth: CGFloat = 180
    static let gridSize = CGSize(width: gridCardWidth, height: 124)
    static let listSize = CGSize(width: 56, height: 42)
    static let inspectorSize = CGSize(width: 240, height: 166)
    static let cornerRadius: CGFloat = 9
}

struct ThumbnailView: View {
    let item: MediaItemEntity
    let size: CGSize
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
            } else {
                Image(systemName: item.kind == .video ? "film" : item.kind == .photo ? "photo" : "doc")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size.width, height: size.height)
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
