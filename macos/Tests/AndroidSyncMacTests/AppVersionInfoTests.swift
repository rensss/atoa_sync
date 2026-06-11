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

    func testTrimsVersionValues() {
        let version = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": " 1.2.3 ",
                "CFBundleVersion": "\n42\t",
            ]
        )

        XCTAssertEqual(version.shortVersion, "1.2.3")
        XCTAssertEqual(version.buildVersion, "42")
    }

    func testFallsBackForMissingInvalidAndBlankVersionValues() {
        let missing = AppVersionInfo(infoDictionary: [:])
        let invalid = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": 123,
                "CFBundleVersion": false,
            ]
        )
        let blank = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": " \n ",
                "CFBundleVersion": "\t",
            ]
        )

        for version in [missing, invalid, blank] {
            XCTAssertEqual(version.shortVersion, "0.0.0")
            XCTAssertEqual(version.buildVersion, "0")
            XCTAssertEqual(version.displayVersion, "0.0.0 (0)")
        }
    }
}
