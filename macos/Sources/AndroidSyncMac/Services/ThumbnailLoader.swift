import AppKit
import QuickLookThumbnailing

@MainActor
final class ThumbnailLoader {
    typealias Generator = @MainActor (URL, CGSize, CGFloat) async -> NSImage?

    static let shared = ThumbnailLoader()

    private let cache = NSCache<NSString, NSImage>()
    private var inFlight: [String: Task<NSImage?, Never>] = [:]
    private let generator: Generator

    init(
        countLimit: Int = 256,
        totalCostLimit: Int = 96 * 1_024 * 1_024,
        generator: @escaping Generator = ThumbnailLoader.generateThumbnail
    ) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
        self.generator = generator
    }

    func image(
        for url: URL,
        size: CGSize,
        scale: CGFloat
    ) async -> NSImage? {
        let key = Self.cacheKey(for: url, size: size, scale: scale)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        if let task = inFlight[key] {
            return await task.value
        }

        let task = Task { await generator(url, size, scale) }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil

        if let image {
            cache.setObject(
                image,
                forKey: key as NSString,
                cost: Self.memoryCost(of: image)
            )
        }
        return image
    }

    static func cacheKey(
        for url: URL,
        size: CGSize,
        scale: CGFloat
    ) -> String {
        "\(url.path(percentEncoded: false))|\(size.width)x\(size.height)@\(scale)"
    }

    private static func memoryCost(of image: NSImage) -> Int {
        let pixels = image.representations.reduce(0) { partial, representation in
            partial + max(1, representation.pixelsWide) * max(1, representation.pixelsHigh)
        }
        return max(1, pixels * 4)
    }

    private static func generateThumbnail(
        for url: URL,
        size: CGSize,
        scale: CGFloat
    ) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        let representation = try? await QLThumbnailGenerator.shared
            .generateBestRepresentation(for: request)
        guard let representation else { return nil }
        return NSImage(
            cgImage: representation.cgImage,
            size: CGSize(
                width: representation.cgImage.width,
                height: representation.cgImage.height
            )
        )
    }
}
