import XCTest
@testable import AndroidSyncMac

final class LocalizationTests: XCTestCase {
    func testDefaultLanguageIsSimplifiedChinese() {
        XCTAssertEqual(AppLanguage.default, .simplifiedChinese)
    }

    func testSettingsTitleMapsToChineseAndEnglish() {
        XCTAssertEqual(
            AppStrings.text(.settings, language: .simplifiedChinese),
            "设置"
        )
        XCTAssertEqual(
            AppStrings.text(.settings, language: .english),
            "Settings"
        )
    }
}
