import Foundation
import Combine

enum AppInfo {
    static var name: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Snowdesk"
    }
}

final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    @Published var intensity: Double { didSet { d.set(intensity, forKey: "intensity") } }
    @Published var speed: Double { didSet { d.set(speed, forKey: "speed") } }
    @Published var wind: Double { didSet { d.set(wind, forKey: "wind") } }
    @Published var flakeSize: Double { didSet { d.set(flakeSize, forKey: "flakeSize") } }
    @Published var accumulate: Bool { didSet { d.set(accumulate, forKey: "accumulate") } }
    @Published var maxPile: Double { didSet { d.set(maxPile, forKey: "maxPile") } }
    @Published var snowballs: Bool { didSet { d.set(snowballs, forKey: "snowballs") } }
    @Published var allScreens: Bool { didSet { d.set(allScreens, forKey: "allScreens") } }

    static let defaults: [String: Any] = [
        "intensity": 0.6,
        "speed": 1.0,
        "wind": 0.15,
        "flakeSize": 1.0,
        "accumulate": true,
        "maxPile": 16.0,
        "snowballs": true,
        "allScreens": true,
    ]

    private init() {
        d.register(defaults: Prefs.defaults)
        intensity = d.double(forKey: "intensity")
        speed = d.double(forKey: "speed")
        wind = d.double(forKey: "wind")
        flakeSize = d.double(forKey: "flakeSize")
        accumulate = d.bool(forKey: "accumulate")
        maxPile = d.double(forKey: "maxPile")
        snowballs = d.bool(forKey: "snowballs")
        allScreens = d.bool(forKey: "allScreens")
    }

    func resetToDefaults() {
        intensity = Prefs.defaults["intensity"] as! Double
        speed = Prefs.defaults["speed"] as! Double
        wind = Prefs.defaults["wind"] as! Double
        flakeSize = Prefs.defaults["flakeSize"] as! Double
        accumulate = Prefs.defaults["accumulate"] as! Bool
        maxPile = Prefs.defaults["maxPile"] as! Double
        snowballs = Prefs.defaults["snowballs"] as! Bool
        allScreens = Prefs.defaults["allScreens"] as! Bool
    }
}
