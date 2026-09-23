// Genera Support/AppIcon.icns: barra flotante estilizada sobre fondo azul Word.
import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1
    let card = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    NSGradient(starting: .init(srgbRed: 0.17, green: 0.42, blue: 0.86, alpha: 1),
               ending: .init(srgbRed: 0.09, green: 0.23, blue: 0.56, alpha: 1))!
        .draw(in: NSBezierPath(roundedRect: card, xRadius: s * 0.18, yRadius: s * 0.18), angle: -90)
    // Líneas de texto
    NSColor.white.withAlphaComponent(0.35).setFill()
    for (i, w) in [0.62, 0.5, 0.56].enumerated() {
        NSBezierPath(roundedRect: NSRect(x: s * 0.22, y: s * (0.26 + Double(i) * 0.1), width: s * w, height: s * 0.045),
                     xRadius: s * 0.02, yRadius: s * 0.02).fill()
    }
    // Barra flotante
    let bar = NSRect(x: s * 0.17, y: s * 0.56, width: s * 0.66, height: s * 0.2)
    let shadow = NSShadow(); shadow.shadowBlurRadius = s * 0.03; shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: bar, xRadius: s * 0.05, yRadius: s * 0.05).fill()
    NSShadow().set()
    let letters: [(String, NSFont)] = [
        ("N", .systemFont(ofSize: s * 0.12, weight: .heavy)),
        ("K", NSFontManager.shared.convert(.systemFont(ofSize: s * 0.12, weight: .medium), toHaveTrait: .italicFontMask)),
        ("S", .systemFont(ofSize: s * 0.12, weight: .medium)),
    ]
    for (i, (t, f)) in letters.enumerated() {
        var attrs: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: NSColor(srgbRed: 0.1, green: 0.2, blue: 0.45, alpha: 1)]
        if t == "S" { attrs[.underlineStyle] = NSUnderlineStyle.thick.rawValue }
        let str = NSAttributedString(string: t, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: bar.minX + bar.width * (0.2 + CGFloat(i) * 0.3) - sz.width / 2, y: bar.midY - sz.height / 2))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: dir.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
