import Foundation

enum Prefs {
    private static let d = UserDefaults.standard

    static func favorites(for uuid: String) -> [String] {
        d.stringArray(forKey: "fav.\(uuid)") ?? []
    }

    static func toggleFavorite(_ key: String, for uuid: String) {
        var f = favorites(for: uuid)
        if let i = f.firstIndex(of: key) { f.remove(at: i) } else { f.append(key) }
        d.set(f, forKey: "fav.\(uuid)")
    }

    static func previous(for uuid: String) -> String? { d.string(forKey: "prev.\(uuid)") }
    static func setPrevious(_ key: String?, for uuid: String) { d.set(key, forKey: "prev.\(uuid)") }

    static var showAllModes: Bool {
        get { d.bool(forKey: "showAllModes") }
        set { d.set(newValue, forKey: "showAllModes") }
    }
}
