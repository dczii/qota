import Foundation

enum AppInfo {
    /// Falls back only when running the bare executable, which has no Info.plist.
    static let version: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }()
}
