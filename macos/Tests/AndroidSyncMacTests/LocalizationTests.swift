import XCTest
@testable import AndroidSyncMac

final class LocalizationTests: XCTestCase {
    func testDefaultLanguageIsSimplifiedChinese() {
        XCTAssertEqual(AppLanguage.default, .simplifiedChinese)
    }

    func testSettingsTitleMapsToChineseAndEnglish() {
        XCTAssertEqual(AppStrings(language: .simplifiedChinese).settings, "设置")
        XCTAssertEqual(AppStrings(language: .english).settings, "Settings")
    }
}
