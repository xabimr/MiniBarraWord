import AppKit

enum Settings {
    private static let defaults = UserDefaults.standard

    static var enabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    static var showOnDoubleClick: Bool {
        get { defaults.object(forKey: "showOnDoubleClick") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showOnDoubleClick") }
    }

    /// Último color de fuente usado (el botón principal lo reaplica). nil = automático.
    static var fontColor: NSColor? {
        get {
            guard let v = defaults.object(forKey: "fontColor") as? Int else { return .hex(0xFF0000) }
            return v < 0 ? nil : .hex(v)
        }
        set {
            guard let c = newValue?.usingColorSpace(.sRGB) else { defaults.set(-1, forKey: "fontColor"); return }
            let v = (Int((c.redComponent * 255).rounded()) << 16)
                | (Int((c.greenComponent * 255).rounded()) << 8)
                | Int((c.blueComponent * 255).rounded())
            defaults.set(v, forKey: "fontColor")
        }
    }

    /// Último color de resaltado usado (término de Word). "" = sin resaltado.
    static var highlightTerm: String {
        get { defaults.string(forKey: "highlightTerm") ?? "yellow" }
        set { defaults.set(newValue, forKey: "highlightTerm") }
    }

    /// Oculta el icono «Aa» de la barra de menús. Se recupera abriendo la app otra vez.
    static var hideMenuBarIcon: Bool {
        get { defaults.bool(forKey: "hideMenuBarIcon") }
        set { defaults.set(newValue, forKey: "hideMenuBarIcon") }
    }

    static var recentFonts: [String] {
        get { defaults.stringArray(forKey: "recentFonts") ?? [] }
        set { defaults.set(Array(newValue.prefix(8)), forKey: "recentFonts") }
    }

    static func noteRecentFont(_ name: String) {
        recentFonts = [name] + recentFonts.filter { $0 != name }
    }
}
