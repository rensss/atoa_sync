import SwiftData
import XCTest
@testable import AndroidSyncMac

final class LocalizationTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "LocalizationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultLanguageIsSimplifiedChinese() {
        XCTAssertEqual(AppLanguage.default, .simplifiedChinese)
    }

    func testInvalidPersistedLanguageFallsBackToSimplifiedChinese() {
        defaults.set("invalid-language", forKey: AppLanguage.defaultsKey)

        XCTAssertEqual(AppLanguage.load(from: defaults), .simplifiedChinese)
    }

    func testLanguagePersistsWithoutUsingStandardDefaults() {
        AppLanguage.english.save(to: defaults)

        XCTAssertEqual(
            defaults.string(forKey: AppLanguage.defaultsKey),
            AppLanguage.english.rawValue
        )
        XCTAssertEqual(AppLanguage.load(from: defaults), .english)
    }

    @MainActor
    func testAppModelPersistsLanguageChangesToInjectedDefaults() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaItemEntity.self,
            configurations: configuration
        )
        let model = AppModel(
            modelContainer: container,
            userDefaults: defaults
        )

        XCTAssertEqual(model.language, .simplifiedChinese)

        model.language = .english

        XCTAssertEqual(AppLanguage.load(from: defaults), .english)
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

    func testLibraryTitlesFollowSelectedLanguage() {
        XCTAssertEqual(
            LibraryCategory.photos.title(using: .simplifiedChinese),
            "照片"
        )
        XCTAssertEqual(
            LibraryCategory.photos.title(using: .english),
            "Photos"
        )
        XCTAssertEqual(
            LibraryDateFilter.sevenDays.title(using: .simplifiedChinese),
            "最近 7 天"
        )
        XCTAssertEqual(
            LibrarySort.newest.title(using: .english),
            "Newest First"
        )
    }

    func testEveryStringKeyHasChineseAndEnglishText() {
        for language in AppLanguage.allCases {
            for key in AppStringKey.allCases {
                XCTAssertNotEqual(
                    AppStrings.text(key, language: language),
                    key.rawValue,
                    "Missing \(language.rawValue) text for \(key.rawValue)"
                )
            }
        }
    }

    func testPortFormatUsesSelectedLanguage() {
        XCTAssertEqual(
            AppStrings.format(.portFormat, language: .simplifiedChinese, 8765),
            "端口 8765"
        )
        XCTAssertEqual(
            AppStrings.format(.portFormat, language: .english, 8765),
            "Port 8765"
        )
    }
}
