import AppKit
import SwiftUI

struct ThumbnailView: View {
    let item: MediaItemEntity
    let size: CGSize
    private let loader: ThumbnailLoader
    @State private var image: NSImage?

    init(
        item: MediaItemEntity,
        size: CGSize,
        loader: ThumbnailLoader = .shared
    ) {
        self.item = item
        self.size = size
        self.loader = loader
    }

    var body: some View {
        ZStack {
            Theme.bgRaised
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
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
            guard !item.removed else { return }
            image = await loader.image(
                for: item.fileURL,
                size: size,
                scale: NSScreen.main?.backingScaleFactor ?? 2
            )
        }
    }
}
