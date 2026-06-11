import Foundation

struct AppVersionInfo: Equatable {
    let shortVersion: String
    let buildVersion: String

    init(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        shortVersion = Self.versionValue(
            infoDictionary["CFBundleShortVersionString"],
            fallback: "0.0.0"
        )
        buildVersion = Self.versionValue(
            infoDictionary["CFBundleVersion"],
            fallback: "0"
        )
    }

    var displayVersion: String {
        "\(shortVersion) (\(buildVersion))"
    }

    private static func versionValue(_ value: Any?, fallback: String) -> String {
        guard let value = value as? String else {
            return fallback
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
