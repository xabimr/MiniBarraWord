import AppKit

/// Botón de la barra: icono o texto, fondo al pasar el ratón y estado activo.
/// Acepta el primer clic para funcionar sin activar la app (Word sigue delante).
final class BarButton: NSView {
    var onClick: ((NSEvent) -> Void)?
    var isOn = false { didSet { needsDisplay = true } }

    private let width: CGFloat
    private var hovering = false { didSet { needsDisplay = true } }
    private var pressed = false { didSet { needsDisplay = true } }
    private let imageView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let chevron: NSImageView?

    /// - Parameters:
    ///   - text: si se da, el botón muestra texto (alineado a la izquierda si hay chevron).
    ///   - chevron: añade una flecha ▾ a la derecha (desplegables de fuente y tamaño).
    init(image: NSImage? = nil, text: NSAttributedString? = nil, width: CGFloat,
         chevron: Bool = false, tooltip: String) {
        self.width = width
        self.chevron = chevron ? NSImageView(image: Icons.symbol("chevron.down", size: 9, weight: .semibold)) : nil
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 30))
        toolTip = tooltip
        setAccessibilityRole(.button)
        setAccessibilityLabel(tooltip)

        imageView.imageScaling = .scaleNone
        imageView.contentTintColor = .labelColor
        imageView.image = image
        addSubview(imageView)

        label.lineBreakMode = .byTruncatingTail
        label.textColor = .labelColor
        label.font = .systemFont(ofSize: 13)
        if let text { label.attributedStringValue = text }
        label.isHidden = text == nil
        addSubview(label)

        if let chevronView = self.chevron {
            chevronView.contentTintColor = .secondaryLabelColor
            addSubview(chevronView)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    var image: NSImage? {
        get { imageView.image }
        set { imageView.image = newValue }
    }

    var title: String {
        get { label.stringValue }
        set { label.stringValue = newValue }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: width, height: 30) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        let chevronWidth: CGFloat = chevron == nil ? 0 : 14
        if let chevron {
            chevron.frame = NSRect(x: bounds.maxX - chevronWidth - 4, y: 0, width: chevronWidth, height: bounds.height)
        }
        imageView.frame = NSRect(x: chevron == nil ? 0 : 4, y: 0, width: bounds.width - chevronWidth - (chevron == nil ? 0 : 4), height: bounds.height)
        let textHeight = label.intrinsicContentSize.height
        let inset: CGFloat = chevron == nil ? 0 : 8
        label.alignment = chevron == nil ? .center : .left
        label.frame = NSRect(x: inset, y: (bounds.height - textHeight) / 2,
                             width: bounds.width - inset - chevronWidth - (chevron == nil ? 0 : 6),
                             height: textHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let alpha: CGFloat = pressed ? 0.16 : (isOn ? 0.13 : (hovering ? 0.07 : 0))
        guard alpha > 0 else { return }
        let color = isOn && !hovering && !pressed ? NSColor.controlAccentColor.withAlphaComponent(0.22)
                                                 : NSColor.labelColor.withAlphaComponent(alpha)
        color.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5).fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    override func mouseDown(with event: NSEvent) { pressed = true }

    override func mouseUp(with event: NSEvent) {
        pressed = false
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        onClick?(event)
    }

    /// Abre un menú justo debajo del botón.
    func popUp(_ menu: NSMenu) {
        hovering = false
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: self)
    }
}

/// Separador vertical fino entre grupos de botones.
final class BarSeparator: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: 9, height: 30) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        NSRect(x: 4, y: 6, width: 1, height: bounds.height - 12).fill()
    }
}
