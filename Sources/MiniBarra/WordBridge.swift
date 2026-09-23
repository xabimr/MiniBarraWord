import AppKit

/// Estado del formato de la selección actual en Word.
struct SelectionState {
    var fontName: String      // vacío si la selección mezcla fuentes
    var fontSize: Double?     // nil si mezcla tamaños
    var bold: Bool
    var italic: Bool
    var underline: Bool
    var styleName: String
}

/// Colores de resaltado que admite Word (WdColorIndex).
struct HighlightColor {
    let term: String          // término AppleScript
    let label: String
    let color: NSColor
}

/// Estilos integrados de Word (WdBuiltinStyle). El nombre visible se pide a Word
/// para que salga en el idioma de la instalación.
struct BuiltinStyle {
    let term: String
    let fallbackName: String
}

/// Todo lo que la barra hace en Word pasa por aquí, vía AppleScript.
final class WordBridge {
    static let bundleID = "com.microsoft.Word"

    static let highlightColors: [HighlightColor] = [
        .init(term: "yellow", label: "Amarillo", color: .hex(0xFFFF00)),
        .init(term: "bright green", label: "Verde brillante", color: .hex(0x00FF00)),
        .init(term: "turquoise", label: "Turquesa", color: .hex(0x00FFFF)),
        .init(term: "pink", label: "Rosa", color: .hex(0xFF00FF)),
        .init(term: "blue", label: "Azul", color: .hex(0x0000FF)),
        .init(term: "red", label: "Rojo", color: .hex(0xFF0000)),
        .init(term: "dark blue", label: "Azul oscuro", color: .hex(0x000080)),
        .init(term: "teal", label: "Verde azulado", color: .hex(0x008080)),
        .init(term: "green", label: "Verde", color: .hex(0x008000)),
        .init(term: "violet", label: "Violeta", color: .hex(0x800080)),
        .init(term: "dark red", label: "Rojo oscuro", color: .hex(0x800000)),
        .init(term: "dark yellow", label: "Amarillo oscuro", color: .hex(0x808000)),
        .init(term: "gray50", label: "Gris 50 %", color: .hex(0x808080)),
        .init(term: "gray25", label: "Gris 25 %", color: .hex(0xC0C0C0)),
        .init(term: "black", label: "Negro", color: .hex(0x000000)),
    ]

    static let styles: [BuiltinStyle] = [
        .init(term: "style normal", fallbackName: "Normal"),
        .init(term: "style title", fallbackName: "Título"),
        .init(term: "style subtitle", fallbackName: "Subtítulo"),
        .init(term: "style heading1", fallbackName: "Título 1"),
        .init(term: "style heading2", fallbackName: "Título 2"),
        .init(term: "style heading3", fallbackName: "Título 3"),
        .init(term: "style heading4", fallbackName: "Título 4"),
        .init(term: "style quote", fallbackName: "Cita"),
        .init(term: "style intense quote", fallbackName: "Cita destacada"),
        .init(term: "style list bullet", fallbackName: "Lista con viñetas"),
        .init(term: "style list number", fallbackName: "Lista con números"),
        .init(term: "style strong", fallbackName: "Fuerte"),
        .init(term: "style emphasis", fallbackName: "Énfasis"),
        .init(term: "style subtle emphasis", fallbackName: "Énfasis sutil"),
        .init(term: "style intense emphasis", fallbackName: "Énfasis intenso"),
        .init(term: "style caption", fallbackName: "Descripción"),
    ]

    private var compiled: [String: NSAppleScript] = [:]
    private(set) var styleNames: [String]?

    var wordApp: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first
    }

    var wordIsFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.bundleID
    }

    // MARK: - Ejecución

    /// Ejecuta `body` dentro de `tell application "Microsoft Word"`, con un tiempo
    /// máximo corto para no bloquear la barra si Word está ocupado con un diálogo.
    @discardableResult
    func run(_ body: String, cache: Bool = true) -> NSAppleEventDescriptor? {
        let source = """
        with timeout of 3 seconds
        tell application id "\(Self.bundleID)"
        \(body)
        end tell
        end timeout
        """
        var script = cache ? compiled[source] : nil
        if script == nil {
            guard let s = NSAppleScript(source: source) else { return nil }
            var err: NSDictionary?
            if !s.compileAndReturnError(&err) {
                NSLog("MiniBarra: error al compilar AppleScript: %@", err ?? [:])
                return nil
            }
            if cache { compiled[source] = s }
            script = s
        }
        var error: NSDictionary?
        let result = script!.executeAndReturnError(&error)
        if let error {
            NSLog("MiniBarra: error de AppleScript: %@", error)
            return nil
        }
        return result
    }

    /// Solo compila todos los scripts (sin ejecutarlos). Sirve para comprobar la
    /// sintaxis contra el diccionario de Word sin tocar ningún documento.
    func compileCheck() -> [String] {
        var failures: [String] = []
        for (name, body) in Self.allScriptsForCheck() {
            let source = "tell application id \"\(Self.bundleID)\"\n\(body)\nend tell"
            var err: NSDictionary?
            if NSAppleScript(source: source)?.compileAndReturnError(&err) != true {
                failures.append("\(name): \(err?[NSAppleScript.errorMessage] ?? "?")")
            }
        }
        return failures
    }

    static func quoted(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    // MARK: - Consulta

    private static let stateScript = """
    set s to selection
    if (selection end of s) ≤ (selection start of s) then return "0"
    set f to font object of s
    set fn to ""
    try
        set fn to (name of f) as text
        if fn is "missing value" then set fn to ""
    end try
    set fz to ""
    try
        set fz to ((font size of f) * 10) as integer as text
    end try
    set bo to "0"
    try
        if (bold of f) is true then set bo to "1"
    end try
    set itl to "0"
    try
        if (italic of f) is true then set itl to "1"
    end try
    set ul to "0"
    try
        set u to underline of f
        if u is not missing value and u is not underline none then set ul to "1"
    end try
    set sn to ""
    try
        set sn to (get name local of style of s)
    end try
    set AppleScript's text item delimiters to (character id 31)
    set r to {"1", fn, fz, bo, itl, ul, sn} as text
    set AppleScript's text item delimiters to ""
    return r
    """

    /// Devuelve el formato de la selección, o nil si no hay texto seleccionado.
    func selectionState() -> SelectionState? {
        guard let text = run(Self.stateScript)?.stringValue else { return nil }
        let parts = text.components(separatedBy: "\u{1F}")
        guard parts.count >= 7, parts[0] == "1" else { return nil }
        let size = Int(parts[2]).flatMap { $0 > 0 && $0 < 20000 ? Double($0) / 10 : nil }
        return SelectionState(
            fontName: parts[1],
            fontSize: size,
            bold: parts[3] == "1",
            italic: parts[4] == "1",
            underline: parts[5] == "1",
            styleName: parts[6]
        )
    }

    /// Nombres de los estilos integrados en el idioma de Word (se piden una vez).
    func loadStyleNames() -> [String] {
        if let styleNames { return styleNames }
        var body = "set out to {}\nset d to active document\n"
        for style in Self.styles {
            body += """
            try
                set end of out to (get name local of Word style (\(style.term)) of d)
            on error
                set end of out to ""
            end try

            """
        }
        body += """
        set AppleScript's text item delimiters to (character id 31)
        set r to out as text
        set AppleScript's text item delimiters to ""
        return r
        """
        let fetched = run(body, cache: false)?.stringValue?.components(separatedBy: "\u{1F}") ?? []
        let names = Self.styles.enumerated().map { i, style in
            i < fetched.count && !fetched[i].isEmpty ? fetched[i] : style.fallbackName
        }
        if fetched.count == Self.styles.count { styleNames = names }
        return names
    }

    // MARK: - Acciones

    private static let toggleBold = """
    set f to font object of selection
    if (bold of f) is true then
        set bold of f to false
    else
        set bold of f to true
    end if
    """

    private static let toggleItalic = """
    set f to font object of selection
    if (italic of f) is true then
        set italic of f to false
    else
        set italic of f to true
    end if
    """

    private static let toggleUnderline = """
    set f to font object of selection
    set u to underline of f
    if u is not missing value and u is not underline none then
        set underline of f to underline none
    else
        set underline of f to underline single
    end if
    """

    func toggleBold() { run(Self.toggleBold) }
    func toggleItalic() { run(Self.toggleItalic) }
    func toggleUnderline() { run(Self.toggleUnderline) }

    func setFontName(_ name: String) {
        run("set name of font object of selection to \(Self.quoted(name))")
    }

    func setFontSize(_ size: Double) {
        run("set font size of font object of selection to \(String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), size))")
    }

    /// `nil` = color automático.
    func setFontColor(_ color: NSColor?) {
        guard let rgb = color?.usingColorSpace(.sRGB) else {
            run("set color index of font object of selection to auto")
            return
        }
        // Word usa componentes de 16 bits (0–65535).
        let c = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { Int(($0 * 65535).rounded()) }
        run("set color of font object of selection to {\(c[0]), \(c[1]), \(c[2])}")
    }

    /// `nil` = quitar resaltado.
    func setHighlight(_ color: HighlightColor?) {
        run("set highlight color index of text object of selection to \(color?.term ?? "no highlight")")
    }

    func copyFormat() { run("copy format selection") }
    func pasteFormat() { run("paste format selection") }
    func clearFormatting() { run("clear formatting selection") }

    func toggleBullets() { run("apply bullet default (list format of text object of selection)") }
    func toggleNumbering() { run("apply number default (list format of text object of selection)") }
    func removeList() { run("remove numbers (list format of text object of selection)") }

    func applyStyle(_ style: BuiltinStyle) {
        run("set style of text object of selection to \(style.term)")
    }

    func typeText(_ text: String) {
        run("type text selection text \(Self.quoted(text))", cache: false)
    }

    /// Plan B para el comentario si no hay permiso de Accesibilidad.
    func addEmptyComment() {
        run("make new Word comment at active document with properties {text range:text object of selection, comment text:\"\"}")
    }

    static func allScriptsForCheck() -> [(String, String)] {
        var list: [(String, String)] = [
            ("estado", stateScript),
            ("negrita", toggleBold),
            ("cursiva", toggleItalic),
            ("subrayado", toggleUnderline),
            ("fuente", "set name of font object of selection to \"Arial\""),
            ("tamaño", "set font size of font object of selection to 10.5"),
            ("color", "set color of font object of selection to {65535, 0, 0}"),
            ("color auto", "set color index of font object of selection to auto"),
            ("sin resaltado", "set highlight color index of text object of selection to no highlight"),
            ("copiar formato", "copy format selection"),
            ("pegar formato", "paste format selection"),
            ("borrar formato", "clear formatting selection"),
            ("viñetas", "apply bullet default (list format of text object of selection)"),
            ("numeración", "apply number default (list format of text object of selection)"),
            ("quitar lista", "remove numbers (list format of text object of selection)"),
            ("escribir", "type text selection text \"x\""),
            ("comentario", "make new Word comment at active document with properties {text range:text object of selection, comment text:\"\"}"),
        ]
        for h in highlightColors {
            list.append(("resaltado \(h.term)", "set highlight color index of text object of selection to \(h.term)"))
        }
        for s in styles {
            list.append(("estilo \(s.term)", "set style of text object of selection to \(s.term)"))
            list.append(("nombre \(s.term)", "get name local of Word style (\(s.term)) of active document"))
        }
        return list
    }
}

extension NSColor {
    static func hex(_ v: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255,
                alpha: 1)
    }
}
