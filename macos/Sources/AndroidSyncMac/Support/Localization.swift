import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    static let `default`: AppLanguage = .simplifiedChinese

    var id: String { rawValue }
}

struct AppStrings {
    let language: AppLanguage

    var settings: String {
        switch language {
        case .simplifiedChinese:
            "设置"
        case .english:
            "Settings"
        }
    }
}
