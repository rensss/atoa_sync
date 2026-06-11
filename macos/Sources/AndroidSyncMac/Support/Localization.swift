import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    static let `default`: AppLanguage = .simplifiedChinese

    var id: String { rawValue }
}

enum AppStringKey: String {
    case settings
}

enum AppStrings {
    private static let table: [AppLanguage: [AppStringKey: String]] = [
        .simplifiedChinese: [
            .settings: "设置",
        ],
        .english: [
            .settings: "Settings",
        ],
    ]

    static func text(_ key: AppStringKey, language: AppLanguage) -> String {
        table[language]?[key]
            ?? table[AppLanguage.default]?[key]
            ?? key.rawValue
    }
}
