import Foundation

struct AppVersionInfo: Equatable {
    static let current = AppVersionInfo()

    let version: String
    let build: String

    init(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        version = Self.versionValue(
            infoDictionary["CFBundleShortVersionString"],
            fallback: "0.0.0"
        )
        build = Self.versionValue(
            infoDictionary["CFBundleVersion"],
            fallback: "0"
        )
    }

    var display: String {
        "\(version) (\(build))"
    }

    var shortVersion: String { version }
    var buildVersion: String { build }
    var displayVersion: String { display }

    private static func versionValue(_ value: Any?, fallback: String) -> String {
        guard let value = value as? String else {
            return fallback
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
