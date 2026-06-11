import Foundation

struct AppVersionInfo: Equatable {
    let shortVersion: String
    let buildVersion: String

    init(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        shortVersion = infoDictionary["CFBundleShortVersionString"] as? String ?? "0.0.0"
        buildVersion = infoDictionary["CFBundleVersion"] as? String ?? "0"
    }

    var displayVersion: String {
        "\(shortVersion) (\(buildVersion))"
    }
}
