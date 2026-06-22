import AndroidSyncCore
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

    func testAboutVersionAndBuildLabelsMapToChineseAndEnglish() {
        XCTAssertEqual(
            AppStrings.text(.about, language: .simplifiedChinese),
            "关于"
        )
        XCTAssertEqual(
            AppStrings.text(.version, language: .simplifiedChinese),
            "版本"
        )
        XCTAssertEqual(
            AppStrings.text(.build, language: .simplifiedChinese),
            "构建号"
        )
        XCTAssertEqual(AppStrings.text(.about, language: .english), "About")
        XCTAssertEqual(AppStrings.text(.version, language: .english), "Version")
        XCTAssertEqual(AppStrings.text(.build, language: .english), "Build")
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

    func testEveryStringKeyHasAnExplicitChineseAndEnglishTranslation() {
        let expectedKeys = Set(AppStringKey.allCases)

        for language in AppLanguage.allCases {
            XCTAssertEqual(
                AppStrings.tableKeys(for: language),
                expectedKeys,
                "Translation table keys differ for \(language.rawValue)"
            )
            for key in AppStringKey.allCases {
                XCTAssertTrue(
                    AppStrings.hasTranslation(key, language: language),
                    "Missing explicit \(language.rawValue) text for \(key.rawValue)"
                )
            }
        }
    }

    func testUploadKindTitlesFollowSelectedLanguage() {
        XCTAssertEqual(
            UploadKind.photo.title(using: .simplifiedChinese),
            "照片"
        )
        XCTAssertEqual(
            UploadKind.video.title(using: .simplifiedChinese),
            "视频"
        )
        XCTAssertEqual(
            UploadKind.file.title(using: .simplifiedChinese),
            "文件"
        )
        XCTAssertEqual(UploadKind.photo.title(using: .english), "Photo")
        XCTAssertEqual(UploadKind.video.title(using: .english), "Video")
        XCTAssertEqual(UploadKind.file.title(using: .english), "File")
    }

    func testMissingOrBlankContentTypeUsesLocalizedUploadKind() {
        XCTAssertEqual(
            AppFormatters.contentType(
                nil,
                kind: .photo,
                language: .simplifiedChinese
            ),
            "照片"
        )
        XCTAssertEqual(
            AppFormatters.contentType(
                "  ",
                kind: .video,
                language: .english
            ),
            "Video"
        )
        XCTAssertEqual(
            AppFormatters.contentType(
                "image/heic",
                kind: .photo,
                language: .simplifiedChinese
            ),
            "image/heic"
        )
    }

    func testMetadataFormattersUseSelectedLanguageLocale() {
        for language in AppLanguage.allCases {
            XCTAssertEqual(
                AppFormatters.byteCountStyle(language: language)
                    .locale.identifier,
                language.locale.identifier
            )
            XCTAssertEqual(
                AppFormatters.dateStyle(language: language).locale,
                language.locale
            )
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
