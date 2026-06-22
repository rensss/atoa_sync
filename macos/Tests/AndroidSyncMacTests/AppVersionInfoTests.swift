import XCTest
@testable import AndroidSyncMac

final class AppVersionInfoTests: XCTestCase {
    func testParsesBundleDictionaryAndBuildsDisplayVersion() {
        let info = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": "1.2.3",
                "CFBundleVersion": "42",
            ]
        )

        XCTAssertEqual(info.version, "1.2.3")
        XCTAssertEqual(info.build, "42")
        XCTAssertEqual(info.display, "1.2.3 (42)")
        XCTAssertEqual(info.shortVersion, info.version)
        XCTAssertEqual(info.buildVersion, info.build)
        XCTAssertEqual(info.displayVersion, info.display)
    }

    func testCurrentReadsTheMainBundle() {
        XCTAssertEqual(AppVersionInfo.current, AppVersionInfo())
    }

    func testTrimsVersionValues() {
        let info = AppVersionInfo(
            infoDictionary: [
                "CFBundleShortVersionString": " 1.2.3 ",
                "CFBundleVersion": "\n42\t",
            ]
        )

        XCTAssertEqual(info.version, "1.2.3")
        XCTAssertEqual(info.build, "42")
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

        for info in [missing, invalid, blank] {
            XCTAssertEqual(info.version, "0.0.0")
            XCTAssertEqual(info.build, "0")
            XCTAssertEqual(info.display, "0.0.0 (0)")
        }
    }
}
