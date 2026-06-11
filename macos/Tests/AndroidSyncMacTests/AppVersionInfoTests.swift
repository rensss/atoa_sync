import XCTest
@testable import AndroidSyncMac

final class AppVersionInfoTests: XCTestCase {
    func testParsesBundleDictionaryAndBuildsDisplayVersion() {
        let version = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "1.2.3",
                "CFBundleVersion": "42",
            ]
        )

        XCTAssertEqual(version.shortVersion, "1.2.3")
        XCTAssertEqual(version.buildVersion, "42")
        XCTAssertEqual(version.displayVersion, "1.2.3 (42)")
    }
}
