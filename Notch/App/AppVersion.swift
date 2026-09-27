import Foundation

/// The version shown to people, read from the app's Info.plist:
/// `CFBundleShortVersionString` (MARKETING_VERSION, e.g. 1.1.0) and `CFBundleVersion`
/// (the build number, which Tools/install.sh sets to the git commit count).
enum AppVersion {
    static var current: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return display(version: info["CFBundleShortVersionString"] as? String,
                       build: info["CFBundleVersion"] as? String)
    }

    static func display(version: String?, build: String?) -> String {
        let version = version?.isEmpty == false ? version! : "?"
        guard let build, !build.isEmpty else { return "Notch \(version)" }
        return "Notch \(version) (\(build))"
    }
}
