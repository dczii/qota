import CoreGraphics
import Foundation

enum Preferences {
    private static let defaults = UserDefaults.standard

    static var hudVisible: Bool {
        get { defaults.object(forKey: "hudVisible") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hudVisible") }
    }

    static var hudOrigin: CGPoint? {
        get {
            guard defaults.object(forKey: "hudOriginX") != nil else { return nil }
            return CGPoint(
                x: defaults.double(forKey: "hudOriginX"),
                y: defaults.double(forKey: "hudOriginY")
            )
        }
        set {
            guard let newValue else { return }
            defaults.set(newValue.x, forKey: "hudOriginX")
            defaults.set(newValue.y, forKey: "hudOriginY")
        }
    }

    static var warnPercent: Double { 80 }
    static var criticalPercent: Double { 90 }
}
