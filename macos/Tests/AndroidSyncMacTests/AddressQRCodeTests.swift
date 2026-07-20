import XCTest
@testable import AndroidSyncMac

final class AddressQRCodeTests: XCTestCase {
    func testConfigurationLinkWrapsUploadURL() throws {
        let uploadURL = "http://192.168.1.6:8765/uploads/"
        let link = try XCTUnwrap(AddressConfigurationLink.make(for: uploadURL))
        let components = try XCTUnwrap(
            URLComponents(url: link, resolvingAgainstBaseURL: false)
        )

        XCTAssertEqual(components.scheme, "androidsync")
        XCTAssertEqual(components.host, "configure")
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "url" })?.value,
            uploadURL
        )
    }

    func testConfigurationLinkPreservesTargetQuery() throws {
        let uploadURL = "https://nas.local/webdav/?token=a%2Bb"
        let link = try XCTUnwrap(AddressConfigurationLink.make(for: uploadURL))
        let components = try XCTUnwrap(
            URLComponents(url: link, resolvingAgainstBaseURL: false)
        )

        XCTAssertEqual(components.queryItems?.first?.value, uploadURL)
    }

    func testConfigurationLinkRejectsUnsupportedTargets() {
        XCTAssertNil(AddressConfigurationLink.make(for: "file:///tmp/uploads"))
        XCTAssertNil(AddressConfigurationLink.make(for: "not a URL"))
    }

    func testQRCodeRendererProducesImage() {
        let image = AddressQRCodeRenderer.image(
            for: "androidsync://configure?url=http%3A%2F%2F192.168.1.6%2Fuploads%2F",
            dimension: 160
        )

        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size, NSSize(width: 160, height: 160))
    }
}
