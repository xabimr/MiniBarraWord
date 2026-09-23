import AppKit

enum Icons {
    static func symbol(_ name: String, size: CGFloat = 15, weight: NSFont.Weight = .regular,
                       fallback: String = "questionmark") -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: fallback, accessibilityDescription: nil)!
        return image.withSymbolConfiguration(config) ?? image
    }

    /// Letras de negrita/cursiva/subrayado según el idioma del sistema, como en Word
    /// (N K S en español y gallego, N I S en portugués, B I U en el resto).
    static var formatLetters: (bold: String, italic: String, underline: String) {
        let lang = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        switch lang {
        case "es", "gl": return ("N", "K", "S")
        case "pt": return ("N", "I", "S")
        default: return ("B", "I", "U")
        }
    }

    static func letter(_ s: String, bold: Bool = false, italic: Bool = false, underline: Bool = false) -> NSAttributedString {
        var font = NSFont.systemFont(ofSize: 16, weight: bold ? .bold : .regular)
        if italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        if underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        return NSAttributedString(string: s, attributes: attrs)
    }

    /// "A" con una barra de color debajo (color de fuente). nil = automático.
    static func fontColor(_ color: NSColor?) -> NSImage {
        NSImage(size: NSSize(width: 22, height: 22), flipped: false) { rect in
            let font = NSFont.systemFont(ofSize: 15, weight: .medium)
            let s = NSAttributedString(string: "A", attributes: [.font: font, .foregroundColor: NSColor.labelColor])
            let size = s.size()
            s.draw(at: NSPoint(x: (rect.width - size.width) / 2, y: 5.5))
            colorBar(color ?? .labelColor, in: rect)
            return true
        }
    }

    /// "A" con una flecha pequeña arriba o abajo (aumentar/reducir fuente).
    static func fontStep(up: Bool) -> NSImage {
        let caret = symbol(up ? "chevron.up" : "chevron.down", size: 7, weight: .bold)
        return NSImage(size: NSSize(width: 22, height: 22), flipped: false) { rect in
            let font = NSFont.systemFont(ofSize: up ? 17 : 13, weight: .regular)
            let s = NSAttributedString(string: "A", attributes: [.font: font, .foregroundColor: NSColor.labelColor])
            let size = s.size()
            s.draw(at: NSPoint(x: up ? 2 : 4, y: 2))
            let tinted = tinted(caret, .labelColor)
            tinted.draw(in: NSRect(x: (up ? 2 : 4) + size.width, y: rect.height - caret.size.height - (up ? 3 : 6),
                                   width: caret.size.width, height: caret.size.height))
            return true
        }
    }

    /// Rotulador con una barra de color debajo (resaltado). nil = sin color.
    static func highlighter(_ color: NSColor?) -> NSImage {
        let pen = symbol("highlighter", size: 13, fallback: "pencil.tip")
        return NSImage(size: NSSize(width: 22, height: 22), flipped: false) { rect in
            let tinted = tinted(pen, .labelColor)
            let s = tinted.size
            tinted.draw(in: NSRect(x: (rect.width - s.width) / 2, y: 6, width: s.width, height: s.height))
            colorBar(color, in: rect)
            return true
        }
    }

    private static func colorBar(_ color: NSColor?, in rect: NSRect) {
        let bar = NSRect(x: 3, y: 1.5, width: rect.width - 6, height: 3.5)
        if let color {
            color.setFill()
            NSBezierPath(roundedRect: bar, xRadius: 1, yRadius: 1).fill()
        } else {
            NSColor.secondaryLabelColor.setStroke()
            NSBezierPath(roundedRect: bar.insetBy(dx: 0.5, dy: 0.5), xRadius: 1, yRadius: 1).stroke()
        }
    }

    static func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    static func swatch(_ color: NSColor?, size: CGFloat = 14) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            if let color { color.setFill(); path.fill() }
            NSColor.separatorColor.setStroke()
            path.stroke()
            if color == nil {
                NSColor.systemRed.setStroke()
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: 2, y: 2))
                slash.line(to: NSPoint(x: rect.maxX - 2, y: rect.maxY - 2))
                slash.stroke()
            }
            return true
        }
    }
}

/// Rejilla de muestras de color para meter dentro de un NSMenuItem.
final class SwatchGrid: NSView {
    struct Swatch {
        let color: NSColor
        let name: String
    }

    private let rows: [[Swatch]]
    private let titles: [String?]
    private let onPick: (Swatch) -> Void
    private var hover: (Int, Int)?
    private let cell: CGFloat = 20
    private let gap: CGFloat = 3
    private let padding: CGFloat = 12
    private let titleHeight: CGFloat = 20

    /// `titles[i]` es un encabezado opcional que se dibuja antes de la fila i.
    init(rows: [[Swatch]], titles: [String?], onPick: @escaping (Swatch) -> Void) {
        self.rows = rows
        self.titles = titles
        self.onPick = onPick
        let columns = rows.map(\.count).max() ?? 0
        let headers = CGFloat(titles.compactMap { $0 }.count)
        let width = padding * 2 + CGFloat(columns) * cell + CGFloat(columns - 1) * gap
        let height = padding + CGFloat(rows.count) * (cell + gap) + headers * titleHeight + 4
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    private func frames() -> [[NSRect]] {
        var y: CGFloat = 4
        var result: [[NSRect]] = []
        for (i, row) in rows.enumerated() {
            if i < titles.count, titles[i] != nil { y += titleHeight }
            result.append(row.indices.map { NSRect(x: padding + CGFloat($0) * (cell + gap), y: y, width: cell, height: cell) })
            y += cell + gap
        }
        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        let f = frames()
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        for (i, row) in rows.enumerated() {
            if i < titles.count, let title = titles[i], let first = f[i].first {
                (title as NSString).draw(at: NSPoint(x: padding, y: first.minY - titleHeight + 3), withAttributes: titleAttrs)
            }
            for (j, swatch) in row.enumerated() {
                let r = f[i][j]
                swatch.color.setFill()
                NSBezierPath(roundedRect: r, xRadius: 3, yRadius: 3).fill()
                let isHover = hover.map { $0 == (i, j) } ?? false
                (isHover ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
                let border = NSBezierPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
                border.lineWidth = isHover ? 2 : 1
                border.stroke()
            }
        }
    }

    private func hit(_ event: NSEvent) -> (Int, Int)? {
        let p = convert(event.locationInWindow, from: nil)
        for (i, row) in frames().enumerated() {
            for (j, r) in row.enumerated() where r.insetBy(dx: -1.5, dy: -1.5).contains(p) { return (i, j) }
        }
        return nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        let h = hit(event)
        if h == nil && hover == nil { return }
        hover = h
        toolTip = h.map { rows[$0.0][$0.1].name }
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hover = nil
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let (i, j) = hit(event) else { return }
        enclosingMenuItem?.menu?.cancelTracking()
        let swatch = rows[i][j]
        DispatchQueue.main.async { self.onPick(swatch) }
    }
}
