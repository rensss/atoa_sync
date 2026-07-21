import AppKit
import XCTest
@testable import AndroidSyncMac

@MainActor
final class ThumbnailLoaderTests: XCTestCase {
    func testRepeatedRequestUsesMemoryCache() async {
        var generationCount = 0
        let expected = NSImage(size: CGSize(width: 40, height: 40))
        let loader = ThumbnailLoader(generator: { _, _, _ in
            generationCount += 1
            return expected
        })
        let url = URL(fileURLWithPath: "/tmp/cache.jpg")

        let first = await loader.image(
            for: url,
            size: CGSize(width: 40, height: 40),
            scale: 2
        )
        let second = await loader.image(
            for: url,
            size: CGSize(width: 40, height: 40),
            scale: 2
        )

        XCTAssertTrue(first === expected)
        XCTAssertTrue(second === expected)
        XCTAssertEqual(generationCount, 1)
    }

    func testCacheSeparatesDisplaySizesAndScales() async {
        var generationCount = 0
        let loader = ThumbnailLoader(generator: { _, size, _ in
            generationCount += 1
            return NSImage(size: size)
        })
        let url = URL(fileURLWithPath: "/tmp/variants.jpg")

        _ = await loader.image(
            for: url,
            size: CGSize(width: 40, height: 40),
            scale: 2
        )
        _ = await loader.image(
            for: url,
            size: CGSize(width: 80, height: 80),
            scale: 2
        )
        _ = await loader.image(
            for: url,
            size: CGSize(width: 40, height: 40),
            scale: 1
        )

        XCTAssertEqual(generationCount, 3)
    }

    func testConcurrentRequestsShareOneGenerationTask() async {
        var generationCount = 0
        let expected = NSImage(size: CGSize(width: 40, height: 40))
        let loader = ThumbnailLoader(generator: { _, _, _ in
            generationCount += 1
            try? await Task.sleep(for: .milliseconds(30))
            return expected
        })
        let url = URL(fileURLWithPath: "/tmp/in-flight.jpg")

        let first = Task { @MainActor in
            await loader.image(
                for: url,
                size: CGSize(width: 40, height: 40),
                scale: 2
            )
        }
        await Task.yield()
        let second = Task { @MainActor in
            await loader.image(
                for: url,
                size: CGSize(width: 40, height: 40),
                scale: 2
            )
        }

        let firstImage = await first.value
        let secondImage = await second.value

        XCTAssertTrue(firstImage === expected)
        XCTAssertTrue(secondImage === expected)
        XCTAssertEqual(generationCount, 1)
    }
}
