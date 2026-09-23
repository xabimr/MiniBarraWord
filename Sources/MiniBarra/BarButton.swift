import AppKit

/// Botón de la barra: icono o texto, fondo al pasar el ratón y estado activo.
/// Acepta el primer clic para funcionar sin activar la app (Word sigue delante).
final class BarButton: NSView {
    var onClick: ((NSEvent) -> Void)?
    var isOn = false { didSet { needsDisplay = true } }

    private let width: CGFloat
    private let height: CGFloat
    private let bordered: Bool
    private let hasCaption: Bool
    private var hovering = false { didSet { needsDisplay = true } }
    private var pressed = false { didSet { needsDisplay = true } }
    private let imageView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let chevron: NSImageView?

    /// - Parameters:
    ///   - text: si se da, el botón muestra texto (alineado a la izquierda si hay chevron).
    ///   - caption: texto bajo el icono, para los botones grandes (Estilos, Nuevo comentario).
    ///   - chevron: añade una flecha ▾ a la derecha (desplegables).
    ///   - bordered: dibuja un campo con borde, como los desplegables de fuente y tamaño.
    init(image: NSImage? = nil, text: NSAttributedString? = nil, caption: String? = nil,
         width: CGFloat, height: CGFloat = 28, chevron: Bool = false, bordered: Bool = false,
         tooltip: String) {
        self.width = width
        self.height = height
        self.bordered = bordered
        self.hasCaption = caption != nil
        self.chevron = chevron ? NSImageView(image: Icons.symbol("chevron.down", size: 9, weight: .semibold)) : nil
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
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
        if let caption {
            label.stringValue = caption
            label.font = .systemFont(ofSize: 12)
            label.alignment = .center
            label.maximumNumberOfLines = 2
            label.lineBreakMode = .byWordWrapping
        }
        label.isHidden = text == nil && caption == nil
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

    override var intrinsicContentSize: NSSize { NSSize(width: width, height: height) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        let chevronWidth: CGFloat = chevron == nil ? 0 : 14
        if hasCaption {
            // Icono arriba, texto debajo; la flecha, junto al icono.
            let captionHeight = label.sizeThatFits(NSSize(width: bounds.width - 4, height: 40)).height
            label.frame = NSRect(x: 2, y: 5, width: bounds.width - 4, height: captionHeight)
            let iconArea = NSRect(x: 0, y: label.frame.maxY, width: bounds.width, height: bounds.height - label.frame.maxY)
            imageView.frame = iconArea.offsetBy(dx: chevron == nil ? 0 : -5, dy: 0)
            chevron?.frame = NSRect(x: bounds.midX + 12, y: iconArea.minY, width: chevronWidth, height: iconArea.height)
            return
        }
        if let chevron {
            chevron.frame = NSRect(x: bounds.maxX - chevronWidth - 4, y: 0, width: chevronWidth, height: bounds.height)
        }
        imageView.frame = NSRect(x: chevron == nil ? 0 : 4, y: 0,
                                 width: bounds.width - chevronWidth - (chevron == nil ? 0 : 4), height: bounds.height)
        let textHeight = label.intrinsicContentSize.height
        let inset: CGFloat = chevron == nil ? 0 : 7
        label.alignment = chevron == nil ? .center : .left
        label.frame = NSRect(x: inset, y: (bounds.height - textHeight) / 2,
                             width: bounds.width - inset - chevronWidth - (chevron == nil ? 0 : 6),
                             height: textHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
        if bordered {
            NSColor.controlBackgroundColor.setFill()
            shape.fill()
            (hovering ? NSColor.secondaryLabelColor : NSColor.separatorColor).setStroke()
            let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: 4.5, yRadius: 4.5)
            border.lineWidth = 1
            border.stroke()
            return
        }
        let alpha: CGFloat = pressed ? 0.16 : (isOn ? 0.13 : (hovering ? 0.07 : 0))
        guard alpha > 0 else { return }
        let color = isOn && !hovering && !pressed ? NSColor.controlAccentColor.withAlphaComponent(0.22)
                                                 : NSColor.labelColor.withAlphaComponent(alpha)
        color.setFill()
        shape.fill()
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
    private let height: CGFloat

    init(height: CGFloat = 28) {
        self.height = height
        super.init(frame: NSRect(x: 0, y: 0, width: 9, height: height))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: 9, height: height) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        NSRect(x: 4, y: 4, width: 1, height: bounds.height - 8).fill()
    }
}
